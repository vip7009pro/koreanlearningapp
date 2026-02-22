import { Injectable, UnauthorizedException, ConflictException } from '@nestjs/common';
import { JwtService } from '@nestjs/jwt';
import { ConfigService } from '@nestjs/config';
import * as bcrypt from 'bcrypt';
import { OAuth2Client } from 'google-auth-library';
import * as admin from 'firebase-admin';
import * as nodemailer from 'nodemailer';
import { PrismaService } from '../../prisma/prisma.service';
import { LoginDto, RegisterDto, UpdateProfileDto } from './dto/auth.dto';

@Injectable()
export class AuthService {
  private googleClient: OAuth2Client;
  private mailer: nodemailer.Transporter | null = null;

  constructor(
    private prisma: PrismaService,
    private jwtService: JwtService,
    private configService: ConfigService,
  ) {
    this.googleClient = new OAuth2Client(
      this.configService.get<string>('GOOGLE_CLIENT_ID') || undefined,
    );

    this.initFirebaseAdmin();
    this.initMailer();
  }

  private initFirebaseAdmin() {
    if (admin.apps.length > 0) return;

    const svcJson = this.configService.get<string>(
      'FIREBASE_SERVICE_ACCOUNT_JSON',
    );

    if (svcJson && svcJson.trim()) {
      try {
        const creds = JSON.parse(svcJson);
        admin.initializeApp({
          credential: admin.credential.cert(creds),
        });
        return;
      } catch (_) {
        // Ignore malformed config; phone login will throw later.
      }
    }

    try {
      admin.initializeApp();
    } catch (_) {
      // Ignore; may fail if no ADC is set.
    }
  }

  private initMailer() {
    const host = this.configService.get<string>('SMTP_HOST');
    const port = this.configService.get<string>('SMTP_PORT');
    const user = this.configService.get<string>('SMTP_USER');
    const pass = this.configService.get<string>('SMTP_PASS');

    if (!host || !port || !user || !pass) {
      this.mailer = null;
      return;
    }

    this.mailer = nodemailer.createTransport({
      host,
      port: parseInt(port, 10),
      secure: parseInt(port, 10) === 465,
      auth: { user, pass },
    });
  }

  private async sendWelcomeEmail(to: string, displayName: string) {
    if (!this.mailer) return;
    const fromEmail =
      this.configService.get<string>('SMTP_FROM') ||
      this.configService.get<string>('SMTP_USER') ||
      'no-reply@koreanapp.local';
    const fromName = this.configService.get<string>('SMTP_FROM_NAME');
    const from = fromName ? `${fromName} <${fromEmail}>` : fromEmail;

    try {
      await this.mailer.sendMail({
        from,
        to,
        subject: 'Chào mừng bạn đến với Tiếng Hàn FDI',
        text: `Xin chào ${displayName || 'bạn'}!\n\nChào mừng bạn đã đăng ký thành công tài khoản.`,
      });
    } catch (_) {
      // best-effort
    }
  }

  private normalizePhoneNumber(phone: string) {
    let p = (phone || '').trim();
    if (!p) return '';

    p = p.replace(/[\s\-().]/g, '');
    if (p.startsWith('00')) p = `+${p.substring(2)}`;
    if (p.startsWith('+')) return p;
    if (p.startsWith('0')) return `+84${p.substring(1)}`;
    if (p.startsWith('84')) return `+${p}`;
    return `+${p}`;
  }

  async register(dto: RegisterDto) {
    const existing = await this.prisma.user.findUnique({
      where: { email: dto.email },
    });

    if (existing) {
      throw new ConflictException('Email already registered');
    }

    const passwordHash = await bcrypt.hash(dto.password, 10);

    const user = await this.prisma.user.create({
      data: {
        email: dto.email,
        passwordHash,
        displayName: dto.displayName,
      },
    });

    // Create free subscription
    await this.prisma.subscription.create({
      data: {
        userId: user.id,
        planType: 'FREE',
        status: 'ACTIVE',
      },
    });

    const tokens = await this.generateTokens(user.id, user.email, user.role);

    await this.sendWelcomeEmail(user.email, user.displayName);

    return {
      ...tokens,
      user: {
        id: user.id,
        email: user.email,
        displayName: user.displayName,
        role: user.role,
        totalXP: user.totalXP,
        streakDays: user.streakDays,
      },
      needsPassword: false,
    };
  }

  async login(dto: LoginDto) {
    const user = await this.prisma.user.findUnique({
      where: { email: dto.email },
    });

    if (!user) {
      throw new UnauthorizedException('Invalid credentials');
    }

    if (!user.passwordHash) {
      throw new UnauthorizedException('Invalid credentials');
    }

    const isPasswordValid = await bcrypt.compare(dto.password, user.passwordHash);

    if (!isPasswordValid) {
      throw new UnauthorizedException('Invalid credentials');
    }

    // Update last active
    await this.prisma.user.update({
      where: { id: user.id },
      data: { lastActiveAt: new Date() },
    });

    const tokens = await this.generateTokens(user.id, user.email, user.role);

    return {
      ...tokens,
      user: {
        id: user.id,
        email: user.email,
        displayName: user.displayName,
        avatarUrl: user.avatarUrl,
        role: user.role,
        totalXP: user.totalXP,
        streakDays: user.streakDays,
      },
      needsPassword: false,
    };
  }

  async loginWithGoogle(idToken: string) {
    let payload:
      | {
          sub?: string;
          email?: string;
          name?: string;
          picture?: string;
        }
      | undefined;

    try {
      const ticket = await this.googleClient.verifyIdToken({
        idToken,
        audience: this.configService.get<string>('GOOGLE_CLIENT_ID') || undefined,
      });
      payload = ticket.getPayload() as any;
    } catch (_) {
      throw new UnauthorizedException('Invalid Google token');
    }

    const email = (payload?.email || '').trim().toLowerCase();
    const googleSub = (payload?.sub || '').trim();
    if (!email || !googleSub) {
      throw new UnauthorizedException('Invalid Google token');
    }

    const existingBySub = await this.prisma.user.findUnique({
      where: { googleSub },
    });

    let user = existingBySub;

    if (!user) {
      const existingByEmail = await this.prisma.user.findUnique({
        where: { email },
      });

      if (existingByEmail) {
        user = await this.prisma.user.update({
          where: { id: existingByEmail.id },
          data: {
            googleSub,
            avatarUrl:
              existingByEmail.avatarUrl || (payload?.picture as any) || null,
          },
        });
      } else {
        const displayName =
          (payload?.name || '').toString().trim() || email.split('@')[0];

        user = await this.prisma.user.create({
          data: {
            email,
            googleSub,
            displayName,
            avatarUrl: (payload?.picture as any) || null,
            passwordHash: null,
          },
        });

        await this.prisma.subscription.create({
          data: {
            userId: user.id,
            planType: 'FREE',
            status: 'ACTIVE',
          },
        });

        await this.sendWelcomeEmail(user.email, user.displayName);
      }
    }

    await this.prisma.user.update({
      where: { id: user.id },
      data: { lastActiveAt: new Date() },
    });

    const tokens = await this.generateTokens(user.id, user.email, user.role);

    return {
      ...tokens,
      user: {
        id: user.id,
        email: user.email,
        displayName: user.displayName,
        avatarUrl: user.avatarUrl,
        role: user.role,
        totalXP: user.totalXP,
        streakDays: user.streakDays,
      },
      needsPassword: !user.passwordHash,
    };
  }

  async loginWithPhoneFirebaseToken(firebaseIdToken: string, displayName?: string) {
    let decoded: admin.auth.DecodedIdToken;
    try {
      decoded = await admin.auth().verifyIdToken(firebaseIdToken);
    } catch (_) {
      throw new UnauthorizedException('Invalid Firebase token');
    }

    const phoneRaw = (decoded as any).phone_number as string | undefined;
    const phone = this.normalizePhoneNumber(phoneRaw || '');
    if (!phone) {
      throw new UnauthorizedException('Phone number not found in token');
    }

    let user = await this.prisma.user.findUnique({
      where: { phoneNumber: phone },
    });

    if (!user) {
      const emailFromToken = ((decoded as any).email as string | undefined) || '';
      const email = emailFromToken.trim().toLowerCase();

      if (email) {
        const existingByEmail = await this.prisma.user.findUnique({
          where: { email },
        });
        if (existingByEmail) {
          user = await this.prisma.user.update({
            where: { id: existingByEmail.id },
            data: {
              phoneNumber: phone,
            },
          });
        }
      }

      if (!user) {
        const fallbackEmail = `phone_${phone.replace('+', '')}@phone.local`;
        const name = (displayName || '').trim() || phone;

        user = await this.prisma.user.create({
          data: {
            email: email || fallbackEmail,
            phoneNumber: phone,
            displayName: name,
            passwordHash: null,
          },
        });

        await this.prisma.subscription.create({
          data: {
            userId: user.id,
            planType: 'FREE',
            status: 'ACTIVE',
          },
        });
      }
    }

    await this.prisma.user.update({
      where: { id: user.id },
      data: { lastActiveAt: new Date() },
    });

    const tokens = await this.generateTokens(user.id, user.email, user.role);
    return {
      ...tokens,
      user: {
        id: user.id,
        email: user.email,
        displayName: user.displayName,
        avatarUrl: user.avatarUrl,
        role: user.role,
        totalXP: user.totalXP,
        streakDays: user.streakDays,
      },
      needsPassword: !user.passwordHash,
    };
  }

  async setPassword(userId: string, password: string) {
    const user = await this.prisma.user.findUnique({ where: { id: userId } });
    if (!user) throw new UnauthorizedException('User not found');
    if (user.passwordHash) {
      throw new ConflictException('Password already set');
    }

    const passwordHash = await bcrypt.hash(password, 10);
    await this.prisma.user.update({
      where: { id: userId },
      data: { passwordHash },
    });

    return { message: 'Password set successfully' };
  }

  async requestPasswordReset(emailRaw: string) {
    const email = (emailRaw || '').trim().toLowerCase();
    const user = await this.prisma.user.findUnique({ where: { email } });

    // Do not reveal whether email exists.
    if (!user) return { message: 'If the email exists, a code has been sent.' };

    if (!this.mailer) {
      return { message: 'If the email exists, a code has been sent.' };
    }

    const code = Math.floor(100000 + Math.random() * 900000).toString();
    const codeHash = await bcrypt.hash(code, 10);
    const expiresAt = new Date(Date.now() + 10 * 60 * 1000);

    await this.prisma.passwordResetCode.create({
      data: {
        userId: user.id,
        codeHash,
        expiresAt,
      },
    });

    const fromEmail =
      this.configService.get<string>('SMTP_FROM') ||
      this.configService.get<string>('SMTP_USER') ||
      'no-reply@koreanapp.local';
    const fromName = this.configService.get<string>('SMTP_FROM_NAME');
    const from = fromName ? `${fromName} <${fromEmail}>` : fromEmail;

    try {
      await this.mailer.sendMail({
        from,
        to: user.email,
        subject: 'Mã đặt lại mật khẩu',
        text: `Mã OTP đặt lại mật khẩu của bạn là: ${code}\n\nMã có hiệu lực trong 10 phút.`,
      });
    } catch (_) {
      // best-effort
    }

    return { message: 'If the email exists, a code has been sent.' };
  }

  async verifyPasswordReset(emailRaw: string, code: string, newPassword: string) {
    const email = (emailRaw || '').trim().toLowerCase();
    const user = await this.prisma.user.findUnique({ where: { email } });
    if (!user) throw new UnauthorizedException('Invalid reset code');

    const now = new Date();
    const recentCodes = await this.prisma.passwordResetCode.findMany({
      where: {
        userId: user.id,
        usedAt: null,
        expiresAt: { gt: now },
      },
      orderBy: { createdAt: 'desc' },
      take: 5,
    });

    let matchedId: string | null = null;
    for (const c of recentCodes) {
      const ok = await bcrypt.compare(code, c.codeHash);
      if (ok) {
        matchedId = c.id;
        break;
      }
    }

    if (!matchedId) throw new UnauthorizedException('Invalid reset code');

    const passwordHash = await bcrypt.hash(newPassword, 10);
    await this.prisma.$transaction([
      this.prisma.passwordResetCode.update({
        where: { id: matchedId },
        data: { usedAt: new Date() },
      }),
      this.prisma.user.update({
        where: { id: user.id },
        data: { passwordHash },
      }),
    ]);

    const tokens = await this.generateTokens(user.id, user.email, user.role);
    return {
      ...tokens,
      user: {
        id: user.id,
        email: user.email,
        displayName: user.displayName,
        avatarUrl: user.avatarUrl,
        role: user.role,
        totalXP: user.totalXP,
        streakDays: user.streakDays,
      },
      needsPassword: false,
    };
  }

  async refreshToken(refreshToken: string) {
    try {
      const payload = this.jwtService.verify(refreshToken, {
        secret: this.configService.get<string>('JWT_REFRESH_SECRET'),
      });

      const user = await this.prisma.user.findUnique({
        where: { id: payload.sub },
      });

      if (!user) {
        throw new UnauthorizedException('User not found');
      }

      return this.generateTokens(user.id, user.email, user.role);
    } catch {
      throw new UnauthorizedException('Invalid refresh token');
    }
  }

  async getProfile(userId: string) {
    const user = await this.prisma.user.findUnique({
      where: { id: userId },
      include: {
        subscriptions: {
          where: { status: 'ACTIVE' },
          orderBy: { createdAt: 'desc' },
          take: 1,
        },
      },
    });

    if (!user) {
      throw new UnauthorizedException('User not found');
    }

    return {
      id: user.id,
      email: user.email,
      displayName: user.displayName,
      avatarUrl: user.avatarUrl,
      role: user.role,
      totalXP: user.totalXP,
      streakDays: user.streakDays,
      createdAt: user.createdAt,
      subscription: user.subscriptions[0] || null,
    };
  }

  async updateProfile(userId: string, dto: UpdateProfileDto) {
    const user = await this.prisma.user.update({
      where: { id: userId },
      data: {
        ...(dto.displayName != null ? { displayName: dto.displayName } : {}),
        ...(dto.avatarUrl != null ? { avatarUrl: dto.avatarUrl } : {}),
      },
    });

    return {
      id: user.id,
      email: user.email,
      displayName: user.displayName,
      avatarUrl: user.avatarUrl,
      role: user.role,
      totalXP: user.totalXP,
      streakDays: user.streakDays,
    };
  }

  private async generateTokens(userId: string, email: string, role: string) {
    const payload = { sub: userId, email, role };

    const [accessToken, refreshToken] = await Promise.all([
      this.jwtService.signAsync(payload, {
        secret: this.configService.get<string>('JWT_SECRET'),
        expiresIn: '24h',
      }),
      this.jwtService.signAsync(payload, {
        secret: this.configService.get<string>('JWT_REFRESH_SECRET'),
        expiresIn: '7d',
      }),
    ]);

    return { accessToken, refreshToken };
  }
}

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

  private escapeHtml(value: string) {
    return String(value || '').replace(/[&<>'"]/g, (char) => {
      switch (char) {
        case '&': return '&amp;';
        case '<': return '&lt;';
        case '>': return '&gt;';
        case '"': return '&quot;';
        case "'": return '&#39;';
        default: return char;
      }
    });
  }

  private buildEmailShell(params: {
    title: string;
    headline: string;
    preheader: string;
    bodyHtml: string;
  }) {
    const title = this.escapeHtml(params.title);
    const headline = this.escapeHtml(params.headline);
    const preheader = this.escapeHtml(params.preheader);

    return `<!doctype html>
<html lang="vi">
  <head>
    <meta charset="UTF-8" />
    <meta name="viewport" content="width=device-width, initial-scale=1.0" />
    <title>${title}</title>
  </head>
  <body style="margin:0;padding:0;background:#f4f7fb;font-family:Arial,Helvetica,sans-serif;color:#0f172a;">
    <div style="display:none;max-height:0;overflow:hidden;opacity:0;color:transparent;">${preheader}</div>
    <table role="presentation" width="100%" cellspacing="0" cellpadding="0" style="background:#f4f7fb;padding:32px 16px;">
      <tr>
        <td align="center">
          <table role="presentation" width="100%" cellspacing="0" cellpadding="0" style="max-width:640px;background:#ffffff;border-radius:24px;overflow:hidden;box-shadow:0 18px 60px rgba(15,23,42,0.12);">
            <tr>
              <td style="background:linear-gradient(135deg,#1d4ed8,#0f766e);padding:28px 32px;color:#ffffff;">
                <div style="font-size:13px;letter-spacing:0.18em;text-transform:uppercase;opacity:0.9;">Tiếng Hàn FDI</div>
                <div style="font-size:26px;line-height:1.25;font-weight:700;margin-top:10px;">${headline}</div>
              </td>
            </tr>
            <tr>
              <td style="padding:32px;">
                ${params.bodyHtml}
              </td>
            </tr>
            <tr>
              <td style="padding:0 32px 32px;color:#64748b;font-size:12px;line-height:1.7;">
                Nếu bạn không thực hiện yêu cầu này, vui lòng bỏ qua email. Đây là email tự động, vui lòng không trả lời.
              </td>
            </tr>
          </table>
        </td>
      </tr>
    </table>
  </body>
</html>`;
  }

  private async sendWelcomeEmail(to: string, displayName: string) {
    if (!this.mailer) return;
    const safeName = this.escapeHtml(displayName || 'bạn');
    const fromEmail =
      this.configService.get<string>('SMTP_FROM') ||
      this.configService.get<string>('SMTP_USER') ||
      'no-reply@koreanapp.local';
    const fromName = this.configService.get<string>('SMTP_FROM_NAME');
    const from = fromName ? `${fromName} <${fromEmail}>` : fromEmail;
    const subject = 'Chào mừng bạn đến với Tiếng Hàn FDI';
    const html = this.buildEmailShell({
      title: subject,
      headline: 'Chào mừng bạn đã gia nhập Tiếng Hàn FDI',
      preheader: 'Tài khoản của bạn đã được tạo thành công. Bắt đầu học ngay hôm nay.',
      bodyHtml: `
        <p style="margin:0 0 16px;font-size:16px;line-height:1.8;">Xin chào <strong>${safeName}</strong>,</p>
        <p style="margin:0 0 20px;font-size:15px;line-height:1.8;color:#334155;">
          Cảm ơn bạn đã đăng ký tài khoản. Tiếng Hàn FDI giúp bạn học tiếng Hàn theo lộ trình rõ ràng, luyện viết AI, ôn tập SRS và theo dõi tiến độ học tập trên mọi thiết bị.
        </p>
        <div style="background:#eff6ff;border:1px solid #bfdbfe;border-radius:16px;padding:18px 20px;margin:0 0 22px;">
          <div style="font-size:14px;font-weight:700;color:#1d4ed8;margin-bottom:10px;">Bạn có thể bắt đầu với:</div>
          <ul style="margin:0;padding-left:20px;color:#334155;font-size:14px;line-height:1.9;">
            <li>Khóa học nền tảng và bài học chuyên ngành</li>
            <li>Luyện viết AI với phản hồi tức thì</li>
            <li>TOPIK, SRS và theo dõi điểm XP</li>
          </ul>
        </div>
        <p style="margin:0;font-size:15px;line-height:1.8;color:#334155;">
          Nếu bạn cần hỗ trợ, hãy phản hồi lại email này hoặc liên hệ đội ngũ hỗ trợ của chúng tôi.
        </p>
      `,
    });
    const text = [
      `Xin chào ${displayName || 'bạn'},`,
      '',
      'Chào mừng bạn đã gia nhập Tiếng Hàn FDI.',
      'Tài khoản của bạn đã được tạo thành công. Bạn có thể bắt đầu học với các khóa học nền tảng, luyện viết AI, TOPIK và SRS.',
      '',
      'Nếu cần hỗ trợ, hãy phản hồi lại email này hoặc liên hệ đội ngũ hỗ trợ của chúng tôi.',
    ].join('\n');

    try {
      await this.mailer.sendMail({
        from,
        to,
        subject,
        text,
        html,
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

  private normalizeEmail(email: string) {
    return (email || '').trim().toLowerCase();
  }

  async register(dto: RegisterDto) {
    const email = this.normalizeEmail(dto.email);
    const existing = await this.prisma.user.findFirst({
      where: {
        email: {
          equals: email,
          mode: 'insensitive',
        },
      },
    });

    if (existing) {
      throw new ConflictException('Email already registered');
    }

    const passwordHash = await bcrypt.hash(dto.password, 10);

    const user = await this.prisma.user.create({
      data: {
        email,
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
    const email = this.normalizeEmail(dto.email);
    const user = await this.prisma.user.findFirst({
      where: {
        email: {
          equals: email,
          mode: 'insensitive',
        },
      },
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

    const email = this.normalizeEmail(payload?.email || '');
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

        await this.sendWelcomeEmail(email, displayName);
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
    const normalizedEmail = this.normalizeEmail(emailRaw);
    const generic = {
      message:
        'Nếu email tồn tại, chúng tôi đã gửi mã xác nhận để đặt lại mật khẩu. Vui lòng kiểm tra hộp thư của bạn.',
    };

    const user = await this.prisma.user.findFirst({
      where: {
        email: {
          equals: normalizedEmail,
          mode: 'insensitive',
        },
      },
    });

    if (!user) return generic;

    if (!this.mailer) {
      return generic;
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
    const subject = 'Mã đặt lại mật khẩu - Tiếng Hàn FDI';
    const html = this.buildEmailShell({
      title: subject,
      headline: 'Mã OTP đặt lại mật khẩu',
      preheader: 'Sử dụng mã này để đặt lại mật khẩu trong vòng 10 phút.',
      bodyHtml: `
        <p style="margin:0 0 16px;font-size:16px;line-height:1.8;">Xin chào <strong>${this.escapeHtml(user.displayName || 'bạn')}</strong>,</p>
        <p style="margin:0 0 20px;font-size:15px;line-height:1.8;color:#334155;">
          Chúng tôi đã nhận được yêu cầu đặt lại mật khẩu cho tài khoản <strong>${this.escapeHtml(user.email)}</strong>.
          Dùng mã bên dưới để hoàn tất bước xác minh.
        </p>
        <div style="text-align:center;margin:26px 0;">
          <div style="display:inline-block;min-width:240px;padding:18px 24px;background:#0f172a;color:#ffffff;border-radius:18px;font-size:34px;font-weight:700;letter-spacing:0.32em;">
            ${code}
          </div>
        </div>
        <div style="background:#fef3c7;border:1px solid #fde68a;border-radius:16px;padding:16px 18px;margin:0 0 20px;color:#92400e;line-height:1.8;font-size:14px;">
          Mã này có hiệu lực trong <strong>10 phút</strong>. Nếu bạn không yêu cầu đặt lại mật khẩu, hãy bỏ qua email này.
        </div>
      `,
    });
    const text = [
      `Xin chào ${user.displayName || 'bạn'},`,
      '',
      `Chúng tôi đã nhận được yêu cầu đặt lại mật khẩu cho tài khoản ${user.email}.`,
      `Mã OTP của bạn là: ${code}`,
      'Mã này có hiệu lực trong 10 phút.',
      '',
      'Nếu bạn không yêu cầu đặt lại mật khẩu, hãy bỏ qua email này.',
    ].join('\n');

    try {
      await this.mailer.sendMail({
        from,
        to: user.email,
        subject,
        text,
        html,
      });
    } catch (_) {
      // best-effort
    }

    return generic;
  }

  async verifyPasswordReset(emailRaw: string, code: string, newPassword: string) {
    const normalizedEmail = this.normalizeEmail(emailRaw);
    const user = await this.prisma.user.findFirst({
      where: {
        email: {
          equals: normalizedEmail,
          mode: 'insensitive',
        },
      },
    });
    if (!user) throw new UnauthorizedException('User not found');

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

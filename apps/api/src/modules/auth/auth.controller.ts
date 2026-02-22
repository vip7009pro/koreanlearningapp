import { Controller, Post, Body, Get, UseGuards, HttpCode, HttpStatus, Patch } from '@nestjs/common';
import { ApiTags, ApiOperation, ApiBearerAuth } from '@nestjs/swagger';
import { AuthGuard } from '@nestjs/passport';
import { AuthService } from './auth.service';
import {
  LoginDto,
  RegisterDto,
  RefreshTokenDto,
  UpdateProfileDto,
  GoogleLoginDto,
  PhoneLoginDto,
  SetPasswordDto,
  RequestPasswordResetDto,
  VerifyPasswordResetDto,
} from './dto/auth.dto';
import { CurrentUser } from '../../common/decorators/current-user.decorator';

@ApiTags('auth')
@Controller('auth')
export class AuthController {
  constructor(private authService: AuthService) {}

  @Post('register')
  @ApiOperation({ summary: 'Register a new user' })
  async register(@Body() dto: RegisterDto) {
    return this.authService.register(dto);
  }

  @Post('login')
  @HttpCode(HttpStatus.OK)
  @ApiOperation({ summary: 'Login with email and password' })
  async login(@Body() dto: LoginDto) {
    return this.authService.login(dto);
  }

  @Post('google')
  @HttpCode(HttpStatus.OK)
  @ApiOperation({ summary: 'Login/Register with Google ID token' })
  async googleLogin(@Body() dto: GoogleLoginDto) {
    return this.authService.loginWithGoogle(dto.idToken);
  }

  @Post('phone')
  @HttpCode(HttpStatus.OK)
  @ApiOperation({ summary: 'Login/Register with Firebase phone ID token' })
  async phoneLogin(@Body() dto: PhoneLoginDto) {
    return this.authService.loginWithPhoneFirebaseToken(
      dto.firebaseIdToken,
      dto.displayName,
    );
  }

  @Post('refresh')
  @HttpCode(HttpStatus.OK)
  @ApiOperation({ summary: 'Refresh access token' })
  async refresh(@Body() dto: RefreshTokenDto) {
    return this.authService.refreshToken(dto.refreshToken);
  }

  @Get('profile')
  @UseGuards(AuthGuard('jwt'))
  @ApiBearerAuth()
  @ApiOperation({ summary: 'Get current user profile' })
  async getProfile(@CurrentUser('id') userId: string) {
    return this.authService.getProfile(userId);
  }

  @Patch('profile')
  @UseGuards(AuthGuard('jwt'))
  @ApiBearerAuth()
  @ApiOperation({ summary: 'Update current user profile' })
  async updateProfile(
    @CurrentUser('id') userId: string,
    @Body() dto: UpdateProfileDto,
  ) {
    return this.authService.updateProfile(userId, dto);
  }

  @Post('password/set')
  @UseGuards(AuthGuard('jwt'))
  @ApiBearerAuth()
  @ApiOperation({ summary: 'Set password for accounts created via Google/Phone' })
  async setPassword(
    @CurrentUser('id') userId: string,
    @Body() dto: SetPasswordDto,
  ) {
    return this.authService.setPassword(userId, dto.password);
  }

  @Post('password/reset/request')
  @HttpCode(HttpStatus.OK)
  @ApiOperation({ summary: 'Request password reset via email OTP' })
  async requestPasswordReset(@Body() dto: RequestPasswordResetDto) {
    return this.authService.requestPasswordReset(dto.email);
  }

  @Post('password/reset/verify')
  @HttpCode(HttpStatus.OK)
  @ApiOperation({ summary: 'Verify reset OTP and set a new password' })
  async verifyPasswordReset(@Body() dto: VerifyPasswordResetDto) {
    return this.authService.verifyPasswordReset(
      dto.email,
      dto.code,
      dto.newPassword,
    );
  }
}

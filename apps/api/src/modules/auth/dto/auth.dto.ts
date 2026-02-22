import { IsEmail, IsString, MinLength, MaxLength, IsNotEmpty, IsOptional } from 'class-validator';
import { ApiProperty } from '@nestjs/swagger';

export class LoginDto {
  @ApiProperty({ example: 'admin@koreanapp.com' })
  @IsEmail()
  email: string;

  @ApiProperty({ example: 'Admin123!' })
  @IsString()
  @MinLength(6)
  password: string;
}

export class RegisterDto {
  @ApiProperty({ example: 'user@example.com' })
  @IsEmail()
  email: string;

  @ApiProperty({ example: 'password123' })
  @IsString()
  @MinLength(6)
  @MaxLength(100)
  password: string;

  @ApiProperty({ example: 'John Doe' })
  @IsString()
  @IsNotEmpty()
  @MaxLength(100)
  displayName: string;
}

export class RefreshTokenDto {
  @ApiProperty()
  @IsString()
  @IsNotEmpty()
  refreshToken: string;
}

export class UpdateProfileDto {
  @ApiProperty({ required: false })
  @IsOptional()
  @IsString()
  @MaxLength(100)
  displayName?: string;

  @ApiProperty({ required: false })
  @IsOptional()
  @IsString()
  avatarUrl?: string;
}

export class GoogleLoginDto {
  @ApiProperty({ description: 'Google ID token from mobile Google Sign-In' })
  @IsString()
  @IsNotEmpty()
  idToken: string;
}

export class PhoneLoginDto {
  @ApiProperty({ description: 'Firebase Auth ID token after phone verification' })
  @IsString()
  @IsNotEmpty()
  firebaseIdToken: string;

  @ApiProperty({ required: false })
  @IsOptional()
  @IsString()
  @MaxLength(100)
  displayName?: string;
}

export class SetPasswordDto {
  @ApiProperty({ example: 'NewPassword123!' })
  @IsString()
  @MinLength(6)
  @MaxLength(100)
  password: string;
}

export class RequestPasswordResetDto {
  @ApiProperty({ example: 'user@example.com' })
  @IsEmail()
  email: string;
}

export class VerifyPasswordResetDto {
  @ApiProperty({ example: 'user@example.com' })
  @IsEmail()
  email: string;

  @ApiProperty({ example: '123456' })
  @IsString()
  @IsNotEmpty()
  code: string;

  @ApiProperty({ example: 'NewPassword123!' })
  @IsString()
  @MinLength(6)
  @MaxLength(100)
  newPassword: string;
}

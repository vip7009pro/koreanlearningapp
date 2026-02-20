import { IsString, IsInt, IsOptional, IsNotEmpty, IsUUID } from 'class-validator';
import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';

export class CreateDialogueDto {
  @ApiProperty() @IsUUID() lessonId: string;
  @ApiProperty({ example: '민수' }) @IsString() @IsNotEmpty() speaker: string;
  @ApiProperty({ example: '안녕하세요! 잘 지내세요?' }) @IsString() @IsNotEmpty() koreanText: string;
  @ApiProperty({ example: 'Xin chào! Bạn khỏe không?' }) @IsString() @IsNotEmpty() vietnameseText: string;
  @ApiPropertyOptional() @IsOptional() @IsString() audioUrl?: string;
  @ApiPropertyOptional({ default: 0 }) @IsOptional() @IsInt() orderIndex?: number;
}

export class UpdateDialogueDto {
  @ApiPropertyOptional() @IsOptional() @IsString() speaker?: string;
  @ApiPropertyOptional() @IsOptional() @IsString() koreanText?: string;
  @ApiPropertyOptional() @IsOptional() @IsString() vietnameseText?: string;
  @ApiPropertyOptional() @IsOptional() @IsString() audioUrl?: string;
  @ApiPropertyOptional() @IsOptional() @IsInt() orderIndex?: number;
}

import { IsString, IsEnum, IsOptional, IsNotEmpty, IsUUID } from 'class-validator';
import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import { Difficulty } from '@prisma/client';

export class CreateVocabularyDto {
  @ApiProperty()
  @IsUUID()
  lessonId: string;

  @ApiProperty({ example: '안녕하세요' })
  @IsString()
  @IsNotEmpty()
  korean: string;

  @ApiProperty({ example: 'Xin chào' })
  @IsString()
  @IsNotEmpty()
  vietnamese: string;

  @ApiPropertyOptional({ example: 'an-nyeong-ha-se-yo' })
  @IsOptional()
  @IsString()
  pronunciation?: string;

  @ApiPropertyOptional({ example: '안녕하세요, 저는 민수입니다.' })
  @IsOptional()
  @IsString()
  exampleSentence?: string;

  @ApiPropertyOptional({ example: 'Xin chào, tôi là Minsu.' })
  @IsOptional()
  @IsString()
  exampleMeaning?: string;

  @ApiPropertyOptional()
  @IsOptional()
  @IsString()
  audioUrl?: string;

  @ApiPropertyOptional({ enum: Difficulty, default: Difficulty.EASY })
  @IsOptional()
  @IsEnum(Difficulty)
  difficulty?: Difficulty;
}

export class UpdateVocabularyDto {
  @ApiPropertyOptional()
  @IsOptional()
  @IsString()
  korean?: string;

  @ApiPropertyOptional()
  @IsOptional()
  @IsString()
  vietnamese?: string;

  @ApiPropertyOptional()
  @IsOptional()
  @IsString()
  pronunciation?: string;

  @ApiPropertyOptional()
  @IsOptional()
  @IsString()
  exampleSentence?: string;

  @ApiPropertyOptional()
  @IsOptional()
  @IsString()
  exampleMeaning?: string;

  @ApiPropertyOptional()
  @IsOptional()
  @IsString()
  audioUrl?: string;

  @ApiPropertyOptional({ enum: Difficulty })
  @IsOptional()
  @IsEnum(Difficulty)
  difficulty?: Difficulty;
}

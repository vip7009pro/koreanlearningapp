import { IsString, IsInt, IsOptional, IsNotEmpty, IsUUID } from 'class-validator';
import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';

export class CreateLessonDto {
  @ApiProperty()
  @IsUUID()
  sectionId: string;

  @ApiProperty({ example: 'Greetings' })
  @IsString()
  @IsNotEmpty()
  title: string;

  @ApiPropertyOptional({ example: 'Learn basic Korean greetings' })
  @IsOptional()
  @IsString()
  description?: string;

  @ApiPropertyOptional({ default: 0 })
  @IsOptional()
  @IsInt()
  orderIndex?: number;

  @ApiPropertyOptional({ default: 10 })
  @IsOptional()
  @IsInt()
  estimatedMinutes?: number;
}

export class UpdateLessonDto {
  @ApiPropertyOptional()
  @IsOptional()
  @IsString()
  title?: string;

  @ApiPropertyOptional()
  @IsOptional()
  @IsString()
  description?: string;

  @ApiPropertyOptional()
  @IsOptional()
  @IsInt()
  orderIndex?: number;

  @ApiPropertyOptional()
  @IsOptional()
  @IsInt()
  estimatedMinutes?: number;
}

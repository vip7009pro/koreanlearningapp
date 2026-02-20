import { IsString, IsInt, IsOptional, IsNotEmpty, IsUUID } from 'class-validator';
import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';

export class CreateSectionDto {
  @ApiProperty()
  @IsUUID()
  courseId: string;

  @ApiProperty({ example: 'Introduction' })
  @IsString()
  @IsNotEmpty()
  title: string;

  @ApiPropertyOptional({ default: 0 })
  @IsOptional()
  @IsInt()
  orderIndex?: number;
}

export class UpdateSectionDto {
  @ApiPropertyOptional()
  @IsOptional()
  @IsString()
  title?: string;

  @ApiPropertyOptional()
  @IsOptional()
  @IsInt()
  orderIndex?: number;
}

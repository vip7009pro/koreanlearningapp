import { IsUUID, IsBoolean, IsInt, IsOptional } from 'class-validator';
import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';

export class UpdateProgressDto {
  @ApiProperty() @IsUUID() lessonId: string;
  @ApiPropertyOptional() @IsOptional() @IsBoolean() completed?: boolean;
  @ApiPropertyOptional() @IsOptional() @IsInt() score?: number;
}

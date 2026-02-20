import { IsString, IsOptional, IsNotEmpty, IsUUID } from 'class-validator';
import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';

export class CreateGrammarDto {
  @ApiProperty() @IsUUID() lessonId: string;
  @ApiProperty({ example: 'V + ㄹ/을 수 있다' }) @IsString() @IsNotEmpty() pattern: string;
  @ApiProperty({ example: 'Diễn tả khả năng/có thể làm gì đó' }) @IsString() @IsNotEmpty() explanationVN: string;
  @ApiProperty({ example: '한국어를 할 수 있어요 (Tôi có thể nói tiếng Hàn)' }) @IsString() @IsNotEmpty() example: string;
}

export class UpdateGrammarDto {
  @ApiPropertyOptional() @IsOptional() @IsString() pattern?: string;
  @ApiPropertyOptional() @IsOptional() @IsString() explanationVN?: string;
  @ApiPropertyOptional() @IsOptional() @IsString() example?: string;
}

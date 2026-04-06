import { ApiProperty } from '@nestjs/swagger';
import { IsNotEmpty, IsString, MaxLength } from 'class-validator';

export class KoreanTtsDto {
  @ApiProperty({ example: '안녕하세요. 오늘은 한국어를 연습해요.' })
  @IsString()
  @IsNotEmpty()
  @MaxLength(5000)
  text: string;
}

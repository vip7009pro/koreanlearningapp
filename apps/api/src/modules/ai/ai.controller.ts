import { Controller, Get, Post, Body, Query, UseGuards } from '@nestjs/common';
import { ApiTags, ApiOperation, ApiBearerAuth, ApiQuery } from '@nestjs/swagger';
import { AuthGuard } from '@nestjs/passport';
import { AIService } from './ai.service';
import { CurrentUser } from '../../common/decorators/current-user.decorator';
import { IsString, IsInt, IsNotEmpty, IsOptional, Min, Max } from 'class-validator';
import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';

class WritingCorrectionDto {
  @ApiProperty({ example: 'Viết một đoạn tự giới thiệu bằng tiếng Hàn' }) @IsString() @IsNotEmpty() prompt: string;
  @ApiProperty({ example: '안녕하세요. 저는 베트남 사람입니다.' }) @IsString() @IsNotEmpty() userAnswer: string;
}

class GenerateQuizDto {
  @ApiProperty({ example: '인사' }) @IsString() @IsNotEmpty() topic: string;
  @ApiPropertyOptional({ example: 'EASY' }) @IsOptional() @IsString() difficulty?: string;
  @ApiPropertyOptional({ example: 5 }) @IsOptional() @IsInt() @Min(1) @Max(20) questionCount?: number;
}

@ApiTags('ai')
@Controller('ai')
@UseGuards(AuthGuard('jwt'))
@ApiBearerAuth()
export class AIController {
  constructor(private aiService: AIService) {}

  @Post('writing-correction')
  @ApiOperation({ summary: 'Submit writing for AI correction' })
  correctWriting(@CurrentUser('id') userId: string, @Body() dto: WritingCorrectionDto) {
    return this.aiService.correctWriting(userId, dto.prompt, dto.userAnswer);
  }

  @Post('generate-quiz')
  @ApiOperation({ summary: 'Generate quiz using AI' })
  generateQuiz(@Body() dto: GenerateQuizDto) {
    return this.aiService.generateQuiz(dto.topic, dto.difficulty || 'EASY', dto.questionCount || 5);
  }

  @Get('writing-history')
  @ApiOperation({ summary: 'Get writing practice history' })
  @ApiQuery({ name: 'page', required: false }) @ApiQuery({ name: 'limit', required: false })
  getWritingHistory(@CurrentUser('id') userId: string, @Query('page') page = 1, @Query('limit') limit = 20) {
    return this.aiService.getWritingHistory(userId, page, limit);
  }
}

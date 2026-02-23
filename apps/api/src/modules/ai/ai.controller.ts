import { Controller, Get, Post, Body, Query, UseGuards, Param, ParseIntPipe, DefaultValuePipe } from '@nestjs/common';
import { ApiTags, ApiOperation, ApiBearerAuth, ApiQuery } from '@nestjs/swagger';
import { AuthGuard } from '@nestjs/passport';
import { UserRole } from '@prisma/client';
import { AIService } from './ai.service';
import { CurrentUser } from '../../common/decorators/current-user.decorator';
import { Roles } from '../../common/decorators/roles.decorator';
import { RolesGuard } from '../../common/guards/roles.guard';
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

class GenerateTopikExamDto {
  @ApiProperty({ enum: ['TOPIK_I', 'TOPIK_II'] })
  @IsString()
  @IsNotEmpty()
  topikLevel: 'TOPIK_I' | 'TOPIK_II';

  @ApiPropertyOptional({ example: 2025 })
  @IsOptional()
  @IsInt()
  @Min(2000)
  @Max(2100)
  year?: number;

  @ApiPropertyOptional({ example: 'TOPIK II 2025 - Mock 01' })
  @IsOptional()
  @IsString()
  title?: string;

  @ApiPropertyOptional({ enum: ['DRAFT', 'PUBLISHED'], example: 'DRAFT' })
  @IsOptional()
  @IsString()
  status?: 'DRAFT' | 'PUBLISHED';

  @ApiPropertyOptional({ description: 'How many questions to generate per chunk/batch (1..20)', example: 10 })
  @IsOptional()
  @IsInt()
  @Min(1)
  @Max(20)
  batchSize?: number;
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

  @Post('admin/lessons/:lessonId/generate-vocabulary')
  @UseGuards(AuthGuard('jwt'), RolesGuard)
  @Roles(UserRole.ADMIN)
  @ApiBearerAuth()
  @ApiOperation({ summary: 'AI generate + insert vocabulary by lesson (Admin only)' })
  @ApiQuery({ name: 'count', required: false })
  @ApiQuery({ name: 'model', required: false })
  generateVocabulary(
    @Param('lessonId') lessonId: string,
    @Query('count', new DefaultValuePipe(10), ParseIntPipe) count: number,
    @Query('model') model?: string,
  ) {
    return this.aiService.generateAndInsertVocabulary(lessonId, count, model);
  }

  @Post('admin/lessons/:lessonId/generate-grammar')
  @UseGuards(AuthGuard('jwt'), RolesGuard)
  @Roles(UserRole.ADMIN)
  @ApiBearerAuth()
  @ApiOperation({ summary: 'AI generate + insert grammar by lesson (Admin only)' })
  @ApiQuery({ name: 'count', required: false })
  @ApiQuery({ name: 'model', required: false })
  generateGrammar(
    @Param('lessonId') lessonId: string,
    @Query('count', new DefaultValuePipe(5), ParseIntPipe) count: number,
    @Query('model') model?: string,
  ) {
    return this.aiService.generateAndInsertGrammar(lessonId, count, model);
  }

  @Post('admin/lessons/:lessonId/generate-dialogues')
  @UseGuards(AuthGuard('jwt'), RolesGuard)
  @Roles(UserRole.ADMIN)
  @ApiBearerAuth()
  @ApiOperation({ summary: 'AI generate + insert dialogues by lesson (Admin only)' })
  @ApiQuery({ name: 'count', required: false })
  @ApiQuery({ name: 'model', required: false })
  generateDialogues(
    @Param('lessonId') lessonId: string,
    @Query('count', new DefaultValuePipe(10), ParseIntPipe) count: number,
    @Query('model') model?: string,
  ) {
    return this.aiService.generateAndInsertDialogues(lessonId, count, model);
  }

  @Post('admin/lessons/:lessonId/generate-quizzes')
  @UseGuards(AuthGuard('jwt'), RolesGuard)
  @Roles(UserRole.ADMIN)
  @ApiBearerAuth()
  @ApiOperation({ summary: 'AI generate + insert quizzes by lesson (Admin only)' })
  @ApiQuery({ name: 'count', required: false })
  @ApiQuery({ name: 'model', required: false })
  generateQuizzes(
    @Param('lessonId') lessonId: string,
    @Query('count', new DefaultValuePipe(1), ParseIntPipe) count: number,
    @Query('model') model?: string,
  ) {
    return this.aiService.generateAndInsertQuizzes(lessonId, count, model);
  }

  @Post('admin/topik/generate-exam')
  @UseGuards(AuthGuard('jwt'), RolesGuard)
  @Roles(UserRole.ADMIN)
  @ApiBearerAuth()
  @ApiOperation({ summary: 'AI generate TOPIK exam payload for import (Admin only)' })
  @ApiQuery({ name: 'model', required: false })
  generateTopikExam(
    @Body() dto: GenerateTopikExamDto,
    @Query('model') model?: string,
  ) {
    return this.aiService.generateTopikExamPayload(
      {
        topikLevel: dto.topikLevel,
        year: dto.year,
        title: dto.title,
        status: dto.status,
        batchSize: dto.batchSize,
      },
      model,
    );
  }
}

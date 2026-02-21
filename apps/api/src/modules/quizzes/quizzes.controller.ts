import { Controller, Get, Post, Patch, Delete, Body, Param, Query, UseGuards } from '@nestjs/common';
import { ApiTags, ApiOperation, ApiBearerAuth, ApiQuery } from '@nestjs/swagger';
import { AuthGuard } from '@nestjs/passport';
import { UserRole } from '@prisma/client';
import { QuizzesService } from './quizzes.service';
import { CreateQuizDto, UpdateQuizDto, CreateQuestionDto, UpdateQuestionDto, SubmitQuizDto } from './dto/quiz.dto';
import { Roles } from '../../common/decorators/roles.decorator';
import { RolesGuard } from '../../common/guards/roles.guard';
import { CurrentUser } from '../../common/decorators/current-user.decorator';

@ApiTags('quizzes')
@Controller('quizzes')
export class QuizzesController {
  constructor(private quizzesService: QuizzesService) {}

  @Post()
  @UseGuards(AuthGuard('jwt'), RolesGuard) @Roles(UserRole.ADMIN) @ApiBearerAuth()
  @ApiOperation({ summary: 'Create quiz (Admin only)' })
  createQuiz(@Body() dto: CreateQuizDto) { return this.quizzesService.createQuiz(dto); }

  @Get()
  @ApiOperation({ summary: 'Get quizzes by lesson' })
  @ApiQuery({ name: 'lessonId', required: true })
  findByLesson(@Query('lessonId') lessonId: string) { return this.quizzesService.findByLesson(lessonId); }

  @Get(':id')
  @ApiOperation({ summary: 'Get quiz by ID' })
  findOne(@Param('id') id: string) { return this.quizzesService.findOneQuiz(id); }

  @Patch(':id')
  @UseGuards(AuthGuard('jwt'), RolesGuard) @Roles(UserRole.ADMIN) @ApiBearerAuth()
  @ApiOperation({ summary: 'Update quiz (Admin only)' })
  updateQuiz(@Param('id') id: string, @Body() dto: UpdateQuizDto) { return this.quizzesService.updateQuiz(id, dto); }

  @Delete(':id')
  @UseGuards(AuthGuard('jwt'), RolesGuard) @Roles(UserRole.ADMIN) @ApiBearerAuth()
  @ApiOperation({ summary: 'Delete quiz (Admin only)' })
  removeQuiz(@Param('id') id: string) { return this.quizzesService.removeQuiz(id); }

  @Post('bulk-delete')
  @UseGuards(AuthGuard('jwt'), RolesGuard) @Roles(UserRole.ADMIN) @ApiBearerAuth()
  @ApiOperation({ summary: 'Bulk delete quizzes (Admin only)' })
  bulkDelete(@Body() body: { ids: string[] }) {
    return this.quizzesService.removeMany(body?.ids || []);
  }

  @Post('questions')
  @UseGuards(AuthGuard('jwt'), RolesGuard) @Roles(UserRole.ADMIN) @ApiBearerAuth()
  @ApiOperation({ summary: 'Create question (Admin only)' })
  createQuestion(@Body() dto: CreateQuestionDto) { return this.quizzesService.createQuestion(dto); }

  @Patch('questions/:id')
  @UseGuards(AuthGuard('jwt'), RolesGuard) @Roles(UserRole.ADMIN) @ApiBearerAuth()
  @ApiOperation({ summary: 'Update question (Admin only)' })
  updateQuestion(@Param('id') id: string, @Body() dto: UpdateQuestionDto) { return this.quizzesService.updateQuestion(id, dto); }

  @Delete('questions/:id')
  @UseGuards(AuthGuard('jwt'), RolesGuard) @Roles(UserRole.ADMIN) @ApiBearerAuth()
  @ApiOperation({ summary: 'Delete question (Admin only)' })
  removeQuestion(@Param('id') id: string) { return this.quizzesService.removeQuestion(id); }

  @Post(':id/submit')
  @UseGuards(AuthGuard('jwt'))
  @ApiBearerAuth()
  @ApiOperation({ summary: 'Submit quiz answers' })
  submit(@Param('id') id: string, @CurrentUser('id') userId: string, @Body() dto: SubmitQuizDto) {
    return this.quizzesService.submitQuizAnswer(id, userId, dto.answers);
  }
}

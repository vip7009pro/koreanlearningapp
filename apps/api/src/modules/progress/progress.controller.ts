import { Controller, Get, Post, Body, Param, UseGuards } from '@nestjs/common';
import { ApiTags, ApiOperation, ApiBearerAuth } from '@nestjs/swagger';
import { AuthGuard } from '@nestjs/passport';
import { ProgressService } from './progress.service';
import { UpdateProgressDto } from './dto/progress.dto';
import { CurrentUser } from '../../common/decorators/current-user.decorator';

@ApiTags('progress')
@Controller('progress')
@UseGuards(AuthGuard('jwt'))
@ApiBearerAuth()
export class ProgressController {
  constructor(private progressService: ProgressService) {}

  @Get()
  @ApiOperation({ summary: 'Get user progress for all lessons' })
  getUserProgress(@CurrentUser('id') userId: string) {
    return this.progressService.getUserProgress(userId);
  }

  @Get('lesson/:lessonId')
  @ApiOperation({ summary: 'Get progress for specific lesson' })
  getLessonProgress(@CurrentUser('id') userId: string, @Param('lessonId') lessonId: string) {
    return this.progressService.getLessonProgress(userId, lessonId);
  }

  @Get('course/:courseId')
  @ApiOperation({ summary: 'Get overall course progress' })
  getCourseProgress(@CurrentUser('id') userId: string, @Param('courseId') courseId: string) {
    return this.progressService.getCourseProgress(userId, courseId);
  }

  @Post()
  @ApiOperation({ summary: 'Update lesson progress' })
  update(@CurrentUser('id') userId: string, @Body() dto: UpdateProgressDto) {
    return this.progressService.updateProgress(userId, dto);
  }
}

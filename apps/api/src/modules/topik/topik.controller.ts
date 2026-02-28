import { Body, Controller, Get, Param, Post, Query, UseGuards } from '@nestjs/common';
import { ApiBearerAuth, ApiOperation, ApiTags } from '@nestjs/swagger';
import { AuthGuard } from '@nestjs/passport';
import { CurrentUser } from '../../common/decorators/current-user.decorator';
import { TopikService } from './topik.service';
import {
  SaveTopikAnswerDto,
  StartTopikSessionDto,
  SubmitTopikSessionDto,
  TopikExamQueryDto,
} from './dto/topik.dto';

@ApiTags('topik')
@Controller('topik')
export class TopikController {
  constructor(private readonly topikService: TopikService) {}

  @Get('exams')
  @UseGuards(AuthGuard('jwt'))
  @ApiBearerAuth()
  @ApiOperation({ summary: 'List published TOPIK exams (with my status)' })
  listExams(@CurrentUser('id') userId: string, @Query() query: TopikExamQueryDto) {
    return this.topikService.listPublishedExams({
      ...query,
      userId,
    });
  }

  @Get('exams/:id')
  @UseGuards(AuthGuard('jwt'))
  @ApiBearerAuth()
  @ApiOperation({ summary: 'Get published exam detail (includes sections/questions)' })
  getExam(@CurrentUser('id') userId: string, @Param('id') id: string) {
    return this.topikService.getExamDetail(id, userId);
  }

  @Post('sessions/start')
  @UseGuards(AuthGuard('jwt'))
  @ApiBearerAuth()
  @ApiOperation({ summary: 'Start or resume an in-progress session' })
  start(@CurrentUser('id') userId: string, @Body() dto: StartTopikSessionDto) {
    return this.topikService.startSession(userId, dto.examId, dto.sectionTypes);
  }

  @Post('sessions/:id/answer')
  @UseGuards(AuthGuard('jwt'))
  @ApiBearerAuth()
  @ApiOperation({ summary: 'Autosave answer + remaining time + current question index' })
  saveAnswer(
    @CurrentUser('id') userId: string,
    @Param('id') sessionId: string,
    @Body() dto: SaveTopikAnswerDto,
  ) {
    return this.topikService.saveAnswer(sessionId, userId, dto);
  }

  @Post('sessions/:id/submit')
  @UseGuards(AuthGuard('jwt'))
  @ApiBearerAuth()
  @ApiOperation({ summary: 'Submit session and compute score (MCQ/short text); AI review runs async for essays' })
  submit(
    @CurrentUser('id') userId: string,
    @Param('id') sessionId: string,
    @Body() dto: SubmitTopikSessionDto,
  ) {
    return this.topikService.submitSession(sessionId, userId, dto);
  }

  @Get('sessions/:id/review')
  @UseGuards(AuthGuard('jwt'))
  @ApiBearerAuth()
  @ApiOperation({ summary: 'Get review (answers, correctness, explanations, section scores, AI feedback if ready)' })
  review(@CurrentUser('id') userId: string, @Param('id') sessionId: string) {
    return this.topikService.getSessionReview(sessionId, userId);
  }
}

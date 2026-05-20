import { Controller, Get, Post, Body, Param, UseGuards } from '@nestjs/common';
import { ApiTags, ApiOperation, ApiBearerAuth, ApiProperty } from '@nestjs/swagger';
import { AuthGuard } from '@nestjs/passport';
import { AIDialoguesService } from './ai-dialogues.service';
import { CurrentUser } from '../../common/decorators/current-user.decorator';
import { IsString, IsNotEmpty } from 'class-validator';

class CreateSessionDto {
  @ApiProperty({ example: 'scenario-uuid' })
  @IsString()
  @IsNotEmpty()
  scenarioId: string;
}

class SubmitTurnDto {
  @ApiProperty({ example: '안녕하세요!' })
  @IsString()
  @IsNotEmpty()
  userAnswer: string;
}

@ApiTags('ai-dialogues')
@Controller('ai-dialogues')
@UseGuards(AuthGuard('jwt'))
@ApiBearerAuth()
export class AIDialoguesController {
  constructor(private readonly aiDialoguesService: AIDialoguesService) {}

  @Get('scenarios')
  @ApiOperation({ summary: 'Get all AI dialogue roleplay scenarios' })
  getScenarios() {
    return this.aiDialoguesService.getScenarios();
  }

  @Post('sessions')
  @ApiOperation({ summary: 'Start a new AI dialogue session' })
  createSession(@CurrentUser('id') userId: string, @Body() dto: CreateSessionDto) {
    return this.aiDialoguesService.createSession(userId, dto.scenarioId);
  }

  @Get('sessions/:id/history')
  @ApiOperation({ summary: 'Get dialogue session history' })
  getSessionHistory(@CurrentUser('id') userId: string, @Param('id') sessionId: string) {
    return this.aiDialoguesService.getSessionHistory(userId, sessionId);
  }

  @Post('sessions/:id/turn')
  @ApiOperation({ summary: 'Submit user response turn and get AI feedback + next turn' })
  submitTurn(
    @CurrentUser('id') userId: string,
    @Param('id') sessionId: string,
    @Body() dto: SubmitTurnDto,
  ) {
    return this.aiDialoguesService.submitTurn(userId, sessionId, dto.userAnswer);
  }
}

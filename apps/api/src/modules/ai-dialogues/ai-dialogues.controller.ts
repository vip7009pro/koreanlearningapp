import { Controller, Get, Post, Patch, Delete, Body, Param, UseGuards } from '@nestjs/common';
import { ApiTags, ApiOperation, ApiBearerAuth, ApiProperty } from '@nestjs/swagger';
import { AuthGuard } from '@nestjs/passport';
import { AIDialoguesService } from './ai-dialogues.service';
import { CurrentUser } from '../../common/decorators/current-user.decorator';
import { IsString, IsNotEmpty, IsOptional, IsEnum } from 'class-validator';
import { Roles } from '../../common/decorators/roles.decorator';
import { RolesGuard } from '../../common/guards/roles.guard';
import { UserRole, Difficulty } from '@prisma/client';

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

class CreateScenarioDto {
  @ApiProperty({ example: 'Phỏng vấn xin việc tại công ty Hàn Quốc' })
  @IsString()
  @IsNotEmpty()
  title: string;

  @ApiProperty({ example: 'Luyện tập hội thoại phỏng vấn...' })
  @IsString()
  @IsNotEmpty()
  description: string;

  @ApiProperty({ example: 'HARD', enum: Difficulty })
  @IsEnum(Difficulty)
  @IsNotEmpty()
  difficulty: Difficulty;

  @ApiProperty({ example: 'Bạn là Giám đốc Nhân sự...' })
  @IsString()
  @IsNotEmpty()
  initialPrompt: string;

  @ApiProperty({ example: '안녕하세요!...' })
  @IsString()
  @IsNotEmpty()
  starterMessage: string;
}

class UpdateScenarioDto {
  @ApiProperty({ example: 'Phỏng vấn xin việc...', required: false })
  @IsString()
  @IsOptional()
  title?: string;

  @ApiProperty({ example: 'Luyện tập...', required: false })
  @IsString()
  @IsOptional()
  description?: string;

  @ApiProperty({ example: 'HARD', enum: Difficulty, required: false })
  @IsEnum(Difficulty)
  @IsOptional()
  difficulty?: Difficulty;

  @ApiProperty({ example: 'Bạn là...', required: false })
  @IsString()
  @IsOptional()
  initialPrompt?: string;

  @ApiProperty({ example: '안녕하세요!...', required: false })
  @IsString()
  @IsOptional()
  starterMessage?: string;
}

@ApiTags('ai-dialogues')
@Controller('ai-dialogues')
@UseGuards(AuthGuard('jwt'), RolesGuard)
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

  @Get('scenarios/:scenarioId/sessions')
  @ApiOperation({ summary: 'Get dialogue sessions of the current user for a specific scenario' })
  getSessionsByScenario(
    @CurrentUser('id') userId: string,
    @Param('scenarioId') scenarioId: string,
  ) {
    return this.aiDialoguesService.getSessionsByScenario(userId, scenarioId);
  }

  @Delete('sessions/:id')
  @ApiOperation({ summary: 'Delete a dialogue session' })
  deleteSession(@CurrentUser('id') userId: string, @Param('id') sessionId: string) {
    return this.aiDialoguesService.deleteSession(userId, sessionId);
  }

  @Post('scenarios')
  @Roles(UserRole.ADMIN)
  @ApiOperation({ summary: 'Create a new dialogue scenario (Admin only)' })
  createScenario(@Body() dto: CreateScenarioDto) {
    return this.aiDialoguesService.createScenario(dto);
  }

  @Patch('scenarios/:id')
  @Roles(UserRole.ADMIN)
  @ApiOperation({ summary: 'Update a dialogue scenario (Admin only)' })
  updateScenario(@Param('id') id: string, @Body() dto: UpdateScenarioDto) {
    return this.aiDialoguesService.updateScenario(id, dto);
  }

  @Delete('scenarios/:id')
  @Roles(UserRole.ADMIN)
  @ApiOperation({ summary: 'Delete a dialogue scenario (Admin only)' })
  deleteScenario(@Param('id') id: string) {
    return this.aiDialoguesService.deleteScenario(id);
  }
}

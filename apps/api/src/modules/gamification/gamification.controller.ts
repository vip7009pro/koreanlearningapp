import { Controller, Get, Post, Body, Query, UseGuards } from '@nestjs/common';
import { ApiTags, ApiOperation, ApiBearerAuth, ApiQuery } from '@nestjs/swagger';
import { AuthGuard } from '@nestjs/passport';
import { GamificationService } from './gamification.service';
import { CurrentUser } from '../../common/decorators/current-user.decorator';
import { IsInt, Min } from 'class-validator';
import { ApiProperty } from '@nestjs/swagger';

class AddXPDto {
  @ApiProperty({ example: 10 }) @IsInt() @Min(1) amount: number;
}

class SetDailyGoalDto {
  @ApiProperty({ example: 100 }) @IsInt() @Min(10) targetXP: number;
}

@ApiTags('gamification')
@Controller('gamification')
export class GamificationController {
  constructor(private gamificationService: GamificationService) {}

  @Post('xp')
  @UseGuards(AuthGuard('jwt')) @ApiBearerAuth()
  @ApiOperation({ summary: 'Add XP to user' })
  addXP(@CurrentUser('id') userId: string, @Body() dto: AddXPDto) {
    return this.gamificationService.addXP(userId, dto.amount);
  }

  @Post('streak')
  @UseGuards(AuthGuard('jwt')) @ApiBearerAuth()
  @ApiOperation({ summary: 'Update user streak' })
  updateStreak(@CurrentUser('id') userId: string) {
    return this.gamificationService.updateStreak(userId);
  }

  @Get('leaderboard')
  @ApiOperation({ summary: 'Get leaderboard' })
  @ApiQuery({ name: 'limit', required: false })
  getLeaderboard(@Query('limit') limit = 20) {
    return this.gamificationService.getLeaderboard(limit);
  }

  @Get('badges')
  @UseGuards(AuthGuard('jwt')) @ApiBearerAuth()
  @ApiOperation({ summary: 'Get user badges' })
  getUserBadges(@CurrentUser('id') userId: string) {
    return this.gamificationService.getUserBadges(userId);
  }

  @Get('badges/all')
  @ApiOperation({ summary: 'Get all available badges' })
  getAllBadges() {
    return this.gamificationService.getAllBadges();
  }

  @Get('daily-goal')
  @UseGuards(AuthGuard('jwt')) @ApiBearerAuth()
  @ApiOperation({ summary: 'Get daily goal' })
  getDailyGoal(@CurrentUser('id') userId: string) {
    return this.gamificationService.getDailyGoal(userId);
  }

  @Post('daily-goal')
  @UseGuards(AuthGuard('jwt')) @ApiBearerAuth()
  @ApiOperation({ summary: 'Set daily goal target' })
  setDailyGoalTarget(@CurrentUser('id') userId: string, @Body() dto: SetDailyGoalDto) {
    return this.gamificationService.setDailyGoalTarget(userId, dto.targetXP);
  }
}

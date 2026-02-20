import { Controller, Get, Post, Body, Query, UseGuards } from '@nestjs/common';
import { ApiTags, ApiOperation, ApiBearerAuth, ApiQuery } from '@nestjs/swagger';
import { AuthGuard } from '@nestjs/passport';
import { UserRole } from '@prisma/client';
import { AnalyticsService } from './analytics.service';
import { CurrentUser } from '../../common/decorators/current-user.decorator';
import { Roles } from '../../common/decorators/roles.decorator';
import { RolesGuard } from '../../common/guards/roles.guard';
import { IsString, IsOptional } from 'class-validator';
import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';

class TrackEventDto {
  @ApiProperty({ example: 'LESSON_COMPLETED' }) @IsString() eventType: string;
  @ApiPropertyOptional() @IsOptional() metadata?: Record<string, unknown>;
}

@ApiTags('analytics')
@Controller('analytics')
export class AnalyticsController {
  constructor(private analyticsService: AnalyticsService) {}

  @Post('track')
  @UseGuards(AuthGuard('jwt')) @ApiBearerAuth()
  @ApiOperation({ summary: 'Track an analytics event' })
  track(@CurrentUser('id') userId: string, @Body() dto: TrackEventDto) {
    return this.analyticsService.trackEvent(userId, dto.eventType, dto.metadata || {});
  }

  @Get('dashboard')
  @UseGuards(AuthGuard('jwt'), RolesGuard) @Roles(UserRole.ADMIN) @ApiBearerAuth()
  @ApiOperation({ summary: 'Get dashboard statistics (Admin only)' })
  getDashboard() { return this.analyticsService.getDashboardStats(); }

  @Get('events')
  @UseGuards(AuthGuard('jwt')) @ApiBearerAuth()
  @ApiOperation({ summary: 'Get user events' })
  @ApiQuery({ name: 'page', required: false }) @ApiQuery({ name: 'limit', required: false })
  getUserEvents(@CurrentUser('id') userId: string, @Query('page') page = 1, @Query('limit') limit = 50) {
    return this.analyticsService.getUserEvents(userId, page, limit);
  }

  @Get('events/type')
  @UseGuards(AuthGuard('jwt'), RolesGuard) @Roles(UserRole.ADMIN) @ApiBearerAuth()
  @ApiOperation({ summary: 'Get events by type (Admin only)' })
  @ApiQuery({ name: 'type', required: true }) @ApiQuery({ name: 'days', required: false })
  getByType(@Query('type') type: string, @Query('days') days = 30) {
    return this.analyticsService.getEventsByType(type, days);
  }
}

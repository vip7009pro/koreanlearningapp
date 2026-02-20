import { Controller, Get, Post, Body, Delete, UseGuards } from '@nestjs/common';
import { ApiTags, ApiOperation, ApiBearerAuth } from '@nestjs/swagger';
import { AuthGuard } from '@nestjs/passport';
import { SubscriptionsService } from './subscriptions.service';
import { CurrentUser } from '../../common/decorators/current-user.decorator';
import { IsEnum } from 'class-validator';
import { ApiProperty } from '@nestjs/swagger';
import { PlanType } from '@prisma/client';

class SubscribeDto {
  @ApiProperty({ enum: PlanType }) @IsEnum(PlanType) planType: PlanType;
}

@ApiTags('subscriptions')
@Controller('subscriptions')
export class SubscriptionsController {
  constructor(private subscriptionsService: SubscriptionsService) {}

  @Get('plans')
  @ApiOperation({ summary: 'Get available subscription plans' })
  getPlans() { return this.subscriptionsService.getPlans(); }

  @Get('current')
  @UseGuards(AuthGuard('jwt')) @ApiBearerAuth()
  @ApiOperation({ summary: 'Get current subscription' })
  getCurrent(@CurrentUser('id') userId: string) { return this.subscriptionsService.getCurrentSubscription(userId); }

  @Get('history')
  @UseGuards(AuthGuard('jwt')) @ApiBearerAuth()
  @ApiOperation({ summary: 'Get subscription history' })
  getHistory(@CurrentUser('id') userId: string) { return this.subscriptionsService.getSubscriptionHistory(userId); }

  @Post()
  @UseGuards(AuthGuard('jwt')) @ApiBearerAuth()
  @ApiOperation({ summary: 'Subscribe to a plan (mock payment)' })
  subscribe(@CurrentUser('id') userId: string, @Body() dto: SubscribeDto) {
    return this.subscriptionsService.subscribe(userId, dto.planType);
  }

  @Delete()
  @UseGuards(AuthGuard('jwt')) @ApiBearerAuth()
  @ApiOperation({ summary: 'Cancel subscription' })
  cancel(@CurrentUser('id') userId: string) { return this.subscriptionsService.cancelSubscription(userId); }

  @Get('check-premium')
  @UseGuards(AuthGuard('jwt')) @ApiBearerAuth()
  @ApiOperation({ summary: 'Check premium status' })
  checkPremium(@CurrentUser('id') userId: string) {
    return this.subscriptionsService.checkPremium(userId).then((isPremium) => ({ isPremium }));
  }
}

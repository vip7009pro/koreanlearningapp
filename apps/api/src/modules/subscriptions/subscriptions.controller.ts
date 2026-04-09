import { Controller, Get, Post, Body, Delete, UseGuards } from '@nestjs/common';
import { ApiTags, ApiOperation, ApiBearerAuth, ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import { AuthGuard } from '@nestjs/passport';
import { SubscriptionsService } from './subscriptions.service';
import { CurrentUser } from '../../common/decorators/current-user.decorator';
import { IsEnum, IsNotEmpty, IsOptional, IsString } from 'class-validator';
import { PlanType } from '@prisma/client';

class SubscribeDto {
  @ApiProperty({ enum: PlanType }) @IsEnum(PlanType) planType: PlanType;
}

class GooglePlayVerifyDto {
  @ApiProperty({ example: 'premium_monthly' })
  @IsString()
  @IsNotEmpty()
  productId: string;

  @ApiProperty({ example: 'purchase-token-from-google-play' })
  @IsString()
  @IsNotEmpty()
  purchaseToken: string;

  @ApiPropertyOptional({ example: 'com.hnp.korean_learning_app' })
  @IsOptional()
  @IsString()
  packageName?: string;

  @ApiPropertyOptional({ enum: PlanType })
  @IsOptional()
  @IsEnum(PlanType)
  planType?: PlanType;

  @ApiPropertyOptional({ example: 'GPA.1234-5678-9012-34567' })
  @IsOptional()
  @IsString()
  orderId?: string;
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

  @Post('google/verify')
  @UseGuards(AuthGuard('jwt')) @ApiBearerAuth()
  @ApiOperation({ summary: 'Verify a Google Play ad-free purchase' })
  verifyGooglePlay(@CurrentUser('id') userId: string, @Body() dto: GooglePlayVerifyDto) {
    return this.subscriptionsService.verifyGooglePlaySubscription(userId, dto);
  }

  @Delete()
  @UseGuards(AuthGuard('jwt')) @ApiBearerAuth()
  @ApiOperation({ summary: 'Cancel subscription' })
  cancel(@CurrentUser('id') userId: string) { return this.subscriptionsService.cancelSubscription(userId); }

  @Get('check-premium')
  @UseGuards(AuthGuard('jwt')) @ApiBearerAuth()
  @ApiOperation({ summary: 'Check ad-free status' })
  checkPremium(@CurrentUser('id') userId: string) {
    return this.subscriptionsService.checkPremium(userId).then((isPremium) => ({ isPremium }));
  }
}

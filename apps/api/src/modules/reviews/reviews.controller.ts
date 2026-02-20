import { Controller, Get, Post, Body, Query, UseGuards } from '@nestjs/common';
import { ApiTags, ApiOperation, ApiBearerAuth, ApiQuery } from '@nestjs/swagger';
import { AuthGuard } from '@nestjs/passport';
import { ReviewsService } from './reviews.service';
import { CurrentUser } from '../../common/decorators/current-user.decorator';
import { IsBoolean, IsUUID } from 'class-validator';
import { ApiProperty } from '@nestjs/swagger';

class AddReviewDto {
  @ApiProperty() @IsUUID() vocabularyId: string;
}

class SubmitReviewDto {
  @ApiProperty() @IsUUID() vocabularyId: string;
  @ApiProperty() @IsBoolean() correct: boolean;
}

@ApiTags('reviews')
@Controller('reviews')
@UseGuards(AuthGuard('jwt'))
@ApiBearerAuth()
export class ReviewsController {
  constructor(private reviewsService: ReviewsService) {}

  @Get('due')
  @ApiOperation({ summary: 'Get due vocabulary reviews' })
  @ApiQuery({ name: 'limit', required: false })
  getDueReviews(@CurrentUser('id') userId: string, @Query('limit') limit = 20) {
    return this.reviewsService.getDueReviews(userId, limit);
  }

  @Get()
  @ApiOperation({ summary: 'Get all vocabulary reviews' })
  getAllReviews(@CurrentUser('id') userId: string) {
    return this.reviewsService.getAllReviews(userId);
  }

  @Get('stats')
  @ApiOperation({ summary: 'Get review statistics' })
  getStats(@CurrentUser('id') userId: string) {
    return this.reviewsService.getReviewStats(userId);
  }

  @Post('add')
  @ApiOperation({ summary: 'Add vocabulary to review deck' })
  addToReview(@CurrentUser('id') userId: string, @Body() dto: AddReviewDto) {
    return this.reviewsService.addToReview(userId, dto.vocabularyId);
  }

  @Post('submit')
  @ApiOperation({ summary: 'Submit review result' })
  submitReview(@CurrentUser('id') userId: string, @Body() dto: SubmitReviewDto) {
    return this.reviewsService.submitReview(userId, dto.vocabularyId, dto.correct);
  }
}

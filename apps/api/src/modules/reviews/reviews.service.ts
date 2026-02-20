import { Injectable } from '@nestjs/common';
import { PrismaService } from '../../prisma/prisma.service';

@Injectable()
export class ReviewsService {
  constructor(private prisma: PrismaService) {}

  private calculateNextReview(level: number): Date {
    const intervals = [1, 3, 7, 14, 30, 60, 120]; // days
    const days = intervals[Math.min(level, intervals.length - 1)];
    const next = new Date();
    next.setDate(next.getDate() + days);
    return next;
  }

  async getDueReviews(userId: string, limit = 20) {
    return this.prisma.userVocabularyReview.findMany({
      where: { userId, nextReviewAt: { lte: new Date() } },
      include: { vocabulary: true },
      take: limit,
      orderBy: { nextReviewAt: 'asc' },
    });
  }

  async getAllReviews(userId: string) {
    return this.prisma.userVocabularyReview.findMany({
      where: { userId },
      include: { vocabulary: true },
      orderBy: { nextReviewAt: 'asc' },
    });
  }

  async addToReview(userId: string, vocabularyId: string) {
    return this.prisma.userVocabularyReview.upsert({
      where: { userId_vocabularyId: { userId, vocabularyId } },
      create: { userId, vocabularyId, reviewLevel: 0, nextReviewAt: new Date() },
      update: {},
    });
  }

  async submitReview(userId: string, vocabularyId: string, correct: boolean) {
    const review = await this.prisma.userVocabularyReview.findUnique({
      where: { userId_vocabularyId: { userId, vocabularyId } },
    });

    if (!review) {
      return this.addToReview(userId, vocabularyId);
    }

    const newLevel = correct ? review.reviewLevel + 1 : Math.max(0, review.reviewLevel - 1);
    const nextReviewAt = this.calculateNextReview(newLevel);

    return this.prisma.userVocabularyReview.update({
      where: { userId_vocabularyId: { userId, vocabularyId } },
      data: {
        reviewLevel: newLevel,
        nextReviewAt,
        correctStreak: correct ? review.correctStreak + 1 : 0,
        wrongCount: correct ? review.wrongCount : review.wrongCount + 1,
      },
    });
  }

  async getReviewStats(userId: string) {
    const [total, due, mastered] = await Promise.all([
      this.prisma.userVocabularyReview.count({ where: { userId } }),
      this.prisma.userVocabularyReview.count({ where: { userId, nextReviewAt: { lte: new Date() } } }),
      this.prisma.userVocabularyReview.count({ where: { userId, reviewLevel: { gte: 5 } } }),
    ]);
    return { total, due, mastered, learning: total - mastered };
  }
}

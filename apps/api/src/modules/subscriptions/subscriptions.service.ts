import { Injectable, NotFoundException } from '@nestjs/common';
import { PrismaService } from '../../prisma/prisma.service';
import { PlanType } from '@prisma/client';

@Injectable()
export class SubscriptionsService {
  constructor(private prisma: PrismaService) {}

  async getCurrentSubscription(userId: string) {
    return this.prisma.subscription.findFirst({
      where: { userId, status: 'ACTIVE' },
      orderBy: { createdAt: 'desc' },
    });
  }

  async getSubscriptionHistory(userId: string) {
    return this.prisma.subscription.findMany({
      where: { userId },
      orderBy: { createdAt: 'desc' },
    });
  }

  /**
   * Mock payment + subscription creation.
   * In production, integrate with actual payment provider (Stripe, PayPal, etc.)
   */
  async subscribe(userId: string, planType: PlanType) {
    // Cancel any existing active subscriptions
    await this.prisma.subscription.updateMany({
      where: { userId, status: 'ACTIVE' },
      data: { status: 'CANCELLED' },
    });

    const endDate = planType === 'LIFETIME'
      ? null
      : new Date(Date.now() + 30 * 24 * 60 * 60 * 1000); // 30 days

    const subscription = await this.prisma.subscription.create({
      data: {
        userId,
        planType,
        startDate: new Date(),
        endDate,
        status: 'ACTIVE',
      },
    });

    return {
      subscription,
      payment: {
        status: 'SUCCESS',
        amount: this.getPlanPrice(planType),
        currency: 'VND',
        transactionId: `MOCK_${Date.now()}`,
      },
    };
  }

  async cancelSubscription(userId: string) {
    const sub = await this.prisma.subscription.findFirst({
      where: { userId, status: 'ACTIVE' },
    });
    if (!sub) throw new NotFoundException('No active subscription found');

    return this.prisma.subscription.update({
      where: { id: sub.id },
      data: { status: 'CANCELLED' },
    });
  }

  async checkPremium(userId: string): Promise<boolean> {
    const sub = await this.prisma.subscription.findFirst({
      where: { userId, status: 'ACTIVE', planType: { in: ['PREMIUM', 'LIFETIME'] } },
    });
    if (!sub) return false;
    if (sub.planType === 'LIFETIME') return true;
    if (sub.endDate && new Date(sub.endDate) < new Date()) return false;
    return true;
  }

  getPlans() {
    return [
      { type: 'FREE', price: 0, currency: 'VND', features: ['5 bài học miễn phí', 'Từ vựng cơ bản', 'Bài kiểm tra giới hạn'] },
      { type: 'PREMIUM', price: 199000, currency: 'VND', duration: '30 ngày', features: ['Toàn bộ bài học', 'AI Writing Practice', 'Không giới hạn bài kiểm tra', 'Ôn tập SRS', 'Tải về học offline'] },
      { type: 'LIFETIME', price: 1990000, currency: 'VND', duration: 'Vĩnh viễn', features: ['Tất cả tính năng Premium', 'Cập nhật nội dung miễn phí', 'Ưu tiên hỗ trợ'] },
    ];
  }

  private getPlanPrice(planType: PlanType): number {
    switch (planType) {
      case 'FREE': return 0;
      case 'PREMIUM': return 199000;
      case 'LIFETIME': return 1990000;
      default: return 0;
    }
  }
}

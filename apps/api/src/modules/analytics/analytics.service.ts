import { Injectable } from '@nestjs/common';
import { PrismaService } from '../../prisma/prisma.service';

@Injectable()
export class AnalyticsService {
  constructor(private prisma: PrismaService) {}

  async trackEvent(userId: string, eventType: string, metadata: Record<string, unknown> = {}) {
    return this.prisma.analyticsEvent.create({
      data: { userId, eventType, metadata: metadata as any },
    });
  }

  async getUserEvents(userId: string, page = 1, limit = 50) {
    const skip = (page - 1) * limit;
    const [data, total] = await Promise.all([
      this.prisma.analyticsEvent.findMany({
        where: { userId },
        skip,
        take: limit,
        orderBy: { createdAt: 'desc' },
      }),
      this.prisma.analyticsEvent.count({ where: { userId } }),
    ]);
    return { data, total, page, limit, totalPages: Math.ceil(total / limit) };
  }

  async getDashboardStats() {
    const [totalUsers, totalCourses, totalLessons, totalVocab, activeSubscriptions] = await Promise.all([
      this.prisma.user.count(),
      this.prisma.course.count(),
      this.prisma.lesson.count(),
      this.prisma.vocabulary.count(),
      this.prisma.subscription.count({ where: { status: 'ACTIVE', planType: { not: 'FREE' } } }),
    ]);

    const recentEvents = await this.prisma.analyticsEvent.groupBy({
      by: ['eventType'],
      _count: { id: true },
      orderBy: { _count: { id: 'desc' } },
      take: 10,
    });

    const topLearners = await this.prisma.user.findMany({
      where: { role: 'USER' },
      orderBy: { totalXP: 'desc' },
      take: 5,
      select: { id: true, displayName: true, totalXP: true, streakDays: true },
    });

    return {
      totalUsers,
      totalCourses,
      totalLessons,
      totalVocab,
      activeSubscriptions,
      recentEvents: recentEvents.map((e: any) => ({ eventType: e.eventType, count: e._count.id })),
      topLearners,
    };
  }

  async getEventsByType(eventType: string, days = 30) {
    const since = new Date();
    since.setDate(since.getDate() - days);

    return this.prisma.analyticsEvent.findMany({
      where: { eventType, createdAt: { gte: since } },
      orderBy: { createdAt: 'desc' },
      take: 100,
    });
  }
}

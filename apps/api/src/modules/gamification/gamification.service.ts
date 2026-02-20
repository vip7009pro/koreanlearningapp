import { Injectable } from '@nestjs/common';
import { PrismaService } from '../../prisma/prisma.service';

@Injectable()
export class GamificationService {
  constructor(private prisma: PrismaService) {}

  async addXP(userId: string, amount: number) {
    const user = await this.prisma.user.update({
      where: { id: userId },
      data: { totalXP: { increment: amount } },
    });

    // Update or create daily goal
    const today = new Date();
    today.setHours(0, 0, 0, 0);
    await this.prisma.dailyGoal.upsert({
      where: { userId_date: { userId, date: today } },
      create: { userId, date: today, currentXP: amount, targetXP: 50, completed: amount >= 50 },
      update: { currentXP: { increment: amount }, completed: user.totalXP >= 50 },
    });

    // Check for badge unlocks
    await this.checkBadgeUnlocks(userId, user.totalXP);

    return { totalXP: user.totalXP, xpAdded: amount };
  }

  async updateStreak(userId: string) {
    const user = await this.prisma.user.findUnique({ where: { id: userId } });
    if (!user) return null;

    const now = new Date();
    const lastActive = new Date(user.lastActiveAt);
    const diffDays = Math.floor((now.getTime() - lastActive.getTime()) / (1000 * 60 * 60 * 24));

    let newStreak = user.streakDays;
    if (diffDays === 1) {
      newStreak++;
    } else if (diffDays > 1) {
      newStreak = 1;
    }

    return this.prisma.user.update({
      where: { id: userId },
      data: { streakDays: newStreak, lastActiveAt: now },
      select: { streakDays: true, lastActiveAt: true },
    });
  }

  async getLeaderboard(limit = 20) {
    const users = await this.prisma.user.findMany({
      where: { role: 'USER' },
      orderBy: { totalXP: 'desc' },
      take: limit,
      select: { id: true, displayName: true, avatarUrl: true, totalXP: true },
    });

    return users.map((user, index) => ({
      ...user,
      rank: index + 1,
    }));
  }

  async getUserBadges(userId: string) {
    return this.prisma.userBadge.findMany({
      where: { userId },
      include: { badge: true },
      orderBy: { earnedAt: 'desc' },
    });
  }

  async getAllBadges() {
    return this.prisma.badge.findMany({ orderBy: { requiredXP: 'asc' } });
  }

  async getDailyGoal(userId: string) {
    const today = new Date();
    today.setHours(0, 0, 0, 0);
    const goal = await this.prisma.dailyGoal.findUnique({
      where: { userId_date: { userId, date: today } },
    });
    return goal || { targetXP: 50, currentXP: 0, completed: false, date: today };
  }

  async setDailyGoalTarget(userId: string, targetXP: number) {
    const today = new Date();
    today.setHours(0, 0, 0, 0);
    return this.prisma.dailyGoal.upsert({
      where: { userId_date: { userId, date: today } },
      create: { userId, date: today, targetXP, currentXP: 0 },
      update: { targetXP },
    });
  }

  private async checkBadgeUnlocks(userId: string, totalXP: number) {
    const unownedBadges = await this.prisma.badge.findMany({
      where: {
        requiredXP: { lte: totalXP },
        userBadges: { none: { userId } },
      },
    });

    for (const badge of unownedBadges) {
      await this.prisma.userBadge.create({
        data: { userId, badgeId: badge.id },
      });
    }
  }
}

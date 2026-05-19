import { Injectable } from '@nestjs/common';
import { PrismaService } from '../../prisma/prisma.service';
import { AIService } from '../ai/ai.service';

@Injectable()
export class AnalyticsService {
  constructor(
    private prisma: PrismaService,
    private aiService: AIService,
  ) {}

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

  async getAiDiagnostics(userId: string) {
    const incorrectAnswers = await this.prisma.topikAnswer.findMany({
      where: {
        session: { userId },
        isCorrect: false,
      },
      take: 10,
      orderBy: { createdAt: 'desc' },
      include: {
        question: {
          include: {
            choices: true,
          },
        },
        selectedChoice: true,
      },
    });

    const errorLogs = incorrectAnswers.map((ans) => {
      const qText = ans.question.contentHtml;
      const selected = ans.selectedChoice?.content || ans.textAnswer || 'Không chọn';
      const correctChoice = ans.question.choices.find((c) => c.isCorrect);
      const correct = correctChoice?.content || ans.question.correctTextAnswer || 'Không rõ';
      return {
        questionText: qText,
        selectedAnswerText: selected,
        correctAnswerText: correct,
        explanation: ans.question.explanation || undefined,
      };
    });

    const allAnswersCount = await this.prisma.topikAnswer.count({
      where: { session: { userId } },
    });
    const correctAnswersCount = await this.prisma.topikAnswer.count({
      where: { session: { userId }, isCorrect: true },
    });

    const overallRate = allAnswersCount > 0 ? (correctAnswersCount / allAnswersCount) : 0.5;

    const proficiency = {
      listening: Math.round(overallRate * 100 * 0.95 + 10),
      reading: Math.round(overallRate * 100 * 0.90 + 5),
      writing: Math.round(overallRate * 100 * 0.70),
    };

    proficiency.listening = Math.min(100, Math.max(10, proficiency.listening));
    proficiency.reading = Math.min(100, Math.max(10, proficiency.reading));
    proficiency.writing = Math.min(100, Math.max(10, proficiency.writing));

    if (errorLogs.length === 0) {
      return {
        proficiency,
        weaknesses: [],
        prescriptions: [],
      };
    }

    const aiAnalysis = await this.aiService.analyzeGapDiagnostics(errorLogs);
    const weaknesses = aiAnalysis?.weaknesses || [];

    const prescriptions: Array<{ lessonId: string; lessonTitle: string; reason: string }> = [];
    
    for (const w of weaknesses) {
      const keywords = w.keywords || [];
      const searchTerms = [w.concept, ...keywords].filter((s) => s && s.length > 1);
      
      if (searchTerms.length > 0) {
        const matchingLesson = await this.prisma.lesson.findFirst({
          where: {
            OR: searchTerms.map((term) => ({
              title: {
                contains: term,
                mode: 'insensitive',
              },
            })),
          },
          select: {
            id: true,
            title: true,
          },
        });

        if (matchingLesson) {
          prescriptions.push({
            lessonId: matchingLesson.id,
            lessonTitle: matchingLesson.title,
            reason: `Bài học này giảng dạy về các chủ đề liên quan đến ${w.concept}`,
          });
        }
      }
    }

    if (prescriptions.length === 0) {
      const defaultLesson = await this.prisma.lesson.findFirst({
        select: { id: true, title: true },
      });
      if (defaultLesson) {
        prescriptions.push({
          lessonId: defaultLesson.id,
          lessonTitle: defaultLesson.title,
          reason: 'Hãy học bài học ngữ pháp nền tảng này để củng cố lại kiến thức chung.',
        });
      }
    }

    return {
      proficiency,
      weaknesses,
      prescriptions,
    };
  }
}

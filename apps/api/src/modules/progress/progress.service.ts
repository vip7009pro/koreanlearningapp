import { Injectable } from '@nestjs/common';
import { PrismaService } from '../../prisma/prisma.service';
import { UpdateProgressDto } from './dto/progress.dto';

@Injectable()
export class ProgressService {
  constructor(private prisma: PrismaService) {}

  async getUserProgress(userId: string) {
    return this.prisma.userProgress.findMany({
      where: { userId },
      include: { lesson: { include: { section: { include: { course: true } } } } },
      orderBy: { updatedAt: 'desc' },
    });
  }

  async getLessonProgress(userId: string, lessonId: string) {
    return this.prisma.userProgress.findUnique({
      where: { userId_lessonId: { userId, lessonId } },
    });
  }

  async updateProgress(userId: string, dto: UpdateProgressDto) {
    return this.prisma.userProgress.upsert({
      where: { userId_lessonId: { userId, lessonId: dto.lessonId } },
      create: {
        userId,
        lessonId: dto.lessonId,
        completed: dto.completed || false,
        score: dto.score || 0,
        completedAt: dto.completed ? new Date() : null,
      },
      update: {
        completed: dto.completed,
        score: dto.score,
        completedAt: dto.completed ? new Date() : undefined,
      },
    });
  }

  async getCourseProgress(userId: string, courseId: string) {
    const course = await this.prisma.course.findUnique({
      where: { id: courseId },
      include: {
        sections: {
          include: {
            lessons: {
              include: {
                progress: { where: { userId } },
              },
            },
          },
        },
      },
    });

    if (!course) return null;

    let totalLessons = 0;
    let completedLessons = 0;

    for (const section of course.sections) {
      for (const lesson of section.lessons) {
        totalLessons++;
        if (lesson.progress.some((p) => p.completed)) {
          completedLessons++;
        }
      }
    }

    return {
      courseId,
      totalLessons,
      completedLessons,
      percentage: totalLessons > 0 ? Math.round((completedLessons / totalLessons) * 100) : 0,
    };
  }
}

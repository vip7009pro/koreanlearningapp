import { Injectable, NotFoundException } from '@nestjs/common';
import { PrismaService } from '../../prisma/prisma.service';
import { CreateCourseDto, UpdateCourseDto } from './dto/course.dto';

@Injectable()
export class CoursesService {
  constructor(private prisma: PrismaService) {}

  async create(dto: CreateCourseDto) {
    return this.prisma.course.create({ data: dto });
  }

  async findAll(page = 1, limit = 20, level?: string, isPremium?: boolean) {
    const skip = (page - 1) * limit;
    const where: Record<string, unknown> = {};
    if (level) where.level = level;
    if (isPremium !== undefined) where.isPremium = isPremium;

    const [data, total] = await Promise.all([
      this.prisma.course.findMany({
        skip,
        take: limit,
        where,
        orderBy: { createdAt: 'desc' },
        include: {
          sections: {
            orderBy: { orderIndex: 'asc' },
            include: {
              lessons: { orderBy: { orderIndex: 'asc' } },
            },
          },
        },
      }),
      this.prisma.course.count({ where }),
    ]);

    return { data, total, page, limit, totalPages: Math.ceil(total / limit) };
  }

  async findOne(id: string) {
    const course = await this.prisma.course.findUnique({
      where: { id },
      include: {
        sections: {
          orderBy: { orderIndex: 'asc' },
          include: {
            lessons: { orderBy: { orderIndex: 'asc' } },
          },
        },
      },
    });
    if (!course) throw new NotFoundException('Course not found');
    return course;
  }

  async update(id: string, dto: UpdateCourseDto) {
    await this.findOne(id);
    return this.prisma.course.update({ where: { id }, data: dto });
  }

  async remove(id: string) {
    await this.findOne(id);
    await this.prisma.course.delete({ where: { id } });
    return { message: 'Course deleted successfully' };
  }

  async publish(id: string) {
    await this.findOne(id);
    return this.prisma.course.update({
      where: { id },
      data: { published: true },
    });
  }

  async unpublish(id: string) {
    await this.findOne(id);
    return this.prisma.course.update({
      where: { id },
      data: { published: false },
    });
  }

  async importCourse(data: any) {
    // Basic mapping to ensure structure fits Prisma create input
    const course = await this.prisma.course.create({
      data: {
        title: data.title,
        description: data.description,
        level: data.level || 'BEGINNER',
        isPremium: data.isPremium || false,
        published: true,
        thumbnailUrl: data.thumbnailUrl,
        sections: {
          create: (data.sections || []).map((sec: any, sIdx: number) => ({
            title: sec.title,
            orderIndex: sec.orderIndex ?? sIdx,
            lessons: {
              create: (sec.lessons || []).map((les: any, lIdx: number) => ({
                title: les.title,
                description: les.description || '',
                estimatedMinutes: les.estimatedMinutes || 10,
                orderIndex: les.orderIndex ?? lIdx,
                vocabularies: {
                  create: (les.vocabularies || []).map((voc: any) => ({
                    korean: voc.korean,
                    vietnamese: voc.vietnamese,
                    pronunciation: voc.pronunciation || '',
                    exampleSentence: voc.exampleSentence || '',
                    exampleMeaning: voc.exampleMeaning || '',
                    audioUrl: voc.audioUrl,
                    difficulty: voc.difficulty || 'EASY',
                  })),
                },
                grammars: {
                  create: (les.grammars || []).map((gr: any) => ({
                    pattern: gr.pattern,
                    explanationVN: gr.explanationVN,
                    example: gr.example,
                  })),
                },
                dialogues: {
                  create: (les.dialogues || []).map((di: any, dIdx: number) => ({
                    speaker: di.speaker,
                    koreanText: di.koreanText,
                    vietnameseText: di.vietnameseText,
                    audioUrl: di.audioUrl,
                    orderIndex: di.orderIndex ?? dIdx,
                  })),
                },
                quizzes: {
                  create: (les.quizzes || []).map((q: any) => ({
                    title: q.title,
                    quizType: q.quizType || 'MULTIPLE_CHOICE',
                    questions: {
                      create: (q.questions || []).map((qu: any, qIdx: number) => ({
                        questionType: qu.questionType || 'MULTIPLE_CHOICE',
                        questionText: qu.questionText || qu.content || `Câu hỏi ${qIdx + 1}`,
                        correctAnswer: qu.correctAnswer || '',
                        options: {
                          create: (qu.options || []).map((opt: any) => ({
                            text: opt.text,
                            isCorrect: opt.isCorrect || false,
                          })),
                        },
                      })),
                    },
                  })),
                },
              })),
            },
          })),
        },
      },
    });

    return course;
  }
}

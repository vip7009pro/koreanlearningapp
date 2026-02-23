import {
  BadRequestException,
  ForbiddenException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import {
  TopikExamStatus,
  TopikQuestionType,
  TopikSectionType,
  TopikSessionStatus,
  UserRole,
} from '@prisma/client';
import { PrismaService } from '../../prisma/prisma.service';
import { InjectQueue } from '@nestjs/bull';
import { Queue } from 'bull';
import { TOPIK_QUEUE, TOPIK_REVIEW_ESSAY_JOB } from './topik.queue';

@Injectable()
export class TopikService {
  constructor(
    private readonly prisma: PrismaService,
    @InjectQueue(TOPIK_QUEUE) private readonly topikQueue: Queue,
  ) {}

  private computeAchievedLevel(topikLevel: any, totalScore: number | null | undefined) {
    const score = typeof totalScore === 'number' ? totalScore : 0;

    // Official TOPIK score thresholds
    // TOPIK I (200): Level 1 >= 80, Level 2 >= 140
    // TOPIK II (300): Level 3 >= 120, Level 4 >= 150, Level 5 >= 190, Level 6 >= 230
    if (topikLevel === 'TOPIK_I') {
      if (score >= 140) return 2;
      if (score >= 80) return 1;
      return null;
    }

    if (topikLevel === 'TOPIK_II') {
      if (score >= 230) return 6;
      if (score >= 190) return 5;
      if (score >= 150) return 4;
      if (score >= 120) return 3;
      return null;
    }

    return null;
  }

  async listPublishedExams(filters: {
    topikLevel?: any;
    year?: number;
    level?: string;
    types?: TopikSectionType[];
    userId?: string;
  }) {
    const where: any = {
      status: TopikExamStatus.PUBLISHED,
      ...(filters.topikLevel ? { topikLevel: filters.topikLevel } : {}),
      ...(filters.year ? { year: filters.year } : {}),
      ...(filters.level ? { level: filters.level } : {}),
      ...(filters.types && filters.types.length
        ? { sections: { some: { type: { in: filters.types } } } }
        : {}),
    };

    const exams = await this.prisma.topikExam.findMany({
      where,
      orderBy: [{ year: 'desc' }, { createdAt: 'desc' }],
      include: {
        sections: {
          orderBy: { orderIndex: 'asc' },
          select: { id: true, type: true, orderIndex: true, durationMinutes: true, maxScore: true },
        },
      },
    });

    if (!filters.userId) return exams;

    const examIds = exams.map((e) => e.id);
    const sessions = await this.prisma.topikSession.groupBy({
      by: ['examId', 'status'],
      where: { userId: filters.userId, examId: { in: examIds } },
      _count: { _all: true },
      _max: { totalScore: true },
    });

    const inProgress = new Map<string, number>();
    const submitted = new Map<string, { attempts: number; bestScore: number | null }>();

    for (const s of sessions) {
      if (s.status === TopikSessionStatus.IN_PROGRESS) {
        inProgress.set(s.examId, (s._count as any)?._all || 0);
      } else if (s.status === TopikSessionStatus.SUBMITTED) {
        const prev = submitted.get(s.examId) || { attempts: 0, bestScore: null };
        const attempts = prev.attempts + ((s._count as any)?._all || 0);
        const best =
          typeof (s._max as any)?.totalScore === 'number'
            ? Math.max(prev.bestScore ?? 0, (s._max as any).totalScore)
            : prev.bestScore;
        submitted.set(s.examId, { attempts, bestScore: best });
      }
    }

    return exams.map((e) => {
      const sub = submitted.get(e.id);
      return {
        ...e,
        myStatus:
          inProgress.get(e.id) && inProgress.get(e.id)! > 0
            ? 'IN_PROGRESS'
            : sub && sub.attempts > 0
              ? 'COMPLETED'
              : 'NOT_STARTED',
        myAttempts: (inProgress.get(e.id) || 0) + (sub?.attempts || 0),
        myBestScore: sub?.bestScore ?? null,
      };
    });
  }

  async getExamDetail(examId: string, userId?: string) {
    const exam = await this.prisma.topikExam.findFirst({
      where: { id: examId, status: TopikExamStatus.PUBLISHED },
      include: {
        sections: {
          orderBy: { orderIndex: 'asc' },
          include: {
            // include maxScore for mobile UI
            questions: {
              orderBy: { orderIndex: 'asc' },
              include: { choices: { orderBy: { orderIndex: 'asc' } } },
            },
          },
        },
      },
    });

    if (!exam) throw new NotFoundException('Exam not found');

    let mySession: any = null;
    if (userId) {
      mySession = await this.prisma.topikSession.findFirst({
        where: {
          userId,
          examId,
          status: TopikSessionStatus.IN_PROGRESS,
        },
        orderBy: { updatedAt: 'desc' },
        include: { answers: true },
      });
    }

    return { exam, mySession };
  }

  async startSession(userId: string, examId: string) {
    const exam = await this.prisma.topikExam.findFirst({
      where: { id: examId, status: TopikExamStatus.PUBLISHED },
    });
    if (!exam) throw new NotFoundException('Exam not found');

    const existing = await this.prisma.topikSession.findFirst({
      where: { userId, examId, status: TopikSessionStatus.IN_PROGRESS },
      orderBy: { updatedAt: 'desc' },
    });
    if (existing) return existing;

    const remainingSeconds = Math.max(60, exam.durationMinutes * 60);
    const expiresAt = new Date(Date.now() + remainingSeconds * 1000);

    return this.prisma.topikSession.create({
      data: {
        userId,
        examId,
        status: TopikSessionStatus.IN_PROGRESS,
        remainingSeconds,
        expiresAt,
        currentQuestionIndex: 0,
      },
    });
  }

  private async requireActiveSession(sessionId: string, userId: string) {
    const session = await this.prisma.topikSession.findUnique({
      where: { id: sessionId },
      include: {
        exam: true,
      },
    });
    if (!session) throw new NotFoundException('Session not found');
    if (session.userId !== userId) throw new ForbiddenException('Forbidden');

    if (session.status !== TopikSessionStatus.IN_PROGRESS) {
      throw new BadRequestException('Session is not active');
    }

    if (session.expiresAt && session.expiresAt.getTime() <= Date.now()) {
      await this.expireSession(session.id);
      throw new BadRequestException('Session expired');
    }

    return session;
  }

  async saveAnswer(sessionId: string, userId: string, dto: {
    questionId: string;
    selectedChoiceId?: string;
    textAnswer?: string;
    currentQuestionIndex?: number;
    remainingSeconds?: number;
    flagged?: boolean;
  }) {
    const session = await this.requireActiveSession(sessionId, userId);

    const question = await this.prisma.topikQuestion.findUnique({
      where: { id: dto.questionId },
      include: { choices: true, section: true },
    });
    if (!question) throw new NotFoundException('Question not found');

    if (question.section.examId !== session.examId) {
      throw new BadRequestException('Question does not belong to this exam');
    }

    const updateData: any = {
      ...(dto.selectedChoiceId !== undefined
        ? { selectedChoiceId: dto.selectedChoiceId }
        : {}),
      ...(dto.textAnswer !== undefined ? { textAnswer: dto.textAnswer } : {}),
      ...(dto.flagged !== undefined ? { flagged: dto.flagged } : {}),
    };

    const answer = await this.prisma.topikAnswer.upsert({
      where: { sessionId_questionId: { sessionId, questionId: dto.questionId } },
      create: {
        sessionId,
        questionId: dto.questionId,
        selectedChoiceId: dto.selectedChoiceId,
        textAnswer: dto.textAnswer,
        flagged: dto.flagged ?? false,
      },
      update: updateData,
    });

    const remainingSeconds =
      typeof dto.remainingSeconds === 'number' && dto.remainingSeconds >= 0
        ? Math.min(dto.remainingSeconds, session.exam.durationMinutes * 60)
        : session.remainingSeconds;

    const currentQuestionIndex =
      typeof dto.currentQuestionIndex === 'number' && dto.currentQuestionIndex >= 0
        ? dto.currentQuestionIndex
        : session.currentQuestionIndex;

    const expiresAt = new Date(Date.now() + remainingSeconds * 1000);

    await this.prisma.topikSession.update({
      where: { id: sessionId },
      data: {
        remainingSeconds,
        currentQuestionIndex,
        expiresAt,
      },
    });

    return answer;
  }

  async submitSession(sessionId: string, userId: string, dto: { remainingSeconds?: number }) {
    const session = await this.requireActiveSession(sessionId, userId);

    const remainingSeconds =
      typeof dto.remainingSeconds === 'number' && dto.remainingSeconds >= 0
        ? Math.min(dto.remainingSeconds, session.exam.durationMinutes * 60)
        : session.remainingSeconds;

    const questions = await this.prisma.topikQuestion.findMany({
      where: { section: { examId: session.examId } },
      include: { choices: true, section: true },
      orderBy: [{ examSectionId: 'asc' }, { orderIndex: 'asc' }],
    });

    const answers = await this.prisma.topikAnswer.findMany({
      where: { sessionId },
    });

    const answerByQ = new Map<string, any>();
    for (const a of answers) answerByQ.set(a.questionId, a);

    let total = 0;
    const updates: any[] = [];

    for (const q of questions) {
      const a = answerByQ.get(q.id);
      if (!a) continue;

      if (q.questionType === TopikQuestionType.MCQ) {
        const correctChoice = q.choices.find((c) => c.isCorrect);
        const isCorrect = !!correctChoice && a.selectedChoiceId === correctChoice.id;
        const score = isCorrect ? q.scoreWeight : 0;
        total += score;
        updates.push(
          this.prisma.topikAnswer.update({
            where: { id: a.id },
            data: { isCorrect, score },
          }),
        );
      } else if (q.questionType === TopikQuestionType.SHORT_TEXT) {
        const expected = (q.correctTextAnswer || '').trim().toLowerCase();
        const got = String(a.textAnswer || '').trim().toLowerCase();
        const isCorrect = expected.length > 0 && got === expected;
        const score = isCorrect ? q.scoreWeight : 0;
        total += score;
        updates.push(
          this.prisma.topikAnswer.update({
            where: { id: a.id },
            data: { isCorrect, score },
          }),
        );
      }
    }

    if (updates.length) await this.prisma.$transaction(updates);

    const submittedAt = new Date();
    const updated = await this.prisma.topikSession.update({
      where: { id: sessionId },
      data: {
        status: TopikSessionStatus.SUBMITTED,
        submittedAt,
        remainingSeconds,
        totalScore: total,
      },
    });

    // Enqueue AI reviews for ESSAY answers
    void this.enqueueEssayReviews(sessionId).catch(() => undefined);

    return updated;
  }

  private async enqueueEssayReviews(sessionId: string) {
    const answers = await this.prisma.topikAnswer.findMany({
      where: {
        sessionId,
        aiReviewedAt: null,
        question: { questionType: TopikQuestionType.ESSAY },
      },
      select: { id: true },
      take: 50,
    });

    for (const a of answers) {
      await this.topikQueue.add(
        TOPIK_REVIEW_ESSAY_JOB,
        { answerId: a.id },
        {
          attempts: 3,
          backoff: { type: 'exponential', delay: 2000 },
          removeOnComplete: true,
          removeOnFail: 100,
        },
      );
    }
  }

  private async expireSession(sessionId: string) {
    await this.prisma.topikSession.update({
      where: { id: sessionId },
      data: {
        status: TopikSessionStatus.EXPIRED,
        submittedAt: new Date(),
        remainingSeconds: 0,
      },
    });
  }

  async getSessionReview(sessionId: string, userId: string) {
    const session = await this.prisma.topikSession.findUnique({
      where: { id: sessionId },
      include: {
        exam: true,
        answers: {
          include: {
            question: {
              include: {
                choices: { orderBy: { orderIndex: 'asc' } },
                section: true,
              },
            },
            selectedChoice: true,
          },
        },
      },
    });

    if (!session) throw new NotFoundException('Session not found');
    if (session.userId !== userId) throw new ForbiddenException('Forbidden');

    const bySection: Record<string, { type: TopikSectionType; score: number; maxScore: number }> = {};

    for (const a of session.answers) {
      const type = a.question.section.type;
      const key = type;
      if (!bySection[key]) {
        bySection[key] = {
          type,
          score: 0,
          // Prefer section.maxScore (official = 100), fallback to sum of question weights
          maxScore: typeof (a.question.section as any)?.maxScore === 'number' ? (a.question.section as any).maxScore : 0,
        };
      }
      bySection[key].score += a.score || 0;
      if (bySection[key].maxScore === 0) bySection[key].maxScore += a.question.scoreWeight;
    }

    const sectionScores = Object.values(bySection);
    const maxTotalScore = sectionScores.reduce((sum, s) => sum + (s.maxScore || 0), 0);
    const achievedLevel = this.computeAchievedLevel((session.exam as any).topikLevel, session.totalScore);

    return {
      session,
      sectionScores,
      maxTotalScore,
      achievedLevel,
    };
  }

  // Admin
  async adminCreateExam(dto: {
    title: string;
    year: number;
    topikLevel: any;
    level?: string;
    durationMinutes: number;
    totalQuestions: number;
    status?: TopikExamStatus;
    createdBy?: string;
  }) {
    return this.prisma.topikExam.create({
      data: {
        title: dto.title,
        year: dto.year,
        topikLevel: dto.topikLevel,
        level: dto.level,
        durationMinutes: dto.durationMinutes,
        totalQuestions: dto.totalQuestions,
        status: dto.status || TopikExamStatus.DRAFT,
        createdBy: dto.createdBy,
      },
    });
  }

  async adminUpdateExam(id: string, dto: any) {
    return this.prisma.topikExam.update({
      where: { id },
      data: dto,
    });
  }

  async adminCreateSection(dto: {
    examId: string;
    type: TopikSectionType;
    orderIndex: number;
    durationMinutes?: number;
    maxScore?: number;
  }) {
    return this.prisma.topikExamSection.create({
      data: dto,
    });
  }

  async adminCreateQuestion(dto: {
    examSectionId: string;
    questionType: TopikQuestionType;
    orderIndex: number;
    contentHtml: string;
    audioUrl?: string;
    listeningScript?: string;
    correctTextAnswer?: string;
    scoreWeight?: number;
    explanation?: string;
    choices?: { orderIndex: number; content: string; isCorrect: boolean }[];
  }) {
    const question = await this.prisma.topikQuestion.create({
      data: {
        examSectionId: dto.examSectionId,
        questionType: dto.questionType,
        orderIndex: dto.orderIndex,
        contentHtml: dto.contentHtml,
        audioUrl: dto.audioUrl,
        listeningScript: dto.listeningScript,
        correctTextAnswer: dto.correctTextAnswer,
        scoreWeight: dto.scoreWeight ?? 1,
        explanation: dto.explanation,
      } as any,
    });

    if (dto.choices && dto.choices.length) {
      await this.prisma.topikChoice.createMany({
        data: dto.choices.map((c) => ({
          questionId: question.id,
          orderIndex: c.orderIndex,
          content: c.content,
          isCorrect: c.isCorrect,
        })),
      });
    }

    return this.prisma.topikQuestion.findUnique({
      where: { id: question.id },
      include: { choices: { orderBy: { orderIndex: 'asc' } } },
    });
  }

  async adminUpdateSection(id: string, dto: any) {
    return this.prisma.topikExamSection.update({
      where: { id },
      data: dto,
    });
  }

  async adminUpdateQuestion(id: string, dto: any) {
    const { choices, ...questionData } = dto || {};
    if (Array.isArray(choices)) {
      await this.prisma.$transaction(async (tx) => {
        await tx.topikQuestion.update({
          where: { id },
          data: questionData as any,
        });
        await tx.topikChoice.deleteMany({ where: { questionId: id } });
        if (choices.length) {
          await tx.topikChoice.createMany({
            data: choices.map((c: any, idx: number) => ({
              questionId: id,
              orderIndex: Number(c?.orderIndex || idx + 1),
              content: String(c?.content || ''),
              isCorrect: !!c?.isCorrect,
            })),
          });
        }
      });

      return this.prisma.topikQuestion.findUnique({
        where: { id },
        include: { choices: { orderBy: { orderIndex: 'asc' } }, section: true },
      });
    }

    return this.prisma.topikQuestion.update({
      where: { id },
      data: questionData as any,
    });
  }

  async adminPublishExam(id: string, published: boolean) {
    return this.prisma.topikExam.update({
      where: { id },
      data: { status: published ? TopikExamStatus.PUBLISHED : TopikExamStatus.DRAFT },
    });
  }

  async adminImportExam(payload: any, createdBy?: string) {
    // Expected payload:
    // { exam: {...}, sections: [{... , questions: [{... , choices:[...] }]}] }
    if (!payload || typeof payload !== 'object') {
      throw new BadRequestException('Invalid payload');
    }

    const examData = payload.exam;
    const sections = Array.isArray(payload.sections) ? payload.sections : [];
    if (!examData) throw new BadRequestException('Missing exam');

    return this.prisma.$transaction(async (tx) => {
      const exam = await tx.topikExam.create({
        data: {
          title: String(examData.title || ''),
          year: Number(examData.year || new Date().getFullYear()),
          topikLevel: examData.topikLevel,
          level: examData.level ? String(examData.level) : null,
          durationMinutes: Number(examData.durationMinutes || 60),
          totalQuestions: Number(examData.totalQuestions || 0),
          status: examData.status || TopikExamStatus.DRAFT,
          createdBy,
        },
      });

      for (const s of sections) {
        const section = await tx.topikExamSection.create({
          data: {
            examId: exam.id,
            type: s.type,
            orderIndex: Number(s.orderIndex || 1),
            durationMinutes: s.durationMinutes != null ? Number(s.durationMinutes) : null,
            maxScore: s.maxScore != null ? Number(s.maxScore) : undefined,
          },
        });

        const questions = Array.isArray(s.questions) ? s.questions : [];
        for (const q of questions) {
          const question = await tx.topikQuestion.create({
            data: {
              examSectionId: section.id,
              questionType: q.questionType,
              orderIndex: Number(q.orderIndex || 1),
              contentHtml: String(q.contentHtml || ''),
              audioUrl: q.audioUrl ? String(q.audioUrl) : null,
              listeningScript: q.listeningScript ? String(q.listeningScript) : null,
              correctTextAnswer: q.correctTextAnswer ? String(q.correctTextAnswer) : null,
              scoreWeight: q.scoreWeight != null ? Number(q.scoreWeight) : 1,
              explanation: q.explanation ? String(q.explanation) : null,
            } as any,
          });

          const choices = Array.isArray(q.choices) ? q.choices : [];
          if (choices.length) {
            await tx.topikChoice.createMany({
              data: choices.map((c: any) => ({
                questionId: question.id,
                orderIndex: Number(c.orderIndex || 1),
                content: String(c.content || ''),
                isCorrect: !!c.isCorrect,
              })),
            });
          }
        }
      }

      return exam;
    });
  }

  async adminListExams() {
    return this.prisma.topikExam.findMany({
      orderBy: [{ createdAt: 'desc' }],
      include: { sections: true },
    });
  }

  async adminGetExam(id: string) {
    const exam = await this.prisma.topikExam.findUnique({
      where: { id },
      include: {
        sections: {
          orderBy: { orderIndex: 'asc' },
          include: {
            questions: {
              orderBy: { orderIndex: 'asc' },
              include: { choices: { orderBy: { orderIndex: 'asc' } } },
            },
          },
        },
      },
    });
    if (!exam) throw new NotFoundException('Exam not found');
    return exam;
  }

  async adminRemoveExam(id: string) {
    await this.prisma.topikExam.delete({ where: { id } });
    return { message: 'Deleted' };
  }

  async adminRequire(role: UserRole) {
    if (role !== UserRole.ADMIN) throw new ForbiddenException('Admin only');
  }
}

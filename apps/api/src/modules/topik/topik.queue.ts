import { Process, Processor } from '@nestjs/bull';
import { Job } from 'bull';
import { Logger } from '@nestjs/common';
import { PrismaService } from '../../prisma/prisma.service';
import { AiReviewService } from './topik.ai-review.service';
import { TopikQuestionType } from '@prisma/client';

export const TOPIK_QUEUE = 'topik';
export const TOPIK_REVIEW_ESSAY_JOB = 'review_essay';

@Processor(TOPIK_QUEUE)
export class TopikQueueProcessor {
  private readonly logger = new Logger(TopikQueueProcessor.name);

  constructor(
    private readonly prisma: PrismaService,
    private readonly aiReviewService: AiReviewService,
  ) {}

  @Process(TOPIK_REVIEW_ESSAY_JOB)
  async handleReviewEssay(job: Job<{ answerId: string }>) {
    const answerId = job.data?.answerId;
    if (!answerId) return;

    const answer = await this.prisma.topikAnswer.findUnique({
      where: { id: answerId },
      include: {
        question: true,
        session: { include: { exam: true } },
      },
    });

    if (!answer) return;
    if (answer.aiReviewedAt) return;
    if (answer.question.questionType !== TopikQuestionType.ESSAY) return;

    const userAnswer = String(answer.textAnswer || '').trim();
    if (!userAnswer) return;

    const ai = await this.aiReviewService.reviewWriting({
      questionPrompt: answer.question.contentHtml,
      userAnswer,
    });

    const essayScore = Math.round((ai.score / 100) * (answer.question.scoreWeight || 1));

    await this.prisma.$transaction(async (tx) => {
      await tx.topikAnswer.update({
        where: { id: answer.id },
        data: {
          aiScore: ai.score,
          aiFeedback: ai as any,
          aiReviewedAt: new Date(),
          score: essayScore,
        },
      });

      const agg = await tx.topikAnswer.aggregate({
        where: { sessionId: answer.sessionId },
        _sum: { score: true },
      });

      await tx.topikSession.update({
        where: { id: answer.sessionId },
        data: {
          totalScore: agg._sum.score ?? 0,
        },
      });
    });

    this.logger.log({ answerId, essayScore }, 'Essay reviewed');
  }
}

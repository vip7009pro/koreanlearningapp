import { Process, Processor } from '@nestjs/bull';
import { Job } from 'bull';
import { Logger } from '@nestjs/common';
import { PrismaService } from '../../prisma/prisma.service';
import { AiReviewService } from './topik.ai-review.service';
import { TopikService } from './topik.service';
import { TopikQuestionType } from '@prisma/client';
import {
  TOPIK_GENERATE_LISTENING_AUDIO_JOB,
  TOPIK_QUEUE,
  TOPIK_REVIEW_ESSAY_JOB,
} from './topik.queue.constants';

@Processor(TOPIK_QUEUE)
export class TopikQueueProcessor {
  private readonly logger = new Logger(TopikQueueProcessor.name);

  constructor(
    private readonly prisma: PrismaService,
    private readonly aiReviewService: AiReviewService,
    private readonly topikService: TopikService,
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

  @Process(TOPIK_GENERATE_LISTENING_AUDIO_JOB)
  async handleGenerateListeningAudio(job: Job<{ examId: string; batchSize?: number }>) {
    const examId = job.data?.examId;
    if (!examId) return;

    try {
      job.progress(0);
      const exam = await this.topikService.adminGenerateExamListeningAudio(
        examId,
        job.data?.batchSize,
        (progress) => job.progress(progress),
      );
      return { listeningAudioUrl: exam.listeningAudioUrl };
    } catch (err: any) {
      this.logger.error(
        { examId, jobId: job.id, err: err?.message || err },
        'Failed to generate listening audio job',
      );
      throw err;
    }
  }
}

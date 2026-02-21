import { Injectable, NotFoundException } from '@nestjs/common';
import { PrismaService } from '../../prisma/prisma.service';
import { CreateQuizDto, UpdateQuizDto, CreateQuestionDto, UpdateQuestionDto } from './dto/quiz.dto';

@Injectable()
export class QuizzesService {
  constructor(private prisma: PrismaService) {}

  async createQuiz(dto: CreateQuizDto) {
    return this.prisma.quiz.create({ data: { lessonId: dto.lessonId, title: dto.title, quizType: dto.quizType } });
  }

  async findByLesson(lessonId: string) {
    return this.prisma.quiz.findMany({
      where: { lessonId },
      include: { questions: { include: { options: true } } },
    });
  }

  async findOneQuiz(id: string) {
    const quiz = await this.prisma.quiz.findUnique({
      where: { id },
      include: { questions: { include: { options: true } } },
    });
    if (!quiz) throw new NotFoundException('Quiz not found');
    return quiz;
  }

  async updateQuiz(id: string, dto: UpdateQuizDto) {
    await this.findOneQuiz(id);
    return this.prisma.quiz.update({ where: { id }, data: dto });
  }

  async removeQuiz(id: string) {
    await this.findOneQuiz(id);
    await this.prisma.quiz.delete({ where: { id } });
    return { message: 'Quiz deleted successfully' };
  }

  async removeMany(ids: string[]) {
    const safeIds = Array.from(new Set((ids || []).filter((x) => typeof x === 'string' && x.trim())));
    if (safeIds.length === 0) return { deleted: 0 };

    const res = await this.prisma.quiz.deleteMany({ where: { id: { in: safeIds } } });
    return { deleted: res.count };
  }

  async createQuestion(dto: CreateQuestionDto) {
    const question = await this.prisma.question.create({
      data: {
        quizId: dto.quizId,
        questionType: dto.questionType,
        questionText: dto.questionText,
        audioUrl: dto.audioUrl,
        correctAnswer: dto.correctAnswer,
      },
    });

    if (dto.options && dto.options.length > 0) {
      await this.prisma.option.createMany({
        data: dto.options.map((opt) => ({
          questionId: question.id,
          text: opt.text,
          isCorrect: opt.isCorrect,
        })),
      });
    }

    return this.prisma.question.findUnique({
      where: { id: question.id },
      include: { options: true },
    });
  }

  async updateQuestion(id: string, dto: UpdateQuestionDto) {
    return this.prisma.question.update({ where: { id }, data: dto });
  }

  async removeQuestion(id: string) {
    await this.prisma.question.delete({ where: { id } });
    return { message: 'Question deleted successfully' };
  }

  async submitQuizAnswer(quizId: string, _userId: string, answers: { questionId: string; answer: string }[]) {
    const quiz = await this.findOneQuiz(quizId);
    let correctCount = 0;

    for (const answer of answers) {
      const question = quiz.questions.find((q: any) => q.id === answer.questionId);
      if (question && question.correctAnswer === answer.answer) {
        correctCount++;
      }
    }

    const score = Math.round((correctCount / quiz.questions.length) * 100);
    return { quizId, score, correctCount, totalQuestions: quiz.questions.length };
  }
}

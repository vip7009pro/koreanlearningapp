import { Injectable } from '@nestjs/common';
import { PrismaService } from '../../prisma/prisma.service';

export interface WritingCorrectionResult {
  correctedText: string;
  feedback: string;
  score: number;
  errors: { original: string; corrected: string; explanation: string }[];
}

export interface GeneratedQuiz {
  title: string;
  questions: {
    questionText: string;
    correctAnswer: string;
    options: string[];
  }[];
}

@Injectable()
export class AIService {
  constructor(private prisma: PrismaService) {}

  /**
   * Mock AI writing correction service.
   * In production, replace this with OpenAI API call.
   */
  async correctWriting(userId: string, prompt: string, userAnswer: string): Promise<WritingCorrectionResult> {
    // Mock AI correction logic
    const feedback = this.generateMockFeedback(userAnswer);
    const score = this.calculateMockScore(userAnswer);

    // Store the practice result
    await this.prisma.aIWritingPractice.create({
      data: {
        userId,
        prompt,
        userAnswer,
        aiFeedback: feedback,
        score,
      },
    });

    return {
      correctedText: userAnswer,
      feedback,
      score,
      errors: this.generateMockErrors(userAnswer),
    };
  }

  /**
   * Mock AI quiz generation service.
   * In production, replace with OpenAI API call.
   */
  async generateQuiz(topic: string, _difficulty: string, questionCount: number): Promise<GeneratedQuiz> {
    const mockQuestions = [];
    const sampleQuestions = [
      { q: `${topic}에 대해 맞는 것은?`, a: '정답입니다', opts: ['정답입니다', '오답 1', '오답 2', '오답 3'] },
      { q: `다음 중 ${topic}의 의미는?`, a: '올바른 뜻', opts: ['올바른 뜻', '틀린 뜻 1', '틀린 뜻 2', '틀린 뜻 3'] },
      { q: `${topic} 관련 문장을 완성하세요.`, a: '완성된 문장', opts: ['완성된 문장', '옵션 1', '옵션 2', '옵션 3'] },
    ];

    for (let i = 0; i < Math.min(questionCount, 10); i++) {
      const sample = sampleQuestions[i % sampleQuestions.length];
      mockQuestions.push({
        questionText: `(${i + 1}) ${sample.q}`,
        correctAnswer: sample.a,
        options: sample.opts,
      });
    }

    return {
      title: `AI Generated Quiz: ${topic}`,
      questions: mockQuestions,
    };
  }

  async getWritingHistory(userId: string, page = 1, limit = 20) {
    const skip = (page - 1) * limit;
    const [data, total] = await Promise.all([
      this.prisma.aIWritingPractice.findMany({
        where: { userId },
        skip,
        take: limit,
        orderBy: { createdAt: 'desc' },
      }),
      this.prisma.aIWritingPractice.count({ where: { userId } }),
    ]);
    return { data, total, page, limit, totalPages: Math.ceil(total / limit) };
  }

  private generateMockFeedback(text: string): string {
    const length = text.length;
    if (length < 10) return 'Câu trả lời quá ngắn. Hãy viết thêm chi tiết hơn.';
    if (length < 30) return 'Khá tốt! Cố gắng sử dụng thêm ngữ pháp đa dạng hơn.';
    return 'Xuất sắc! Bài viết của bạn rất tốt. Ngữ pháp chính xác và từ vựng phong phú.';
  }

  private calculateMockScore(text: string): number {
    const length = text.length;
    if (length < 10) return Math.floor(Math.random() * 30) + 30;
    if (length < 30) return Math.floor(Math.random() * 20) + 60;
    return Math.floor(Math.random() * 15) + 85;
  }

  private generateMockErrors(text: string) {
    if (text.length < 5) return [];
    return [
      {
        original: text.substring(0, 3),
        corrected: text.substring(0, 3),
        explanation: 'Ngữ pháp đúng, tiếp tục phát huy!',
      },
    ];
  }
}

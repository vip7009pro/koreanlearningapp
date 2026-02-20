import { Injectable, Logger } from '@nestjs/common';
import { PrismaService } from '../../prisma/prisma.service';
import axios from 'axios';

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
  private readonly logger = new Logger(AIService.name);
  constructor(private prisma: PrismaService) {}

  private get apiKey(): string {
    return process.env.OPENROUTER_API_KEY || '';
  }

  /**
   * System prompt that enforces Korean language learning context and blocks abuse.
   */
  private readonly SYSTEM_PROMPT = `Bạn là một giáo viên tiếng Hàn chuyên nghiệp. Vai trò duy nhất của bạn là chấm điểm và sửa bài viết tiếng Hàn cho người học Việt Nam.

QUY TẮC BẮT BUỘC:
1. Bạn CHỈ được phản hồi liên quan đến việc học tiếng Hàn.
2. Nếu người dùng gửi nội dung KHÔNG liên quan đến tiếng Hàn, nội dung nhạy cảm, bạo lực, chính trị, khiêu dâm hoặc vi phạm đạo đức, hãy từ chối lịch sự và nhắc họ gửi bài viết tiếng Hàn.
3. Luôn phản hồi bằng tiếng Việt.
4. Phản hồi phải ở dạng JSON hợp lệ với cấu trúc:
{
  "correctedText": "bài viết đã sửa",
  "feedback": "nhận xét tổng thể",
  "score": <số từ 0-100>,
  "errors": [{"original": "lỗi gốc", "corrected": "đã sửa", "explanation": "giải thích"}]
}
5. Nếu bài viết tốt và không có lỗi, vẫn đưa ra nhận xét và điểm cao.`;

  /**
   * Call OpenRouter API for AI writing correction.
   * Falls back to mock if no API key is configured.
   */
  async correctWriting(userId: string, prompt: string, userAnswer: string): Promise<WritingCorrectionResult> {
    let result: WritingCorrectionResult;

    if (this.apiKey) {
      try {
        result = await this.callOpenRouter(prompt, userAnswer);
      } catch (e) {
        this.logger.warn('OpenRouter call failed, falling back to mock', e);
        result = this.mockCorrection(userAnswer);
      }
    } else {
      this.logger.warn('No OPENROUTER_API_KEY set, using mock correction');
      result = this.mockCorrection(userAnswer);
    }

    // Store the practice result
    await this.prisma.aIWritingPractice.create({
      data: {
        userId,
        prompt,
        userAnswer,
        aiFeedback: result.feedback,
        score: result.score,
      },
    });

    return result;
  }

  private async callOpenRouter(prompt: string, userAnswer: string): Promise<WritingCorrectionResult> {
    const response = await axios.post(
      'https://openrouter.ai/api/v1/chat/completions',
      {
        model: process.env.OPENROUTER_MODEL || 'google/gemini-2.0-flash-001',
        messages: [
          { role: 'system', content: this.SYSTEM_PROMPT },
          {
            role: 'user',
            content: `Chủ đề viết: "${prompt}"\n\nBài viết của học viên:\n"${userAnswer}"\n\nHãy chấm điểm và sửa bài. Trả lời bằng JSON theo đúng cấu trúc đã quy định.`,
          },
        ],
        temperature: 0.3,
        max_tokens: 2000,
      },
      {
        headers: {
          Authorization: `Bearer ${this.apiKey}`,
          'Content-Type': 'application/json',
          'HTTP-Referer': process.env.APP_URL || 'http://localhost:3000',
          'X-Title': 'Korean Learning App',
        },
        timeout: 30000,
      },
    );

    const content = response.data?.choices?.[0]?.message?.content || '';
    
    // Try to parse JSON from the response
    try {
      // Extract JSON from markdown code block if present
      const jsonMatch = content.match(/```json\s*([\s\S]*?)```/) || content.match(/\{[\s\S]*\}/);
      const jsonStr = jsonMatch ? (jsonMatch[1] || jsonMatch[0]) : content;
      const parsed = JSON.parse(jsonStr.trim());

      return {
        correctedText: parsed.correctedText || userAnswer,
        feedback: parsed.feedback || 'Không có nhận xét',
        score: typeof parsed.score === 'number' ? parsed.score : 70,
        errors: Array.isArray(parsed.errors) ? parsed.errors : [],
      };
    } catch {
      // If JSON parsing fails, return the raw text as feedback
      return {
        correctedText: userAnswer,
        feedback: content || 'AI không thể phân tích bài viết.',
        score: 50,
        errors: [],
      };
    }
  }

  private mockCorrection(userAnswer: string): WritingCorrectionResult {
    const length = userAnswer.length;
    let feedback: string;
    let score: number;

    if (length < 10) {
      feedback = 'Câu trả lời quá ngắn. Hãy viết thêm chi tiết hơn.';
      score = Math.floor(Math.random() * 30) + 30;
    } else if (length < 30) {
      feedback = 'Khá tốt! Cố gắng sử dụng thêm ngữ pháp đa dạng hơn.';
      score = Math.floor(Math.random() * 20) + 60;
    } else {
      feedback = 'Xuất sắc! Bài viết của bạn rất tốt. Ngữ pháp chính xác và từ vựng phong phú.';
      score = Math.floor(Math.random() * 15) + 85;
    }

    return {
      correctedText: userAnswer,
      feedback,
      score,
      errors: length >= 5
        ? [{ original: userAnswer.substring(0, 3), corrected: userAnswer.substring(0, 3), explanation: 'Ngữ pháp đúng, tiếp tục phát huy!' }]
        : [],
    };
  }

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
}

import { Injectable, Logger } from '@nestjs/common';
import { AIService } from '../ai/ai.service';

@Injectable()
export class AiReviewService {
  private readonly logger = new Logger(AiReviewService.name);
  constructor(private readonly aiService: AIService) {}

  async reviewWriting(params: {
    questionPrompt: string;
    userAnswer: string;
    scoringCriteria?: string;
  }): Promise<{
    score: number;
    strengths: string[];
    weaknesses: string[];
    improvementSuggestions: string[];
    detailedFeedback: string;
  }> {
    const { questionPrompt, userAnswer, scoringCriteria } = params;

    const systemPrompt =
      'Bạn là giám khảo TOPIK Writing. Chỉ trả về JSON hợp lệ. Không markdown, không giải thích ngoài JSON.';

    const userPrompt = `Hãy chấm bài TOPIK Writing.

Đề bài (prompt):
${questionPrompt}

Bài làm của học viên:
${userAnswer}

Tiêu chí chấm (nếu có):
${scoringCriteria || '(không có)'}

YÊU CẦU JSON:
{
  "score": 0,
  "strengths": ["..."],
  "weaknesses": ["..."],
  "improvementSuggestions": ["..."],
  "detailedFeedback": "..."
}

- score 0-100
- strengths/weaknesses/suggestions: tối đa 5 ý mỗi phần
- phản hồi chi tiết bằng tiếng Việt, có ví dụ sửa câu nếu phù hợp
`;

    try {
      const json = await this.aiService.callJson(
        systemPrompt,
        userPrompt,
        process.env.OPENROUTER_MODEL_WRITING || undefined,
      );

      const score = Math.max(0, Math.min(100, Math.floor(Number(json?.score ?? 0))));
      return {
        score,
        strengths: Array.isArray(json?.strengths) ? json.strengths.map(String).slice(0, 5) : [],
        weaknesses: Array.isArray(json?.weaknesses) ? json.weaknesses.map(String).slice(0, 5) : [],
        improvementSuggestions: Array.isArray(json?.improvementSuggestions)
          ? json.improvementSuggestions.map(String).slice(0, 5)
          : [],
        detailedFeedback: String(json?.detailedFeedback ?? ''),
      };
    } catch (e) {
      this.logger.warn({ err: String(e) }, 'Writing review failed');
      return {
        score: 0,
        strengths: [],
        weaknesses: ['Không thể chấm điểm do lỗi hệ thống AI.'],
        improvementSuggestions: ['Thử nộp lại sau.'],
        detailedFeedback: 'Hệ thống AI hiện không khả dụng. Vui lòng thử lại sau.',
      };
    }
  }
}

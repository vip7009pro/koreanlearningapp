import { Injectable, NotFoundException, ForbiddenException } from '@nestjs/common';
import { PrismaService } from '../../prisma/prisma.service';
import { AIService } from '../ai/ai.service';
import { Difficulty } from '@prisma/client';

@Injectable()
export class AIDialoguesService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly aiService: AIService,
  ) {}

  private readonly DEFAULT_SCENARIOS = [
    {
      title: 'Phỏng vấn xin việc tại công ty Hàn Quốc',
      description: 'Tập luyện trả lời phỏng vấn xin việc với Giám đốc Nhân sự. Trả lời các câu hỏi về bản thân, kinh nghiệm và mong muốn.',
      difficulty: Difficulty.HARD,
      starterMessage: '안녕하세요! 지원자님, 자기소개를 해주시겠어요?',
      initialPrompt: 'Bạn là một Giám đốc Nhân sự người Hàn Quốc đang phỏng vấn xin việc ứng viên. Hãy đóng vai một cách chuyên nghiệp, lịch sự nhưng nghiêm túc. Hỏi các câu hỏi phỏng vấn tiêu chuẩn bằng tiếng Hàn. Mỗi lần trả lời hãy nói ngắn gọn, khoảng 1-2 câu để duy trì hội thoại.',
    },
    {
      title: 'Gọi món tại quán ăn ở Seoul',
      description: 'Luyện tập giao tiếp với nhân viên phục vụ quán ăn. Gọi món, yêu cầu thêm nước panchan và thanh toán.',
      difficulty: Difficulty.EASY,
      starterMessage: '어서 오세요! 몇 분이세요? 주문하시겠어요?',
      initialPrompt: 'Bạn là một nhân viên phục vụ tại một nhà hàng Hàn Quốc thân thiện. Hãy nói chuyện lịch sự, niềm nở. Giúp khách hàng gọi món và trả lời các câu hỏi của khách hàng. Mỗi lượt nói khoảng 1 câu tiếng Hàn ngắn gọn.',
    },
    {
      title: 'Hỏi đường tại ga tàu điện ngầm Myeongdong',
      description: 'Tìm đường đến lối ra số 4 và hỏi cách mua vé tàu điện ngầm.',
      difficulty: Difficulty.MEDIUM,
      starterMessage: '실례합니다, 무엇을 도와드릴까요?',
      initialPrompt: 'Bạn là một nhân viên hỗ trợ tại ga tàu điện ngầm Seoul hoặc một người qua đường tốt bụng. Chỉ đường cho người nước ngoài bằng tiếng Hàn rõ ràng, dễ hiểu. Mỗi lượt nói khoảng 1-2 câu.',
    },
  ];

  async getScenarios() {
    let scenarios = await this.prisma.dialogueScenario.findMany({
      orderBy: { createdAt: 'asc' },
    });

    if (scenarios.length === 0) {
      await this.prisma.dialogueScenario.createMany({
        data: this.DEFAULT_SCENARIOS,
      });
      scenarios = await this.prisma.dialogueScenario.findMany({
        orderBy: { createdAt: 'asc' },
      });
    }

    return scenarios;
  }

  async createSession(userId: string, scenarioId: string) {
    const scenario = await this.prisma.dialogueScenario.findUnique({
      where: { id: scenarioId },
    });

    if (!scenario) {
      throw new NotFoundException('Không tìm thấy kịch bản hội thoại này');
    }

    const session = await this.prisma.dialogueSession.create({
      data: {
        userId,
        scenarioId,
      },
    });

    // Create starter message turn
    await this.prisma.dialogueTurn.create({
      data: {
        sessionId: session.id,
        role: 'AI',
        content: scenario.starterMessage,
      },
    });

    return this.prisma.dialogueSession.findUnique({
      where: { id: session.id },
      include: {
        turns: {
          orderBy: { createdAt: 'asc' },
        },
        scenario: true,
      },
    });
  }

  async getSessionHistory(userId: string, sessionId: string) {
    const session = await this.prisma.dialogueSession.findUnique({
      where: { id: sessionId },
      include: {
        turns: {
          orderBy: { createdAt: 'asc' },
        },
        scenario: true,
      },
    });

    if (!session) {
      throw new NotFoundException('Không tìm thấy phiên hội thoại');
    }

    if (session.userId !== userId) {
      throw new ForbiddenException('Bạn không có quyền truy cập phiên này');
    }

    return session;
  }

  async submitTurn(userId: string, sessionId: string, userAnswer: string) {
    const session = await this.prisma.dialogueSession.findUnique({
      where: { id: sessionId },
      include: {
        scenario: true,
        turns: {
          orderBy: { createdAt: 'asc' },
        },
      },
    });

    if (!session) {
      throw new NotFoundException('Không tìm thấy phiên hội thoại');
    }

    if (session.userId !== userId) {
      throw new ForbiddenException('Bạn không có quyền truy cập phiên này');
    }

    // Save user's turn
    const userTurn = await this.prisma.dialogueTurn.create({
      data: {
        sessionId: session.id,
        role: 'USER',
        content: userAnswer,
      },
    });

    // Build dialogue context for AI prompt
    const contextLines = session.turns.map((t) => {
      const speaker = t.role === 'AI' ? 'Character' : 'User';
      return `${speaker}: "${t.content}"`;
    });
    contextLines.push(`User: "${userAnswer}"`);

    const contextStr = contextLines.join('\n');

    const systemPrompt = `
Bạn đóng vai nhân vật trong kịch bản: "${session.scenario.title}".
Mô tả nhân vật: "${session.scenario.initialPrompt}".

Nhiệm vụ của bạn:
1. Đánh giá câu nói tiếng Hàn mới nhất của người dùng ("User"). Chấm điểm từ 0 đến 100 dựa trên ngữ pháp, sự phù hợp ngữ cảnh và tính tự nhiên.
2. Cung cấp lời giải thích ngắn gọn bằng tiếng Việt về ngữ pháp/từ vựng (nếu có lỗi sai hoặc điểm cần lưu ý).
3. Đưa ra 2 đến 3 cách diễn đạt tự nhiên hơn hoặc nâng cấp hơn bằng tiếng Hàn cho câu nói của người dùng kèm nghĩa tiếng Việt.
4. Viết câu trả lời tiếp theo của nhân vật bằng tiếng Hàn (ngắn gọn, khoảng 1-2 câu, phù hợp với ngữ cảnh hội thoại hiện tại).

BẮT BUỘC TRẢ VỀ định dạng JSON thuần túy theo cấu trúc sau (không có bất kỳ text giải thích nào ngoài JSON):
{
  "score": 85,
  "explanation": "Giải thích ngắn gọn lỗi ngữ pháp hoặc gợi ý từ vựng bằng tiếng Việt...",
  "suggestions": [
    "Câu gợi ý tiếng Hàn 1 (Nghĩa tiếng Việt)",
    "Câu gợi ý tiếng Hàn 2 (Nghĩa tiếng Việt)"
  ],
  "aiResponse": "Câu trả lời tiếp theo bằng tiếng Hàn của nhân vật..."
}
`;

    const userPrompt = `
Lịch sử cuộc hội thoại:
${contextStr}

Hãy đánh giá câu nói cuối cùng của User và đưa ra phản hồi tiếp theo. Trả về đúng JSON.
`;

    let evaluation: {
      score: number;
      explanation: string;
      suggestions: string[];
      aiResponse: string;
    };

    try {
      evaluation = await this.aiService['callAiJson']('google', systemPrompt, userPrompt);
    } catch (e) {
      // Mock/Fallback evaluation on failure
      evaluation = {
        score: 80,
        explanation: 'AI đang bận, đã lưu câu trả lời của bạn.',
        suggestions: [userAnswer],
        aiResponse: '네, 그렇군요. 계속 말씀해 주세요.',
      };
    }

    // Save AI's response turn
    const aiTurn = await this.prisma.dialogueTurn.create({
      data: {
        sessionId: session.id,
        role: 'AI',
        content: evaluation.aiResponse,
        pronunciationScore: evaluation.score,
        grammarFeedback: {
          explanation: evaluation.explanation,
          suggestions: evaluation.suggestions,
        } as any,
      },
    });

    // Update user turn with evaluation feedback
    const updatedUserTurn = await this.prisma.dialogueTurn.update({
      where: { id: userTurn.id },
      data: {
        pronunciationScore: evaluation.score,
        grammarFeedback: {
          explanation: evaluation.explanation,
          suggestions: evaluation.suggestions,
        } as any,
      },
    });

    return {
      userTurn: updatedUserTurn,
      aiTurn,
    };
  }
}

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

type GeneratedVocabularyItem = {
  korean: string;
  vietnamese: string;
  pronunciation?: string;
  exampleSentence?: string;
  exampleMeaning?: string;
  difficulty?: 'EASY' | 'MEDIUM' | 'HARD';
};

type GeneratedGrammarItem = {
  pattern: string;
  explanationVN: string;
  example: string;
};

type GeneratedDialogueItem = {
  speaker: string;
  koreanText: string;
  vietnameseText: string;
  orderIndex?: number;
};

type GeneratedQuizItem = {
  title: string;
  quizType?: 'MULTIPLE_CHOICE' | 'FILL_IN_BLANK' | 'LISTENING' | 'MATCHING';
  questions: {
    questionType?: 'MULTIPLE_CHOICE' | 'TRUE_FALSE' | 'FILL_IN_BLANK' | 'AUDIO';
    questionText: string;
    correctAnswer: string;
    options?: { text: string; isCorrect?: boolean }[];
  }[];
};

@Injectable()
export class AIService {
  private readonly logger = new Logger(AIService.name);
  constructor(private prisma: PrismaService) {}

  private get apiKey(): string {
    return process.env.OPENROUTER_API_KEY || '';
  }

  private async getLessonContext(lessonId: string) {
    return this.prisma.lesson.findUnique({
      where: { id: lessonId },
      include: {
        section: {
          include: {
            course: true,
          },
        },
      },
    });
  }

  private async callOpenRouterJson(
    systemPrompt: string,
    userPrompt: string,
    modelOverride?: string,
  ): Promise<any> {
    if (!this.apiKey) {
      throw new Error('OPENROUTER_API_KEY is not configured');
    }

    const response = await axios.post(
      'https://openrouter.ai/api/v1/chat/completions',
      {
        model:
          (modelOverride && String(modelOverride).trim()) ||
          process.env.OPENROUTER_MODEL ||
          'google/gemini-2.0-flash-001',
        messages: [
          { role: 'system', content: systemPrompt },
          { role: 'user', content: userPrompt },
        ],
        temperature: 0.2,
        max_tokens: 18000,
      },
      {
        headers: {
          Authorization: `Bearer ${this.apiKey}`,
          'Content-Type': 'application/json',
          'HTTP-Referer': process.env.APP_URL || 'http://localhost:3000',
          'X-Title': 'Korean Learning App',
        },
        timeout: 45000,
      },
    );

    const content = response.data?.choices?.[0]?.message?.content || '';

    const jsonMatch =
      content.match(/```json\s*([\s\S]*?)```/) || content.match(/\{[\s\S]*\}/);
    const jsonStr = jsonMatch ? jsonMatch[1] || jsonMatch[0] : content;

    const trimmed = String(jsonStr).trim();
    try {
      return JSON.parse(trimmed);
    } catch (e) {
      const msg = (e as any)?.message ? String((e as any).message) : String(e);
      const posMatch = msg.match(/position\s+(\d+)/i);
      const pos = posMatch ? Number(posMatch[1]) : null;

      // Common failure mode: model output gets truncated and misses closing brackets.
      // If the error position is at end-of-string, try a minimal repair by appending closing tokens.
      if (typeof pos === 'number' && !Number.isNaN(pos) && pos >= trimmed.length - 1) {
        const repairedCandidates = [
          `${trimmed}\n]}`,
          `${trimmed}\n]}}`,
        ];
        for (const candidate of repairedCandidates) {
          try {
            const repaired = JSON.parse(candidate);
            this.logger.warn(
              {
                model: modelOverride || 'default',
                jsonLength: trimmed.length,
                repairedJsonLength: candidate.length,
                parseError: msg,
              },
              'OpenRouter JSON.parse failed but was auto-repaired',
            );
            return repaired;
          } catch (_) {
            // ignore and try next candidate
          }
        }
      }

      const clamp = (n: number, min: number, max: number) =>
        Math.max(min, Math.min(max, n));
      const excerptAround = (s: string, center: number, radius: number) => {
        const start = clamp(center - radius, 0, s.length);
        const end = clamp(center + radius, 0, s.length);
        return s.slice(start, end);
      };

      const head = trimmed.slice(0, 500);
      const tail = trimmed.length > 500 ? trimmed.slice(-500) : '';
      const around =
        typeof pos === 'number' && !Number.isNaN(pos)
          ? excerptAround(trimmed, pos, 250)
          : '';

      this.logger.warn(
        {
          model: modelOverride || 'default',
          contentLength: String(content).length,
          jsonLength: trimmed.length,
          parseError: msg,
          errorPosition: pos,
          jsonHead: head,
          jsonTail: tail,
          jsonAroundError: around,
        },
        'OpenRouter JSON.parse failed',
      );
      throw e;
    }
  }

  async generateAndInsertVocabulary(lessonId: string, count: number, model?: string) {
    const ctx = await this.getLessonContext(lessonId);
    if (!ctx) throw new Error('Lesson not found');

    const safeCount = Math.max(1, Math.min(200, Math.floor(count || 10)));
    const courseTitle = ctx.section?.course?.title || '';
    const sectionTitle = ctx.section?.title || '';
    const lessonTitle = ctx.title || '';

    const existingKorean = await this.prisma.vocabulary.findMany({
      where: { lessonId },
      select: { korean: true },
      orderBy: { createdAt: 'asc' },
      take: 500,
    });
    const existingList = existingKorean
      .map((x) => String(x.korean || '').trim())
      .filter((x) => x.length)
      .slice(0, 500);

    const systemPrompt = `Bạn là trợ lý tạo nội dung học tiếng Hàn cho người Việt. Chỉ trả về JSON hợp lệ, không giải thích, không markdown.`;
    const userPrompt = `Hãy tạo danh sách ${safeCount} từ vựng MỚI cho bài học tiếng Hàn.

Ngữ cảnh:
- Course: "${courseTitle}"
- Section: "${sectionTitle}"
- Lesson: "${lessonTitle}"

KHÔNG ĐƯỢC tạo trùng (korean) với các từ đã tồn tại sau:
${existingList.length ? existingList.map((x) => `- ${x}`).join('\n') : '- (trống)'}

YÊU CẦU JSON:
{
  "items": [
    {
      "korean": "...",
      "vietnamese": "...",
      "pronunciation": "...",
      "exampleSentence": "...",
      "exampleMeaning": "...",
      "difficulty": "EASY"|"MEDIUM"|"HARD"
    }
  ]
}

Lưu ý: ví dụ câu nên ngắn, tự nhiên, liên quan chủ đề.`;

    let items: GeneratedVocabularyItem[] = [];
    if (this.apiKey) {
      try {
        const parsed = await this.callOpenRouterJson(systemPrompt, userPrompt, model);
        items = Array.isArray(parsed?.items) ? parsed.items : [];
      } catch (e) {
        this.logger.warn('AI vocab generation failed, falling back to mock', e as any);
      }
    }

    if (!items.length) {
      items = Array.from({ length: safeCount }).map((_, i) => ({
        korean: `단어 ${i + 1}`,
        vietnamese: `Từ ${i + 1}`,
        pronunciation: '',
        exampleSentence: '',
        exampleMeaning: '',
        difficulty: 'EASY',
      }));
    }

    const rawItems = items.slice(0, safeCount).map((it) => ({
      lessonId,
      korean: String(it.korean || '').trim(),
      vietnamese: String(it.vietnamese || '').trim(),
      pronunciation: String(it.pronunciation || ''),
      exampleSentence: String(it.exampleSentence || ''),
      exampleMeaning: String(it.exampleMeaning || ''),
      difficulty: (it.difficulty as any) || 'EASY',
    }));

    const uniqueByKorean = new Map<string, (typeof rawItems)[number]>();
    for (const it of rawItems) {
      if (!it.korean) continue;
      const key = it.korean.toLowerCase();
      if (!uniqueByKorean.has(key)) uniqueByKorean.set(key, it);
    }

    const uniqueItems = Array.from(uniqueByKorean.values());
    const existing = await this.prisma.vocabulary.findMany({
      where: {
        lessonId,
        korean: { in: uniqueItems.map((x) => x.korean) },
      },
      select: { korean: true },
    });

    const existingSet = new Set(existing.map((x) => String(x.korean).toLowerCase()));
    const createItems = uniqueItems.filter((x) => !existingSet.has(x.korean.toLowerCase()));

    const created = createItems.length
      ? await this.prisma.vocabulary.createMany({
          data: createItems,
          skipDuplicates: false,
        })
      : { count: 0 };

    return {
      inserted: created.count,
      requested: safeCount,
      generatedUnique: uniqueItems.length,
      skippedExisting: uniqueItems.length - createItems.length,
      lessonId,
    };
  }

  async generateAndInsertGrammar(lessonId: string, count: number, model?: string) {
    const ctx = await this.getLessonContext(lessonId);
    if (!ctx) throw new Error('Lesson not found');

    const safeCount = Math.max(1, Math.min(30, Math.floor(count || 5)));
    const courseTitle = ctx.section?.course?.title || '';
    const sectionTitle = ctx.section?.title || '';
    const lessonTitle = ctx.title || '';

    const systemPrompt = `Bạn là trợ lý tạo ngữ pháp tiếng Hàn cho người Việt. Chỉ trả về JSON hợp lệ, không giải thích, không markdown.`;
    const userPrompt = `Hãy tạo ${safeCount} mục ngữ pháp cho bài học.

Ngữ cảnh:
- Course: "${courseTitle}"
- Section: "${sectionTitle}"
- Lesson: "${lessonTitle}"

YÊU CẦU JSON:
{
  "items": [
    {
      "pattern": "...",
      "explanationVN": "...",
      "example": "..."
    }
  ]
}`;

    let items: GeneratedGrammarItem[] = [];
    if (this.apiKey) {
      try {
        const parsed = await this.callOpenRouterJson(systemPrompt, userPrompt, model);
        items = Array.isArray(parsed?.items) ? parsed.items : [];
      } catch (e) {
        this.logger.warn('AI grammar generation failed, falling back to mock', e as any);
      }
    }

    if (!items.length) {
      items = Array.from({ length: safeCount }).map((_, i) => ({
        pattern: `패턴 ${i + 1}`,
        explanationVN: `Giải thích ${i + 1}`,
        example: `예문 ${i + 1}`,
      }));
    }

    const data = items.slice(0, safeCount).map((it) => ({
      lessonId,
      pattern: String(it.pattern || '').trim(),
      explanationVN: String(it.explanationVN || '').trim(),
      example: String(it.example || '').trim(),
    }));

    const created = await this.prisma.grammar.createMany({ data });
    return { inserted: created.count, requested: safeCount, lessonId };
  }

  async generateAndInsertDialogues(lessonId: string, count: number, model?: string) {
    const ctx = await this.getLessonContext(lessonId);
    if (!ctx) throw new Error('Lesson not found');

    const safeCount = Math.max(1, Math.min(50, Math.floor(count || 10)));
    const courseTitle = ctx.section?.course?.title || '';
    const sectionTitle = ctx.section?.title || '';
    const lessonTitle = ctx.title || '';

    const systemPrompt = `Bạn là trợ lý tạo hội thoại tiếng Hàn cho người Việt. Chỉ trả về JSON hợp lệ, không giải thích, không markdown.`;
    const userPrompt = `Hãy tạo hội thoại gồm ${safeCount} câu (lines) cho bài học.

Ngữ cảnh:
- Course: "${courseTitle}"
- Section: "${sectionTitle}"
- Lesson: "${lessonTitle}"

YÊU CẦU JSON:
{
  "items": [
    {
      "speaker": "A|B|...",
      "koreanText": "...",
      "vietnameseText": "...",
      "orderIndex": 0
    }
  ]
}

Lưu ý: orderIndex tăng dần từ 0.`;

    let items: GeneratedDialogueItem[] = [];
    if (this.apiKey) {
      try {
        const parsed = await this.callOpenRouterJson(systemPrompt, userPrompt, model);
        items = Array.isArray(parsed?.items) ? parsed.items : [];
      } catch (e) {
        this.logger.warn('AI dialogues generation failed, falling back to mock', e as any);
      }
    }

    if (!items.length) {
      items = Array.from({ length: safeCount }).map((_, i) => ({
        speaker: i % 2 == 0 ? 'A' : 'B',
        koreanText: `대화 ${i + 1}`,
        vietnameseText: `Hội thoại ${i + 1}`,
        orderIndex: i,
      }));
    }

    const data = items.slice(0, safeCount).map((it, i) => ({
      lessonId,
      speaker: String(it.speaker || (i % 2 === 0 ? 'A' : 'B')).trim(),
      koreanText: String(it.koreanText || '').trim(),
      vietnameseText: String(it.vietnameseText || '').trim(),
      orderIndex: Number.isFinite(Number(it.orderIndex)) ? Number(it.orderIndex) : i,
    }));

    const created = await this.prisma.dialogue.createMany({ data });
    return { inserted: created.count, requested: safeCount, lessonId };
  }

  async generateAndInsertQuizzes(lessonId: string, count: number, model?: string) {
    const ctx = await this.getLessonContext(lessonId);
    if (!ctx) throw new Error('Lesson not found');

    const safeCount = Math.max(1, Math.min(10, Math.floor(count || 1)));
    const courseTitle = ctx.section?.course?.title || '';
    const sectionTitle = ctx.section?.title || '';
    const lessonTitle = ctx.title || '';

    const systemPrompt = `Bạn là trợ lý tạo quiz tiếng Hàn cho người Việt. Chỉ trả về JSON hợp lệ, không giải thích, không markdown.`;
    const userPrompt = `Hãy tạo ${safeCount} quiz cho bài học.

Ngữ cảnh:
- Course: "${courseTitle}"
- Section: "${sectionTitle}"
- Lesson: "${lessonTitle}"

YÊU CẦU JSON:
{
  "items": [
    {
      "title": "...",
      "quizType": "MULTIPLE_CHOICE",
      "questions": [
        {
          "questionType": "MULTIPLE_CHOICE",
          "questionText": "...",
          "correctAnswer": "...",
          "options": [
            {"text": "...", "isCorrect": true},
            {"text": "...", "isCorrect": false}
          ]
        }
      ]
    }
  ]
}

Lưu ý: mỗi quiz nên có 3-10 câu hỏi, options tối thiểu 4 lựa chọn.`;

    let items: GeneratedQuizItem[] = [];
    if (this.apiKey) {
      try {
        const parsed = await this.callOpenRouterJson(systemPrompt, userPrompt, model);
        items = Array.isArray(parsed?.items) ? parsed.items : [];
      } catch (e) {
        this.logger.warn('AI quiz generation failed, falling back to mock', e as any);
      }
    }

    if (!items.length) {
      items = Array.from({ length: safeCount }).map((_, i) => ({
        title: `Quiz ${i + 1}: ${lessonTitle}`,
        quizType: 'MULTIPLE_CHOICE',
        questions: [
          {
            questionType: 'MULTIPLE_CHOICE',
            questionText: `Câu hỏi ${i + 1}?`,
            correctAnswer: 'Đáp án đúng',
            options: [
              { text: 'Đáp án đúng', isCorrect: true },
              { text: 'Đáp án sai 1', isCorrect: false },
              { text: 'Đáp án sai 2', isCorrect: false },
              { text: 'Đáp án sai 3', isCorrect: false },
            ],
          },
        ],
      }));
    }

    const createdIds: string[] = [];

    for (const quiz of items.slice(0, safeCount)) {
      const quizTitle = String(quiz.title || '').trim() || `Quiz: ${lessonTitle}`;
      const quizType = (quiz.quizType as any) || 'MULTIPLE_CHOICE';

      const createdQuiz = await this.prisma.quiz.create({
        data: {
          lessonId,
          title: quizTitle,
          quizType,
        },
      });

      createdIds.push(createdQuiz.id);

      const questions = Array.isArray(quiz.questions) ? quiz.questions : [];
      for (const q of questions) {
        const questionText = String(q.questionText || '').trim();
        if (!questionText) continue;

        const correctAnswer = String(q.correctAnswer || '').trim();
        const questionType = (q.questionType as any) || 'MULTIPLE_CHOICE';
        const createdQ = await this.prisma.question.create({
          data: {
            quizId: createdQuiz.id,
            questionType,
            questionText,
            correctAnswer,
          },
        });

        const options = Array.isArray(q.options) ? q.options : [];
        if (options.length) {
          await this.prisma.option.createMany({
            data: options
              .filter((o) => String(o?.text || '').trim().length)
              .map((o) => ({
                questionId: createdQ.id,
                text: String(o.text).trim(),
                isCorrect: o.isCorrect === true || String(o.text).trim() === correctAnswer,
              })),
          });
        }
      }
    }

    return {
      inserted: createdIds.length,
      requested: safeCount,
      lessonId,
      quizIds: createdIds,
    };
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
    const pageNum = typeof page === 'string' ? Number(page) : page;
    const limitNum = typeof limit === 'string' ? Number(limit) : limit;
    const safePage = Number.isFinite(pageNum) && pageNum > 0 ? Math.floor(pageNum) : 1;
    const safeLimit = Number.isFinite(limitNum) && limitNum > 0 ? Math.floor(limitNum) : 20;
    const skip = (safePage - 1) * safeLimit;
    const [data, total] = await Promise.all([
      this.prisma.aIWritingPractice.findMany({
        where: { userId },
        skip,
        take: safeLimit,
        orderBy: { createdAt: 'desc' },
      }),
      this.prisma.aIWritingPractice.count({ where: { userId } }),
    ]);
    return {
      data,
      total,
      page: safePage,
      limit: safeLimit,
      totalPages: Math.ceil(total / safeLimit),
    };
  }
}

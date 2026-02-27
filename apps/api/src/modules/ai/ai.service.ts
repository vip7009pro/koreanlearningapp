import {
  Injectable,
  Logger,
  HttpException,
  HttpStatus,
  ServiceUnavailableException,
} from '@nestjs/common';
import { PrismaService } from '../../prisma/prisma.service';
import axios from 'axios';
import { GoogleGenAI } from '@google/genai';

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

type TopikGeneratedChoice = {
  orderIndex: number;
  content: string;
  isCorrect: boolean;
};

type TopikGeneratedQuestion = {
  questionType: 'MCQ' | 'SHORT_TEXT' | 'ESSAY';
  orderIndex: number;
  contentHtml: string;
  audioUrl?: string | null;
  listeningScript?: string | null;
  correctTextAnswer?: string | null;
  scoreWeight?: number;
  explanation?: string | null;
  choices?: TopikGeneratedChoice[];
};

type TopikGeneratedSection = {
  type: 'LISTENING' | 'READING' | 'WRITING';
  orderIndex: number;
  durationMinutes?: number;
  maxScore?: number;
  questions: TopikGeneratedQuestion[];
};

export type TopikExamImportPayload = {
  exam: {
    title: string;
    year: number;
    topikLevel: 'TOPIK_I' | 'TOPIK_II';
    level?: string | null;
    durationMinutes: number;
    totalQuestions: number;
    status?: 'DRAFT' | 'PUBLISHED';
  };
  sections: TopikGeneratedSection[];
};

type GenerateTopikExamInput = {
  topikLevel: 'TOPIK_I' | 'TOPIK_II';
  year?: number;
  title?: string;
  status?: 'DRAFT' | 'PUBLISHED';
  batchSize?: number;
};

type AiProvider = 'openrouter' | 'google';

type QuotaInfo = {
  perMinuteLimit: number;
  perMinuteRemaining: number;
  minuteResetAt: string;
  dailyLimit: number;
  dailyRemaining: number;
  dayResetAt: string;
};

@Injectable()
export class AIService {
  private readonly logger = new Logger(AIService.name);
  constructor(private prisma: PrismaService) {}

  private _googleClient: GoogleGenAI | null = null;

  private get googleApiKey(): string {
    // Support both common env var names.
    return process.env.GEMINI_API_KEY || process.env.GOOGLE_API_KEY || '';
  }

  private async callAiJson(
    provider: 'openrouter' | 'google',
    systemPrompt: string,
    userPrompt: string,
    modelOverride?: string,
    maxTokens?: number,
  ): Promise<any> {
    if (provider === 'google') {
      return this.callGoogleGenAiJson(systemPrompt, userPrompt, modelOverride);
    }
    return this.callOpenRouterJson(systemPrompt, userPrompt, modelOverride, maxTokens);
  }

  private async callGoogleGenAiJson(
    systemPrompt: string,
    userPrompt: string,
    modelOverride?: string,
  ): Promise<any> {
    this.enforceGoogleQuota();
    const ai = this.getGoogleClient();
    const model = (modelOverride && String(modelOverride).trim()) || 'gemini-2.0-flash';

    // Keep it simple: send combined prompt as text. We still enforce JSON-only in the system prompt.
    const response = await ai.models.generateContent({
      model,
      contents: `${systemPrompt}\n\n${userPrompt}`,
    } as any);

    const content = String((response as any)?.text || (response as any)?.response?.text || '').trim();
    const raw = String(content);
    const fenced = raw.match(/```json\s*([\s\S]*?)```/i) || raw.match(/```\s*([\s\S]*?)```/i);
    let jsonStr = fenced ? String(fenced[1] || '').trim() : raw.trim();

    if (!jsonStr.startsWith('{')) {
      const first = jsonStr.indexOf('{');
      const last = jsonStr.lastIndexOf('}');
      if (first >= 0 && last > first) {
        jsonStr = jsonStr.slice(first, last + 1);
      }
    }

    const trimmed = String(jsonStr).trim();
    try {
      return JSON.parse(trimmed);
    } catch (e) {
      try {
        const sanitized = this.sanitizeJsonControlChars(trimmed);
        return JSON.parse(sanitized);
      } catch (_) {
        // ignore and rethrow original error
      }

      const msg = (e as any)?.message ? String((e as any).message) : String(e);
      this.logger.warn(
        {
          provider: 'google',
          model: modelOverride || 'default',
          contentLength: raw.length,
          jsonLength: trimmed.length,
          parseError: msg,
        },
        'Google GenAI JSON.parse failed',
      );
      throw e;
    }
  }

  private getGoogleClient() {
    if (!this._googleClient) {
      if (!this.googleApiKey) {
        throw new Error('GEMINI_API_KEY/GOOGLE_API_KEY is not configured');
      }
      this._googleClient = new GoogleGenAI({ apiKey: this.googleApiKey });
    }
    return this._googleClient;
  }

  private normalizeProvider(input?: string): AiProvider {
    const v = String(input || '').trim().toLowerCase();
    if (v === 'google' || v === 'gemini') return 'google';
    return 'openrouter';
  }

  adminListModels(provider?: string) {
    const p = this.normalizeProvider(provider);
    if (p === 'google') return this.listGoogleModels();
    return this.listOpenRouterModels();
  }

  private listOpenRouterModels() {
    return {
      provider: 'openrouter',
      models: [
        { id: 'google/gemini-2.0-flash-001', label: 'gemini-2.0-flash-001' },
        { id: 'openai/gpt-4o-mini', label: 'gpt-4o-mini' },
        { id: 'anthropic/claude-3.5-haiku', label: 'claude-3.5-haiku' },
        { id: 'meta-llama/llama-3.1-70b-instruct', label: 'llama-3.1-70b' },
        { id: 'meta-llama/llama-3.3-70b-instruct:free', label: 'llama-3.3-70b:free' },
      ],
    };
  }

  private async listGoogleModels() {
    const ai = this.getGoogleClient();
    const pager = await ai.models.list();
    const out: Array<{ id: string; label: string }> = [];

    for await (const m of pager as any) {
      const name = String((m as any)?.name || '').trim();
      if (!name) continue;
      // Filter to Gemini text models to keep the list relevant.
      if (!name.toLowerCase().includes('gemini')) continue;
      out.push({ id: name, label: name });
      if (out.length >= 200) break;
    }

    out.sort((a, b) => a.id.localeCompare(b.id));
    return { provider: 'google', models: out, quota: this.getGoogleQuotaInfo() };
  }

  // NOTE: In-memory quotas are best-effort (per process). If you run multiple API instances,
  // you should move this to Redis for a shared limiter.
  private static freeMinuteBucket = new Map<string, { windowKey: string; count: number }>();
  private static freeDailyBucket = new Map<string, { dayKey: string; count: number }>();

  private static googleMinuteBucket = new Map<string, { windowKey: string; count: number }>();
  private static googleDailyBucket = new Map<string, { dayKey: string; count: number }>();

  private isFreeModel(modelId: string) {
    // OpenRouter free variants commonly end with ':free'
    return String(modelId || '').toLowerCase().includes(':free');
  }

  private enforceFreeModelQuota(modelId: string) {
    const perMinuteLimit = Math.max(
      1,
      Number.parseInt(process.env.OPENROUTER_FREE_PER_MINUTE_LIMIT || '20', 10) || 20,
    );
    const dailyLimit = Math.max(
      1,
      Number.parseInt(process.env.OPENROUTER_FREE_DAILY_LIMIT || '50', 10) || 50,
    );

    const now = new Date();
    const windowKey = `${now.getUTCFullYear()}-${String(now.getUTCMonth() + 1).padStart(2, '0')}-${String(now.getUTCDate()).padStart(2, '0')}T${String(now.getUTCHours()).padStart(2, '0')}:${String(now.getUTCMinutes()).padStart(2, '0')}`;
    const dayKey = `${now.getUTCFullYear()}-${String(now.getUTCMonth() + 1).padStart(2, '0')}-${String(now.getUTCDate()).padStart(2, '0')}`;

    const minute = AIService.freeMinuteBucket.get(modelId);
    if (!minute || minute.windowKey !== windowKey) {
      AIService.freeMinuteBucket.set(modelId, { windowKey, count: 0 });
    }
    const day = AIService.freeDailyBucket.get(modelId);
    if (!day || day.dayKey !== dayKey) {
      AIService.freeDailyBucket.set(modelId, { dayKey, count: 0 });
    }

    const m = AIService.freeMinuteBucket.get(modelId)!;
    const d = AIService.freeDailyBucket.get(modelId)!;

    if (m.count >= perMinuteLimit) {
      throw new HttpException(
        `Đã đạt rate limit của OpenRouter free model: ${perMinuteLimit} requests/phút. Vui lòng chờ sang phút tiếp theo hoặc giảm số lần generate đồng thời.`,
        HttpStatus.TOO_MANY_REQUESTS,
      );
    }
    if (d.count >= dailyLimit) {
      throw new HttpException(
        `Đã đạt daily limit của OpenRouter free model: ${dailyLimit} requests/ngày. Vui lòng chờ sang ngày mới hoặc nạp credits để tăng hạn mức.`,
        HttpStatus.TOO_MANY_REQUESTS,
      );
    }

    m.count += 1;
    d.count += 1;
  }

  private getGoogleQuotaInfo(): QuotaInfo {
    const perMinuteLimit = Math.max(
      1,
      Number.parseInt(process.env.GOOGLE_PER_MINUTE_LIMIT || '60', 10) || 60,
    );
    const dailyLimit = Math.max(
      1,
      Number.parseInt(process.env.GOOGLE_DAILY_LIMIT || '1000', 10) || 1000,
    );

    const now = new Date();
    const windowKey = `${now.getUTCFullYear()}-${String(now.getUTCMonth() + 1).padStart(2, '0')}-${String(now.getUTCDate()).padStart(2, '0')}T${String(now.getUTCHours()).padStart(2, '0')}:${String(now.getUTCMinutes()).padStart(2, '0')}`;
    const dayKey = `${now.getUTCFullYear()}-${String(now.getUTCMonth() + 1).padStart(2, '0')}-${String(now.getUTCDate()).padStart(2, '0')}`;

    const minute = AIService.googleMinuteBucket.get('google');
    const day = AIService.googleDailyBucket.get('google');
    const minuteCount = minute && minute.windowKey === windowKey ? minute.count : 0;
    const dayCount = day && day.dayKey === dayKey ? day.count : 0;

    const minuteResetAt = new Date(Date.UTC(
      now.getUTCFullYear(),
      now.getUTCMonth(),
      now.getUTCDate(),
      now.getUTCHours(),
      now.getUTCMinutes() + 1,
      0,
      0,
    )).toISOString();
    const dayResetAt = new Date(Date.UTC(
      now.getUTCFullYear(),
      now.getUTCMonth(),
      now.getUTCDate() + 1,
      0,
      0,
      0,
      0,
    )).toISOString();

    return {
      perMinuteLimit,
      perMinuteRemaining: Math.max(0, perMinuteLimit - minuteCount),
      minuteResetAt,
      dailyLimit,
      dailyRemaining: Math.max(0, dailyLimit - dayCount),
      dayResetAt,
    };
  }

  private enforceGoogleQuota() {
    const perMinuteLimit = Math.max(
      1,
      Number.parseInt(process.env.GOOGLE_PER_MINUTE_LIMIT || '60', 10) || 60,
    );
    const dailyLimit = Math.max(
      1,
      Number.parseInt(process.env.GOOGLE_DAILY_LIMIT || '1000', 10) || 1000,
    );

    const now = new Date();
    const windowKey = `${now.getUTCFullYear()}-${String(now.getUTCMonth() + 1).padStart(2, '0')}-${String(now.getUTCDate()).padStart(2, '0')}T${String(now.getUTCHours()).padStart(2, '0')}:${String(now.getUTCMinutes()).padStart(2, '0')}`;
    const dayKey = `${now.getUTCFullYear()}-${String(now.getUTCMonth() + 1).padStart(2, '0')}-${String(now.getUTCDate()).padStart(2, '0')}`;

    const minute = AIService.googleMinuteBucket.get('google');
    if (!minute || minute.windowKey !== windowKey) {
      AIService.googleMinuteBucket.set('google', { windowKey, count: 0 });
    }
    const day = AIService.googleDailyBucket.get('google');
    if (!day || day.dayKey !== dayKey) {
      AIService.googleDailyBucket.set('google', { dayKey, count: 0 });
    }

    const m = AIService.googleMinuteBucket.get('google')!;
    const d = AIService.googleDailyBucket.get('google')!;

    if (m.count >= perMinuteLimit) {
      const quota = this.getGoogleQuotaInfo();
      throw new HttpException(
        {
          message: `Đã đạt rate limit Google provider: ${perMinuteLimit} requests/phút.`,
          quota,
        },
        HttpStatus.TOO_MANY_REQUESTS,
      );
    }
    if (d.count >= dailyLimit) {
      const quota = this.getGoogleQuotaInfo();
      throw new HttpException(
        {
          message: `Đã đạt daily limit Google provider: ${dailyLimit} requests/ngày.`,
          quota,
        },
        HttpStatus.TOO_MANY_REQUESTS,
      );
    }

    m.count += 1;
    d.count += 1;
  }

  private sanitizeJsonControlChars(input: string) {
    // OpenRouter models sometimes output raw control characters inside JSON strings
    // (e.g. literal newlines), which makes JSON.parse fail with "Bad control character".
    // This sanitizer escapes control characters only when inside a quoted string.
    let out = '';
    let inString = false;
    let escaped = false;

    for (let i = 0; i < input.length; i++) {
      const ch = input[i];

      if (!inString) {
        if (ch === '"') inString = true;
        out += ch;
        continue;
      }

      if (escaped) {
        escaped = false;
        out += ch;
        continue;
      }

      if (ch === '\\') {
        escaped = true;
        out += ch;
        continue;
      }

      if (ch === '"') {
        inString = false;
        out += ch;
        continue;
      }

      const code = ch.charCodeAt(0);
      if (code >= 0 && code <= 0x1f) {
        if (ch === '\n') out += '\\n';
        else if (ch === '\r') out += '\\r';
        else if (ch === '\t') out += '\\t';
        else out += `\\u${code.toString(16).padStart(4, '0')}`;
        continue;
      }

      out += ch;
    }
    return out;
  }

  private get apiKey(): string {
    return process.env.OPENROUTER_API_KEY || '';
  }

  private readonly TOPIK_SYSTEM_PROMPT = `Bạn là chuyên gia ra đề thi TOPIK (Kỳ thi năng lực tiếng Hàn). Bạn phải tạo nội dung giống đề TOPIK thật: tự nhiên, chuẩn phong cách thi, có bẫy hợp lý nhưng không mơ hồ.

QUY TẮC BẮT BUỘC:
1) Chỉ trả về JSON hợp lệ, KHÔNG markdown, KHÔNG giải thích.
2) contentHtml có thể là text thuần, nhưng phải là chuỗi (không được null).
3) Với câu MCQ: phải có đúng 4 lựa chọn, orderIndex tăng dần từ 1..4, đúng 1 lựa chọn isCorrect=true.
4) Với LISTENING: luôn tạo listeningScript bằng tiếng Hàn (có thể 1-3 câu) phù hợp với câu hỏi. audioUrl = null.
5) Với WRITING:
   - SHORT_TEXT: có correctTextAnswer (một đáp án mẫu ngắn).
   - ESSAY: không cần correctTextAnswer.
6) Không tạo nội dung nhạy cảm/vi phạm pháp luật. Ngôn ngữ: tiếng Hàn cho câu hỏi/nội dung nghe; có thể thêm tiếng Việt cho hướng dẫn nếu cần, nhưng ưu tiên giống đề TOPIK (chủ yếu tiếng Hàn).
`;

  private getTopikBlueprint(topikLevel: 'TOPIK_I' | 'TOPIK_II') {
    if (topikLevel === 'TOPIK_I') {
      return {
        durationMinutes: 100,
        sections: [
          { type: 'LISTENING' as const, orderIndex: 1, durationMinutes: 40, maxScore: 100, questionCount: 30 },
          { type: 'READING' as const, orderIndex: 2, durationMinutes: 60, maxScore: 100, questionCount: 40 },
        ],
      };
    }
    return {
      durationMinutes: 180,
      sections: [
        { type: 'LISTENING' as const, orderIndex: 1, durationMinutes: 60, maxScore: 100, questionCount: 50 },
        { type: 'WRITING' as const, orderIndex: 2, durationMinutes: 50, maxScore: 100, questionCount: 4 },
        { type: 'READING' as const, orderIndex: 3, durationMinutes: 70, maxScore: 100, questionCount: 50 },
      ],
    };
  }

  private async generateTopikQuestionsChunk(params: {
    topikLevel: 'TOPIK_I' | 'TOPIK_II';
    sectionType: 'LISTENING' | 'READING' | 'WRITING';
    startIndex: number;
    endIndex: number;
    provider: AiProvider;
    model?: string;
  }): Promise<TopikGeneratedQuestion[]> {
    const count = params.endIndex - params.startIndex + 1;
    const systemPrompt = this.TOPIK_SYSTEM_PROMPT;

    const writingHint =
      params.sectionType === 'WRITING'
        ? `WRITING phải gồm 4 câu theo phong cách TOPIK II: thường có câu điền từ/viết câu ngắn (SHORT_TEXT) và 1 câu bài viết dài (ESSAY). Hãy phân bổ hợp lý trong ${count} câu của chunk này.`
        : '';

    const userPrompt = `Hãy tạo ${count} câu hỏi cho section ${params.sectionType} của đề ${params.topikLevel}.

Ràng buộc:
- orderIndex phải chạy từ ${params.startIndex} đến ${params.endIndex}.
- Cấu trúc JSON phải đúng:
{
  "questions": [
    {
      "questionType": "MCQ"|"SHORT_TEXT"|"ESSAY",
      "orderIndex": 1,
      "contentHtml": "...",
      "audioUrl": null,
      "listeningScript": "...",
      "correctTextAnswer": "...",
      "scoreWeight": 1,
      "explanation": "...",
      "choices": [
        {"orderIndex":1,"content":"...","isCorrect":false}
      ]
    }
  ]
}

Ghi chú:
- LISTENING: luôn có listeningScript (tiếng Hàn), audioUrl = null, thường là MCQ.
- READING: thường là MCQ.
- WRITING: có thể SHORT_TEXT hoặc ESSAY. ESSAY có prompt rõ ràng như đề TOPIK thật.
${writingHint}`;

    const tryParseOnce = async () => {
      // Use a slightly lower maxTokens to reduce the chance of truncation/invalid JSON.
      const parsed = await this.callAiJson(
        params.provider,
        systemPrompt,
        userPrompt,
        params.model,
        12000,
      );
      const items = Array.isArray(parsed?.questions) ? parsed.questions : [];
      return items as TopikGeneratedQuestion[];
    };

    try {
      return await tryParseOnce();
    } catch (e) {
      // If JSON parse fails, split the chunk into smaller chunks and retry.
      // This reduces output size and improves reliability.
      if (count <= 1) {
        return await tryParseOnce();
      }

      const mid = params.startIndex + Math.floor((count - 1) / 2);
      const left = await this.generateTopikQuestionsChunk({
        ...params,
        startIndex: params.startIndex,
        endIndex: mid,
      });
      const right = await this.generateTopikQuestionsChunk({
        ...params,
        startIndex: mid + 1,
        endIndex: params.endIndex,
      });
      return [...left, ...right];
    }
  }

  async generateTopikExamPayload(
    input: GenerateTopikExamInput,
    provider?: string,
    model?: string,
  ): Promise<{ payload: TopikExamImportPayload; stats: any }> {
    const topikLevel = input.topikLevel;
    const year = Number.isFinite(Number(input.year)) ? Number(input.year) : new Date().getFullYear();
    const blueprint = this.getTopikBlueprint(topikLevel);
    const batchSizeDefault = topikLevel === 'TOPIK_II' ? 10 : 10;
    // Keep batchSize conservative to reduce OpenRouter token/credit usage and JSON failures.
    const batchSize = Math.max(1, Math.min(10, Math.floor(input.batchSize || batchSizeDefault)));

    const totalQuestions = blueprint.sections.reduce((sum, s) => sum + s.questionCount, 0);
    const title = (input.title && String(input.title).trim()) || `${topikLevel.replace('_', ' ')} ${year}`;

    const payload: TopikExamImportPayload = {
      exam: {
        title,
        year,
        topikLevel,
        level: null,
        durationMinutes: blueprint.durationMinutes,
        totalQuestions,
        status: input.status || 'DRAFT',
      },
      sections: [],
    };

    const stats: any = {
      topikLevel,
      year,
      totalQuestions,
      sections: [],
      batchSize,
      provider: this.normalizeProvider(provider),
      model: model || 'google/gemini-2.0-flash-001',
    };

    const resolvedProvider = this.normalizeProvider(provider);

    for (const s of blueprint.sections) {
      const section: TopikGeneratedSection = {
        type: s.type,
        orderIndex: s.orderIndex,
        durationMinutes: s.durationMinutes,
        maxScore: s.maxScore,
        questions: [],
      };

      const sectionStats: any = {
        type: s.type,
        questionCount: s.questionCount,
        batches: 0,
      };

      let start = 1;
      while (start <= s.questionCount) {
        const end = Math.min(s.questionCount, start + batchSize - 1);
        sectionStats.batches++;

        const chunk = await this.generateTopikQuestionsChunk({
          topikLevel,
          sectionType: s.type,
          startIndex: start,
          endIndex: end,
          provider: resolvedProvider,
          model,
        });

        // Normalize
        for (const q of chunk) {
          const qt = String((q as any).questionType || '').trim();
          const orderIndex = Number((q as any).orderIndex);
          if (!Number.isFinite(orderIndex)) continue;

          const normalized: TopikGeneratedQuestion = {
            questionType: (qt as any) || 'MCQ',
            orderIndex,
            contentHtml: String((q as any).contentHtml || '').trim(),
            audioUrl: (q as any).audioUrl ?? null,
            listeningScript: (q as any).listeningScript ?? null,
            correctTextAnswer: (q as any).correctTextAnswer ?? null,
            scoreWeight: Number.isFinite(Number((q as any).scoreWeight)) ? Number((q as any).scoreWeight) : 1,
            explanation: (q as any).explanation ?? null,
            choices: Array.isArray((q as any).choices)
              ? (q as any).choices.map((c: any, idx: number) => ({
                  orderIndex: Number.isFinite(Number(c?.orderIndex)) ? Number(c.orderIndex) : idx + 1,
                  content: String(c?.content || '').trim(),
                  isCorrect: c?.isCorrect === true,
                }))
              : undefined,
          };

          if (s.type === 'LISTENING') {
            normalized.audioUrl = null;
            normalized.listeningScript = String(normalized.listeningScript || '').trim();
          }

          // Ensure MCQ has 4 choices
          if (normalized.questionType === 'MCQ') {
            const choices = Array.isArray(normalized.choices) ? normalized.choices : [];
            const trimmed = choices.filter((c) => String(c.content || '').trim().length).slice(0, 4);
            while (trimmed.length < 4) {
              trimmed.push({ orderIndex: trimmed.length + 1, content: `선택 ${trimmed.length + 1}`, isCorrect: false });
            }
            // Ensure exactly one correct
            const correctCount = trimmed.filter((c) => c.isCorrect).length;
            if (correctCount === 0) trimmed[0].isCorrect = true;
            if (correctCount > 1) {
              let first = true;
              for (const c of trimmed) {
                if (c.isCorrect) {
                  if (first) first = false;
                  else c.isCorrect = false;
                }
              }
            }
            normalized.choices = trimmed.map((c, i) => ({ ...c, orderIndex: i + 1 }));
          } else {
            delete (normalized as any).choices;
          }

          section.questions.push(normalized);
        }

        start = end + 1;
      }

      // Sort and clamp
      section.questions.sort((a, b) => a.orderIndex - b.orderIndex);
      section.questions = section.questions.filter((q) => q.orderIndex >= 1 && q.orderIndex <= s.questionCount);

      payload.sections.push(section);
      stats.sections.push(sectionStats);
    }

    return { payload, stats };
  }

  async callJson(
    systemPrompt: string,
    userPrompt: string,
    modelOverride?: string,
  ): Promise<any> {
    return this.callOpenRouterJson(systemPrompt, userPrompt, modelOverride);
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
    maxTokens = 18000,
  ): Promise<any> {
    if (!this.apiKey) {
      throw new Error('OPENROUTER_API_KEY is not configured');
    }

    const resolvedModel =
      (modelOverride && String(modelOverride).trim()) ||
      process.env.OPENROUTER_MODEL ||
      'google/gemini-2.0-flash-001';

    if (this.isFreeModel(resolvedModel)) {
      this.enforceFreeModelQuota(resolvedModel);
    }

    const postOnce = async (tokenLimit: number) => {
      return axios.post(
        'https://openrouter.ai/api/v1/chat/completions',
        {
          model: resolvedModel,
          messages: [
            { role: 'system', content: systemPrompt },
            { role: 'user', content: userPrompt },
          ],
          temperature: 0.2,
          max_tokens: tokenLimit,
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
    };

    let response: any;
    try {
      response = await postOnce(maxTokens);
    } catch (err: any) {
      const status = err?.response?.status;
      if (status === 402) {
        const rawMsg =
          err?.response?.data?.error?.message ||
          err?.response?.data?.message ||
          err?.message ||
          '';
        const m = String(rawMsg);

        // Example:
        // "You requested up to 8192 tokens, but can only afford 5828."
        const affordMatch = m.match(/afford\s+(\d+)/i);
        const affordable = affordMatch ? Number(affordMatch[1]) : null;

        this.logger.warn(
          {
            status,
            model: modelOverride || 'default',
            requestedMaxTokens: maxTokens,
            affordableMaxTokens: affordable,
            message: err?.response?.data?.error || err?.response?.data || err?.message,
          },
          'OpenRouter quota/credits error',
        );

        // Best-effort retry once with the affordable token limit if provided.
        if (typeof affordable === 'number' && Number.isFinite(affordable) && affordable > 1000) {
          try {
            response = await postOnce(Math.max(1000, affordable - 200));
          } catch (_) {
            throw new ServiceUnavailableException(
              'OpenRouter hết credits hoặc token limit không đủ (HTTP 402). Vui lòng nạp credits / giảm batchSize / đổi model.',
            );
          }
        } else {
          throw new ServiceUnavailableException(
            'OpenRouter hết credits hoặc token limit không đủ (HTTP 402). Vui lòng nạp credits / giảm batchSize / đổi model.',
          );
        }
      } else {
        throw err;
      }
    }

    const content = response.data?.choices?.[0]?.message?.content || '';

    const raw = String(content);
    const fenced = raw.match(/```json\s*([\s\S]*?)```/i) || raw.match(/```\s*([\s\S]*?)```/i);
    let jsonStr = fenced ? String(fenced[1] || '').trim() : raw.trim();

    if (!jsonStr.startsWith('{')) {
      const first = jsonStr.indexOf('{');
      const last = jsonStr.lastIndexOf('}');
      if (first >= 0 && last > first) {
        jsonStr = jsonStr.slice(first, last + 1);
      }
    }

    const trimmed = String(jsonStr).trim();
    try {
      return JSON.parse(trimmed);
    } catch (e) {
      // Try to sanitize raw control characters inside JSON strings.
      // This addresses errors like "Bad control character in string literal".
      try {
        const sanitized = this.sanitizeJsonControlChars(trimmed);
        return JSON.parse(sanitized);
      } catch (_) {
        // fall through to logging below
      }

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

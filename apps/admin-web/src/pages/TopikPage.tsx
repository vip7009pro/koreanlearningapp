import { useMutation, useQuery } from '@tanstack/react-query';
import { useMemo, useState } from 'react';
import { useNavigate } from 'react-router-dom';
import toast from 'react-hot-toast';
import { FiUpload, FiZap, FiDownload, FiClipboard, FiCopy } from 'react-icons/fi';
import { aiAdminApi, topikAdminApi } from '../lib/api';

type TopikLevel = 'TOPIK_I' | 'TOPIK_II';

type GenerateResult = {
  payload: any;
  stats?: any;
};

const DEFAULT_GOOGLE_MODEL = 'models/gemma-4-31b-it';

export default function TopikPage() {
  const navigate = useNavigate();
  const [importJson, setImportJson] = useState('');

  const [provider, setProvider] = useState<'openrouter' | 'google'>('openrouter');
  const [model, setModel] = useState('');
  const [topikLevel, setTopikLevel] = useState<TopikLevel>('TOPIK_II');
  const [year, setYear] = useState<number>(new Date().getFullYear());
  const [title, setTitle] = useState('');
  const [batchSize, setBatchSize] = useState<number>(10);
  const [status, setStatus] = useState<'DRAFT' | 'PUBLISHED'>('DRAFT');

  const [generated, setGenerated] = useState<GenerateResult | null>(null);
  const [showTopikPrompt, setShowTopikPrompt] = useState(false);
  const [topikPromptText, setTopikPromptText] = useState('');

  const { data: exams } = useQuery({
    queryKey: ['topik-exams'],
    queryFn: () => topikAdminApi.listExams().then((r) => r.data),
  });

  const parsedImport = useMemo(() => {
    try {
      const trimmed = importJson.trim();
      if (!trimmed) return null;
      return JSON.parse(trimmed);
    } catch {
      return undefined;
    }
  }, [importJson]);

  const importMut = useMutation({
    mutationFn: (payload: any) => topikAdminApi.importExam(payload),
    onSuccess: () => {
      toast.success('Imported TOPIK exam successfully');
      setImportJson('');
    },
    onError: (err: any) => toast.error('Import failed: ' + (err.response?.data?.message || err.message)),
  });

  const genMut = useMutation({
    mutationFn: (input: any) => aiAdminApi.generateTopikExam(input, provider, model || undefined).then((r) => r.data),
    onSuccess: (data: any) => {
      setGenerated(data);
      toast.success('Generated payload');
    },
    onError: (err: any) => toast.error('Generate failed: ' + (err.response?.data?.message || err.message)),
  });

  const modelsQuery = useQuery({
    queryKey: ['ai-models', provider],
    queryFn: () => aiAdminApi.listModels(provider).then((r) => r.data),
  });

  const modelOptions = useMemo(() => {
    const models = Array.isArray(modelsQuery.data?.models) ? modelsQuery.data.models : [];
    return [{ id: '', label: provider === 'google' ? `${DEFAULT_GOOGLE_MODEL} (default)` : '(default)' }, ...models];
  }, [modelsQuery.data, provider]);

  const quota = modelsQuery.data?.quota;

  const handleUploadJsonFile = async (file: File) => {
    try {
      const text = await file.text();
      setImportJson(text);
      toast.success('Loaded JSON file');
    } catch {
      toast.error('Cannot read file');
    }
  };

  const handleImport = () => {
    if (parsedImport === null) {
      toast.error('Paste/upload JSON first');
      return;
    }
    if (parsedImport === undefined) {
      toast.error('Invalid JSON');
      return;
    }
    importMut.mutate(parsedImport);
  };

  const handleGenerate = () => {
    genMut.mutate({
      topikLevel,
      year,
      title: title.trim().length ? title.trim() : undefined,
      batchSize,
      status,
    });
  };

  const handleImportGenerated = () => {
    const payload = generated?.payload;
    if (!payload) {
      toast.error('No generated payload');
      return;
    }

    // Normalize payload to ensure it's plain JSON (some backends/validators are strict
    // and may reject undefined/non-serializable values).
    try {
      const normalized = JSON.parse(JSON.stringify(payload));
      importMut.mutate(normalized);
    } catch {
      importMut.mutate(payload);
    }
  };

  const handleDownloadGenerated = () => {
    const payload = generated?.payload;
    if (!payload) {
      toast.error('No generated payload');
      return;
    }
    const blob = new Blob([JSON.stringify(payload, null, 2)], { type: 'application/json' });
    const url = URL.createObjectURL(blob);
    const a = document.createElement('a');
    a.href = url;
    a.download = `topik_${topikLevel}_${year}.json`;
    a.click();
    URL.revokeObjectURL(url);
  };

  const validateInfo = useMemo(() => {
    if (parsedImport == null || parsedImport === undefined) return null;
    try {
      const exam = parsedImport.exam;
      const sections = Array.isArray(parsedImport.sections) ? parsedImport.sections : [];
      const sectionCounts = sections.map((s: any) => {
        const qs = Array.isArray(s.questions) ? s.questions.length : 0;
        return `${String(s.type || 'UNKNOWN')}=${qs}`;
      });
      return {
        title: exam?.title,
        topikLevel: exam?.topikLevel,
        year: exam?.year,
        totalQuestions: exam?.totalQuestions,
        sections: sectionCounts.join(', '),
      };
    } catch {
      return null;
    }
  }, [parsedImport]);

  const generateTopikPrompt = () => {
    const lvl = topikLevel === 'TOPIK_I' ? 'TOPIK I (sơ cấp, 1-2급)' : 'TOPIK II (trung-cao cấp, 3-6급)';
    const examTitle = title.trim() || `${topikLevel.replace('_', ' ')} ${year}`;

    const bp = topikLevel === 'TOPIK_I'
      ? { totalQ: 70, dur: 100, sections: 'LISTENING (30 câu, 40 phút), READING (40 câu, 60 phút)' }
      : { totalQ: 104, dur: 180, sections: 'LISTENING (50 câu, 60 phút), WRITING (4 câu, 50 phút), READING (50 câu, 70 phút)' };

    const prompt = `Bạn là chuyên gia ra đề thi TOPIK (Kỳ thi năng lực tiếng Hàn). Bạn phải tạo nội dung giống đề TOPIK thật: tự nhiên, chuẩn phong cách thi, có bẫy hợp lý nhưng không mơ hồ.

QUY TẮC BẮT BUỘC:
1) Chỉ trả về JSON hợp lệ, KHÔNG markdown, KHÔNG giải thích.
2) contentHtml có thể là text thuần, nhưng phải là chuỗi (không được null).
3) Với câu MCQ: phải có đúng 4 lựa chọn, orderIndex tăng dần từ 1..4, đúng 1 lựa chọn isCorrect=true.
4) Với LISTENING: luôn tạo listeningScript bằng tiếng Hàn (có thể 1-3 câu) phù hợp với câu hỏi. audioUrl = null.
5) Với WRITING:
   - SHORT_TEXT: có correctTextAnswer (một đáp án mẫu ngắn).
   - ESSAY: không cần correctTextAnswer.
6) Ngôn ngữ: tiếng Hàn cho câu hỏi/nội dung nghe; có thể thêm tiếng Việt cho hướng dẫn.

Hãy tạo đề thi ${lvl} năm ${year}.
Cấu trúc: ${bp.sections}
Tổng: ${bp.totalQ} câu, ${bp.dur} phút.

Trả về JSON theo format sau:

{
  "exam": {
    "title": "${examTitle}",
    "topikLevel": "${topikLevel}",
    "year": ${year},
    "totalQuestions": ${bp.totalQ},
    "durationMinutes": ${bp.dur},
    "status": "${status}"
  },
  "sections": [
    {
      "type": "LISTENING",
      "orderIndex": 1,
      "durationMinutes": ${topikLevel === 'TOPIK_I' ? 40 : 60},
      "maxScore": 100,
      "questions": [
        {
          "questionType": "MCQ",
          "orderIndex": 1,
          "contentHtml": "Nội dung câu hỏi",
          "audioUrl": null,
          "listeningScript": "대화/음성 내용 (tiếng Hàn)",
          "correctTextAnswer": null,
          "scoreWeight": 1,
          "explanation": "Giải thích đáp án",
          "choices": [
            {"orderIndex": 1, "content": "Đáp án 1", "isCorrect": false},
            {"orderIndex": 2, "content": "Đáp án 2", "isCorrect": true},
            {"orderIndex": 3, "content": "Đáp án 3", "isCorrect": false},
            {"orderIndex": 4, "content": "Đáp án 4", "isCorrect": false}
          ]
        }
      ]
    },
    {
      "type": "READING",
      "orderIndex": ${topikLevel === 'TOPIK_I' ? 2 : 3},
      "durationMinutes": ${topikLevel === 'TOPIK_I' ? 60 : 70},
      "maxScore": 100,
      "questions": [ ... tương tự MCQ ... ]
    }${topikLevel === 'TOPIK_II' ? `,
    {
      "type": "WRITING",
      "orderIndex": 2,
      "durationMinutes": 50,
      "maxScore": 100,
      "questions": [
        {
          "questionType": "SHORT_TEXT",
          "orderIndex": 1,
          "contentHtml": "Đề viết ngắn",
          "correctTextAnswer": "Đáp án mẫu",
          "scoreWeight": 1
        },
        {
          "questionType": "ESSAY",
          "orderIndex": 4,
          "contentHtml": "Hãy viết bài luận 200-300 chữ về chủ đề...",
          "scoreWeight": 4
        }
      ]
    }` : ''}
  ]
}

Hãy tạo đầy đủ số lượng câu hỏi theo quy định mỗi section. Chỉ trả về JSON, không có text nào khác.`;

    setTopikPromptText(prompt);
    setShowTopikPrompt(true);
  };

  const copyTopikPrompt = () => {
    navigator.clipboard.writeText(topikPromptText).then(() => {
      toast.success('Đã copy prompt TOPIK!');
    });
  };

  return (
    <div>
      <h1 className="text-2xl font-bold text-primary-800 mb-6">TOPIK</h1>

      <div className="card mb-6">
        <h2 className="text-lg font-semibold text-gray-800 mb-4">Exams</h2>
        <div className="overflow-x-auto">
          <table className="min-w-full">
            <thead>
              <tr className="bg-gray-50">
                <th className="table-header">Title</th>
                <th className="table-header">Level</th>
                <th className="table-header">Year</th>
                <th className="table-header">Status</th>
                <th className="table-header">Sections</th>
              </tr>
            </thead>
            <tbody className="divide-y divide-gray-100">
              {(Array.isArray(exams) ? exams : []).map((e: any) => (
                <tr
                  key={e.id}
                  className="hover:bg-gray-50 cursor-pointer"
                  onClick={() => navigate(`/topik/exams/${e.id}`)}
                >
                  <td className="table-cell font-medium text-gray-900">{e.title}</td>
                  <td className="table-cell">{e.topikLevel}</td>
                  <td className="table-cell">{e.year}</td>
                  <td className="table-cell">
                    <span className={`badge ${e.status === 'PUBLISHED' ? 'badge-green' : 'badge-yellow'}`}>
                      {e.status}
                    </span>
                  </td>
                  <td className="table-cell">{Array.isArray(e.sections) ? e.sections.length : 0}</td>
                </tr>
              ))}
              {(!exams || (Array.isArray(exams) && exams.length === 0)) && (
                <tr>
                  <td className="table-cell text-gray-400" colSpan={5}>No exams yet</td>
                </tr>
              )}
            </tbody>
          </table>
        </div>
        <p className="text-xs text-gray-400 mt-3">Click an exam to edit questions/answers and publish/draft.</p>
      </div>

      <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
        <div className="card">
          <div className="flex items-center justify-between mb-4">
            <h2 className="text-lg font-semibold text-gray-800">Import JSON</h2>
            <label className="btn-secondary flex items-center gap-2 cursor-pointer">
              <FiUpload />
              <span>Upload</span>
              <input
                type="file"
                accept="application/json"
                className="hidden"
                onChange={(e) => {
                  const f = e.target.files?.[0];
                  if (f) handleUploadJsonFile(f);
                }}
              />
            </label>
          </div>

          <textarea
            className="input min-h-[260px] font-mono"
            placeholder="Paste payload JSON: { exam: {...}, sections: [...] }"
            value={importJson}
            onChange={(e) => setImportJson(e.target.value)}
          />

          {validateInfo && (
            <div className="mt-3 text-sm text-gray-700">
              <div className="flex items-center gap-2">
                <span className="badge badge-blue">Preview</span>
                <span className="font-medium">{validateInfo.title || '(no title)'}</span>
              </div>
              <div className="mt-1 text-xs text-gray-500">
                {String(validateInfo.topikLevel || '')} · {String(validateInfo.year || '')} · totalQuestions={String(validateInfo.totalQuestions || '')}
              </div>
              <div className="mt-1 text-xs text-gray-500">{validateInfo.sections}</div>
            </div>
          )}

          <div className="flex gap-2 mt-4">
            <button
              className="btn-primary flex items-center gap-2"
              onClick={handleImport}
              disabled={importMut.isPending}
            >
              <FiClipboard />
              <span>{importMut.isPending ? 'Importing...' : 'Import'}</span>
            </button>
          </div>
        </div>

        <div className="card">
          <div className="flex items-center justify-between mb-4">
            <h2 className="text-lg font-semibold text-gray-800">AI Generate (Chuẩn TOPIK)</h2>
          </div>

          <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
            <div>
              <label className="label">Provider</label>
              <select className="input" value={provider} onChange={(e) => {
                const p = e.target.value as any;
                setProvider(p);
                setModel(p === 'google' ? DEFAULT_GOOGLE_MODEL : '');
              }}>
                <option value="openrouter">OpenRouter</option>
                <option value="google">Google (Gemma)</option>
              </select>
            </div>

            <div>
              <label className="label">Model</label>
              <select
                className="input"
                value={model}
                onChange={(e) => setModel(e.target.value)}
                disabled={modelsQuery.isLoading}
              >
                {modelOptions.map((m: any) => (
                  <option key={m.id || 'default'} value={m.id}>
                    {m.label}
                  </option>
                ))}
              </select>
              <p className="text-xs text-gray-400 mt-1">
                {provider === 'openrouter'
                  ? '(default) = dùng OPENROUTER_MODEL mặc định.'
                  : `(default) = dùng ${DEFAULT_GOOGLE_MODEL} (backend).`}
              </p>
              {quota && (
                <p className="text-xs text-gray-500 mt-1">
                  Quota (server limiter): {quota.perMinuteRemaining}/{quota.perMinuteLimit} req/phút (reset {quota.minuteResetAt})
                  {' • '}
                  {quota.dailyRemaining}/{quota.dailyLimit} req/ngày (reset {quota.dayResetAt})
                </p>
              )}
            </div>

            <div>
              <label className="label">TOPIK Level</label>
              <select className="input" value={topikLevel} onChange={(e) => setTopikLevel(e.target.value as TopikLevel)}>
                <option value="TOPIK_I">TOPIK I</option>
                <option value="TOPIK_II">TOPIK II</option>
              </select>
            </div>

            <div>
              <label className="label">Year</label>
              <input
                type="number"
                className="input"
                value={year}
                onChange={(e) => setYear(Number(e.target.value || new Date().getFullYear()))}
              />
            </div>

            <div>
              <label className="label">Status</label>
              <select className="input" value={status} onChange={(e) => setStatus(e.target.value as any)}>
                <option value="DRAFT">DRAFT</option>
                <option value="PUBLISHED">PUBLISHED</option>
              </select>
            </div>

            <div className="md:col-span-2">
              <label className="label">Title (optional)</label>
              <input
                className="input"
                placeholder="vd: TOPIK II 2025 - Mock 01"
                value={title}
                onChange={(e) => setTitle(e.target.value)}
              />
            </div>

            <div>
              <label className="label">Batch size (1..20)</label>
              <input
                type="number"
                className="input"
                value={batchSize}
                min={1}
                max={20}
                onChange={(e) => setBatchSize(Math.max(1, Math.min(20, Number(e.target.value || 10))))}
              />
              <p className="text-xs text-gray-400 mt-1">Batch nhỏ hơn sẽ an toàn hơn với limit nhưng chậm hơn.</p>
            </div>
          </div>

          <div className="flex flex-wrap gap-2 mt-4">
            <button
              className="btn-primary flex items-center gap-2"
              onClick={handleGenerate}
              disabled={genMut.isPending}
            >
              <FiZap />
              <span>{genMut.isPending ? 'Generating...' : 'Generate'}</span>
            </button>

            <button
              className="btn-secondary flex items-center gap-2"
              onClick={handleImportGenerated}
              disabled={importMut.isPending || !generated?.payload}
            >
              <FiClipboard />
              <span>{importMut.isPending ? 'Importing...' : 'Import payload'}</span>
            </button>

            <button
              className="btn-secondary flex items-center gap-2"
              onClick={handleDownloadGenerated}
              disabled={!generated?.payload}
            >
              <FiDownload />
              <span>Download</span>
            </button>

            <button
              className="btn-secondary flex items-center gap-2"
              onClick={generateTopikPrompt}
              title="Generate a prompt to run in external LLM"
            >
              <FiCopy />
              <span>Copy Prompt</span>
            </button>
          </div>

          {showTopikPrompt && (
            <div className="mt-4 p-4 rounded-lg border-2 border-indigo-200 bg-indigo-50">
              <div className="flex justify-between items-center mb-3">
                <h3 className="font-semibold text-indigo-800">📋 Prompt sinh đề TOPIK</h3>
                <div className="flex gap-2">
                  <button onClick={copyTopikPrompt} className="btn-primary flex items-center gap-2 text-sm">
                    <FiCopy /> Copy
                  </button>
                  <button onClick={() => setShowTopikPrompt(false)} className="btn-secondary text-sm">Đóng</button>
                </div>
              </div>
              <p className="text-xs text-indigo-600 mb-3">Copy prompt → chạy trên ChatGPT/Gemini/Claude → copy JSON kết quả → dán vào ô "Import JSON" bên trái để nhập.</p>
              <textarea
                className="input w-full font-mono text-xs bg-white"
                rows={12}
                value={topikPromptText}
                readOnly
              />
            </div>
          )}

          {generated?.stats && (
            <div className="mt-4 text-sm text-gray-700">
              <div className="flex items-center gap-2">
                <span className="badge badge-blue">Stats</span>
                <span className="text-gray-600">batchSize={String(generated.stats.batchSize)} · model={String(generated.stats.model)}</span>
              </div>
              <div className="mt-2 text-xs text-gray-500">
                {Array.isArray(generated.stats.sections)
                  ? generated.stats.sections.map((s: any) => `${String(s.type)}: ${String(s.questionCount)}q (${String(s.batches)} batches)`).join(' · ')
                  : null}
              </div>
            </div>
          )}
        </div>
      </div>
    </div>
  );
}

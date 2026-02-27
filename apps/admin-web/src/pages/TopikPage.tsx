import { useMutation, useQuery } from '@tanstack/react-query';
import { useMemo, useState } from 'react';
import { useNavigate } from 'react-router-dom';
import toast from 'react-hot-toast';
import { FiUpload, FiZap, FiDownload, FiClipboard } from 'react-icons/fi';
import { aiAdminApi, topikAdminApi } from '../lib/api';

type TopikLevel = 'TOPIK_I' | 'TOPIK_II';

type GenerateResult = {
  payload: any;
  stats?: any;
};

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
    return [{ id: '', label: '(default)' }, ...models];
  }, [modelsQuery.data]);

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
                setModel('');
              }}>
                <option value="openrouter">OpenRouter</option>
                <option value="google">Google (Gemini)</option>
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
                  : '(default) = dùng gemini-2.0-flash (backend).'}
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
          </div>

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

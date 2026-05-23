import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query';
import { useEffect, useMemo, useState } from 'react';
import { useNavigate, useParams } from 'react-router-dom';
import toast from 'react-hot-toast';
import { FiArrowLeft, FiSave, FiTrash2, FiEye, FiEyeOff, FiCopy, FiUpload, FiImage, FiChevronDown, FiChevronUp } from 'react-icons/fi';
import { topikAdminApi, uploadApi } from '../lib/api';

function stripHtml(html: string) {
  return String(html || '')
    .replace(/<[^>]*>/g, ' ')
    .replace(/\s+/g, ' ')
    .trim();
}

type ChoiceDraft = { orderIndex: number; content: string; isCorrect: boolean };

type QuestionDraft = {
  id: string;
  questionType: string;
  orderIndex: number;
  contentHtml: string;
  audioUrl?: string | null;
  listeningScript?: string | null;
  correctTextAnswer?: string | null;
  scoreWeight?: number;
  explanation?: string | null;
  imageUrl?: string | null;
  imagePrompt?: string | null;
  choices?: ChoiceDraft[];
};

export default function TopikExamEditorPage() {
  const { examId } = useParams();
  const navigate = useNavigate();
  const qc = useQueryClient();

  const [dirtyExam, setDirtyExam] = useState<Record<string, unknown>>({});
  const [dirtyQuestions, setDirtyQuestions] = useState<Record<string, QuestionDraft>>({});
  const [filterOnlyWithImage, setFilterOnlyWithImage] = useState(false);
  const [collapsedSections, setCollapsedSections] = useState<Record<string, boolean>>({});

  const { data, isLoading } = useQuery({
    queryKey: ['topik-exam', examId],
    enabled: !!examId,
    queryFn: () => topikAdminApi.getExam(examId as string).then((r) => r.data),
  });

  const exam = data;
  const sections = Array.isArray(exam?.sections) ? exam.sections : [];

  const handleToggleAllSections = (collapse: boolean) => {
    const next: Record<string, boolean> = {};
    if (collapse) {
      for (const s of sections) {
        next[s.id] = true;
      }
    }
    setCollapsedSections(next);
  };

  const questionIndex = useMemo(() => {
    const map: Record<string, QuestionDraft> = {};
    for (const s of sections) {
      const qs = Array.isArray(s.questions) ? s.questions : [];
      for (const q of qs) {
        map[q.id] = {
          id: q.id,
          questionType: q.questionType,
          orderIndex: q.orderIndex,
          contentHtml: q.contentHtml,
          audioUrl: q.audioUrl,
          listeningScript: q.listeningScript,
          correctTextAnswer: q.correctTextAnswer,
          scoreWeight: q.scoreWeight,
          explanation: q.explanation,
          imageUrl: q.imageUrl,
          imagePrompt: q.imagePrompt,
          choices: Array.isArray(q.choices)
            ? q.choices.map((c: any) => ({
                orderIndex: c.orderIndex,
                content: c.content,
                isCorrect: !!c.isCorrect,
              }))
            : undefined,
        };
      }
    }
    return map;
  }, [sections]);

  const [isGeneratingAudio, setIsGeneratingAudio] = useState<string | null>(null);
  const [isGeneratingConsolidatedAudio, setIsGeneratingConsolidatedAudio] = useState(false);
  const [listeningBatchSize, setListeningBatchSize] = useState(1);
  const [listeningJobId, setListeningJobId] = useState<string | null>(null);
  const [listeningJobStatus, setListeningJobStatus] = useState<{
    state: string;
    progress?: number;
    failedReason?: string;
  } | null>(null);
  const [ttsProvider, setTtsProvider] = useState<string>(() => {
    return localStorage.getItem('topik-tts-provider') || 'google';
  });
  const [pitchFemale, setPitchFemale] = useState<number>(() => {
    const v = localStorage.getItem('topik-tts-pitch-female');
    return v ? Number(v) : 0.85;
  });
  const [pitchMale, setPitchMale] = useState<number>(() => {
    const v = localStorage.getItem('topik-tts-pitch-male');
    return v ? Number(v) : 1.15;
  });
  const [ttsSpeed, setTtsSpeed] = useState<number>(() => {
    const v = localStorage.getItem('topik-tts-speed');
    return v ? Number(v) : 1.0;
  });
  const [silenceSeconds, setSilenceSeconds] = useState<number>(() => {
    const v = localStorage.getItem('topik-tts-silence-seconds');
    return v ? Number(v) : 5;
  });

  const [testText, setTestText] = useState('남: 안녕하세요. 여: 반갑습니다. 오늘 날씨가 정말 화창하고 좋네요.');
  const [testAudioUrl, setTestAudioUrl] = useState<string | null>(null);
  const [isTestingTts, setIsTestingTts] = useState(false);

  useEffect(() => {
    localStorage.setItem('topik-tts-provider', ttsProvider);
  }, [ttsProvider]);

  useEffect(() => {
    localStorage.setItem('topik-tts-pitch-female', String(pitchFemale));
  }, [pitchFemale]);

  useEffect(() => {
    localStorage.setItem('topik-tts-pitch-male', String(pitchMale));
  }, [pitchMale]);

  useEffect(() => {
    localStorage.setItem('topik-tts-speed', String(ttsSpeed));
  }, [ttsSpeed]);

  useEffect(() => {
    localStorage.setItem('topik-tts-silence-seconds', String(silenceSeconds));
  }, [silenceSeconds]);

  const listeningJobStorageKey = examId ? `topik-listening-audio-job:${examId}` : null;

  useEffect(() => {
    if (!examId || !listeningJobStorageKey) return;
    const storedJobId = localStorage.getItem(listeningJobStorageKey);
    if (storedJobId) {
      setListeningJobId(storedJobId);
      setIsGeneratingConsolidatedAudio(true);
    }
  }, [examId, listeningJobStorageKey]);

  useEffect(() => {
    if (!examId || !listeningJobId) return;
    let cancelled = false;

    const poll = async () => {
      try {
        const res = await topikAdminApi.getExamListeningAudioJobStatus(examId, listeningJobId);
        if (cancelled) return;
        const status = res.data || {};
        setListeningJobStatus(status);

        const state = String(status.state || '');
        const isActive = state === 'waiting' || state === 'active' || state === 'delayed';
        setIsGeneratingConsolidatedAudio(isActive);

        if (state === 'completed') {
          setListeningJobId(null);
          if (listeningJobStorageKey) localStorage.removeItem(listeningJobStorageKey);
          qc.invalidateQueries({ queryKey: ['topik-exam', examId] });
          toast.success('Đã tạo file nghe AI toàn bộ thành công!');
        }

        if (state === 'failed') {
          setListeningJobId(null);
          if (listeningJobStorageKey) localStorage.removeItem(listeningJobStorageKey);
          const reason = status.failedReason ? String(status.failedReason) : 'Unknown error';
          toast.error('Tạo file nghe AI thất bại: ' + reason);
        }
      } catch (err: any) {
        if (cancelled) return;
        setListeningJobId(null);
        setIsGeneratingConsolidatedAudio(false);
        if (listeningJobStorageKey) localStorage.removeItem(listeningJobStorageKey);
        toast.error('Không lấy được trạng thái job: ' + (err.response?.data?.message || err.message));
      }
    };

    poll();
    const timer = window.setInterval(poll, 2000);
    return () => {
      cancelled = true;
      clearInterval(timer);
    };
  }, [examId, listeningJobId, listeningJobStorageKey, qc]);

  const buildConsolidatedPrompt = () => {
    const listeningSections = sections.filter((s: any) => s.type === 'LISTENING');
    const questions = listeningSections
      .flatMap((s: any) => (Array.isArray(s.questions) ? s.questions : []))
      .sort((a: any, b: any) => a.orderIndex - b.orderIndex);

    const lines: string[] = [];
    for (const q of questions) {
      const draft = dirtyQuestions[q.id] || questionIndex[q.id] || q;
      const scriptText = String(draft?.listeningScript || '').trim();
      if (!scriptText) continue;

      const orderIndex = Number.isFinite(Number(draft?.orderIndex)) ? Number(draft.orderIndex) : q.orderIndex;
      const instruction = stripHtml(draft?.contentHtml ?? q.contentHtml ?? '');
      const header = `제 ${orderIndex}번. ${instruction}`.trim();
      const combined = header ? `${header}\n${scriptText}` : scriptText;
      lines.push(combined);
    }

    return lines.join('\n\n');
  };

  const handleGenerateConsolidatedAudio = async () => {
    if (!examId) return;
    setIsGeneratingConsolidatedAudio(true);
    const safeBatchSize = Math.max(1, Math.min(200, Math.floor(Number(listeningBatchSize) || 1)));
    try {
      const res = await topikAdminApi.generateExamListeningAudioJob(examId, { 
        batchSize: safeBatchSize,
        provider: ttsProvider,
        pitchFemale,
        pitchMale,
        speed: ttsSpeed,
        silenceSeconds,
      });
      const jobId = res.data?.jobId;
      if (!jobId) {
        toast.error('Không tạo được job. Vui lòng thử lại.');
        setIsGeneratingConsolidatedAudio(false);
        return;
      }
      setListeningJobId(String(jobId));
      setListeningJobStatus({ state: 'waiting', progress: 0 });
      if (listeningJobStorageKey) localStorage.setItem(listeningJobStorageKey, String(jobId));
      toast.success('Đã tạo job, đang xử lý...');
    } catch (err: any) {
      toast.error('Tạo file nghe AI thất bại: ' + (err.response?.data?.message || err.message));
      setIsGeneratingConsolidatedAudio(false);
    }
  };

  const handleGenerateAudio = async (qid: string) => {
    const d = dirtyQuestions[qid] || questionIndex[qid];
    if (!d?.listeningScript?.trim()) {
      toast.error('Vui lòng nhập Listening Script trước khi tạo âm thanh AI');
      return;
    }
    setIsGeneratingAudio(qid);
    try {
      const res = await topikAdminApi.generateQuestionAudio(qid, {
        provider: ttsProvider,
        pitchFemale,
        pitchMale,
        speed: ttsSpeed,
      });
      const url = res.data?.audioUrl;
      if (url) {
        setDirtyQuestions((prev) => ({
          ...prev,
          [qid]: {
            ...(prev[qid] || questionIndex[qid]),
            audioUrl: url,
          },
        }));
        toast.success('Đã tạo audio AI thành công!');
        qc.invalidateQueries({ queryKey: ['topik-exam', examId] });
      }
    } catch (err: any) {
      toast.error('AI Gen failed: ' + (err.response?.data?.message || err.message));
    } finally {
      setIsGeneratingAudio(null);
    }
  };

  const handleTestTts = async () => {
    if (!testText.trim()) {
      toast.error('Vui lòng nhập văn bản thử nghiệm');
      return;
    }
    setIsTestingTts(true);
    setTestAudioUrl(null);
    try {
      const res = await topikAdminApi.testTts({
        text: testText,
        provider: ttsProvider,
        pitchFemale,
        pitchMale,
        speed: ttsSpeed,
      });
      const url = res.data?.audioUrl;
      if (url) {
        setTestAudioUrl(url);
        toast.success('Đã sinh giọng thử thành công!');
      } else {
        toast.error('Không nhận được URL âm thanh.');
      }
    } catch (err: any) {
      toast.error('Sinh giọng thử thất bại: ' + (err.response?.data?.message || err.message));
    } finally {
      setIsTestingTts(false);
    }
  };

  const deleteMut = useMutation({
    mutationFn: (id: string) => topikAdminApi.deleteExam(id),
    onSuccess: () => {
      toast.success('Deleted');
      qc.invalidateQueries({ queryKey: ['topik-exams'] });
      navigate('/topik');
    },
    onError: (err: any) => toast.error('Delete failed: ' + (err.response?.data?.message || err.message)),
  });

  const publishMut = useMutation({
    mutationFn: ({ id, publish }: { id: string; publish: boolean }) =>
      publish ? topikAdminApi.publishExam(id) : topikAdminApi.unpublishExam(id),
    onSuccess: () => {
      toast.success('Status updated');
      qc.invalidateQueries({ queryKey: ['topik-exam', examId] });
      qc.invalidateQueries({ queryKey: ['topik-exams'] });
    },
    onError: (err: any) => toast.error('Status update failed: ' + (err.response?.data?.message || err.message)),
  });

  const updateExamMut = useMutation({
    mutationFn: ({ id, patch }: { id: string; patch: Record<string, unknown> }) => topikAdminApi.updateExam(id, patch),
    onSuccess: () => {
      toast.success('Exam saved');
      setDirtyExam({});
      qc.invalidateQueries({ queryKey: ['topik-exam', examId] });
      qc.invalidateQueries({ queryKey: ['topik-exams'] });
    },
    onError: (err: any) => toast.error('Save exam failed: ' + (err.response?.data?.message || err.message)),
  });

  const updateQuestionMut = useMutation({
    mutationFn: ({ id, patch }: { id: string; patch: Record<string, unknown> }) => topikAdminApi.updateQuestion(id, patch),
    onSuccess: () => {
      toast.success('Question saved');
      qc.invalidateQueries({ queryKey: ['topik-exam', examId] });
    },
    onError: (err: any) => toast.error('Save question failed: ' + (err.response?.data?.message || err.message)),
  });

  const handleSaveExam = () => {
    if (!examId) return;
    if (Object.keys(dirtyExam).length === 0) {
      toast('Nothing to save');
      return;
    }
    updateExamMut.mutate({ id: examId, patch: dirtyExam });
  };

  const handleSaveQuestion = (qid: string) => {
    if (!qid) return;
    const d = dirtyQuestions[qid];
    if (!d) return;
    const patch: Record<string, unknown> = {
      questionType: d.questionType,
      orderIndex: d.orderIndex,
      contentHtml: d.contentHtml,
      audioUrl: d.audioUrl,
      listeningScript: d.listeningScript,
      correctTextAnswer: d.correctTextAnswer,
      scoreWeight: d.scoreWeight,
      explanation: d.explanation,
      imageUrl: d.imageUrl,
      imagePrompt: d.imagePrompt,
    };
    if (d.questionType === 'MCQ') {
      patch.choices = (d.choices || []).map((c) => ({
        orderIndex: c.orderIndex,
        content: c.content,
        isCorrect: c.isCorrect,
      }));
    }
    updateQuestionMut.mutate({ id: qid, patch });
    setDirtyQuestions((prev) => {
      const next = { ...prev };
      delete next[qid];
      return next;
    });
  };

  const loadQuestionDraft = (qid: string) => {
    return dirtyQuestions[qid] || questionIndex[qid];
  };

  if (isLoading) return <div className="text-center py-12 text-gray-500">Loading...</div>;
  if (!exam) return <div className="text-center py-12 text-gray-500">Not found</div>;

  return (
    <div>
      <button
        onClick={() => navigate('/topik')}
        className="flex items-center gap-1 text-gray-500 hover:text-gray-700 mb-4 text-sm"
      >
        <FiArrowLeft /> Back to TOPIK
      </button>

      <div className="flex items-start justify-between gap-4 mb-6">
        <div>
          <h1 className="text-2xl font-bold text-primary-800">{exam.title}</h1>
          <div className="text-xs text-gray-500 mt-1">
            {exam.topikLevel} · {exam.year} · status={exam.status}
          </div>
        </div>
        <div className="flex flex-wrap gap-2">
          <button
            className="btn-secondary flex items-center gap-2"
            onClick={() => publishMut.mutate({ id: exam.id, publish: exam.status !== 'PUBLISHED' })}
          >
            {exam.status === 'PUBLISHED' ? <FiEyeOff /> : <FiEye />}
            <span>{exam.status === 'PUBLISHED' ? 'Set Draft' : 'Publish'}</span>
          </button>
          <button className="btn-danger flex items-center gap-2" onClick={() => deleteMut.mutate(exam.id)}>
            <FiTrash2 /> Delete
          </button>
        </div>
      </div>

      <div className="card mb-6">
        <h2 className="text-lg font-semibold text-gray-800 mb-4">Exam</h2>
        <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
          <div>
            <label className="label">Title</label>
            <input
              className="input"
              defaultValue={exam.title}
              onChange={(e) => setDirtyExam((p) => ({ ...p, title: e.target.value }))}
            />
          </div>
          <div>
            <label className="label">Year</label>
            <input
              type="number"
              className="input"
              defaultValue={exam.year}
              onChange={(e) => setDirtyExam((p) => ({ ...p, year: Number(e.target.value) }))}
            />
          </div>
          <div>
            <label className="label">Duration (minutes)</label>
            <input
              type="number"
              className="input"
              defaultValue={exam.durationMinutes}
              onChange={(e) => setDirtyExam((p) => ({ ...p, durationMinutes: Number(e.target.value) }))}
            />
          </div>
          <div>
            <label className="label">Total Questions</label>
            <input
              type="number"
              className="input"
              defaultValue={exam.totalQuestions}
              onChange={(e) => setDirtyExam((p) => ({ ...p, totalQuestions: Number(e.target.value) }))}
            />
          </div>

          {sections.some((s: any) => s.type === 'LISTENING') && (
            <div className="md:col-span-2 border-t border-gray-100 pt-4 mt-2">
              <label className="label">File nghe toàn bộ (Consolidated Listening Audio)</label>
              <div className="flex flex-wrap items-center gap-3">
                <input
                  className="input flex-1 min-w-[220px]"
                  placeholder="Đường dẫn file nghe (tự động điền sau khi tạo hoặc tải lên)"
                  value={String(dirtyExam.listeningAudioUrl !== undefined ? dirtyExam.listeningAudioUrl : (exam.listeningAudioUrl || ''))}
                  onChange={(e) => setDirtyExam((p) => ({ ...p, listeningAudioUrl: e.target.value }))}
                />
                <div className="flex items-center gap-2">
                  <span className="text-xs text-gray-600 font-semibold whitespace-nowrap">TTS Provider</span>
                  <select
                    className="input w-36 py-1 px-2 text-sm bg-white"
                    value={ttsProvider}
                    onChange={(e) => setTtsProvider(e.target.value)}
                  >
                    <option value="google">Google TTS</option>
                    <option value="local">Local TTS</option>
                  </select>
                </div>
                <div className="flex items-center gap-2">
                  <span className="text-xs text-gray-600 font-semibold whitespace-nowrap">Số câu/batch</span>
                  <input
                    type="number"
                    min={1}
                    max={200}
                    className="input w-20"
                    value={listeningBatchSize}
                    onChange={(e) => {
                      const next = Math.max(1, Math.min(200, Math.floor(Number(e.target.value) || 1)));
                      setListeningBatchSize(next);
                    }}
                  />
                </div>
                <label className="btn-secondary flex items-center gap-2 cursor-pointer whitespace-nowrap">
                  <FiUpload size={14} /> Upload Audio
                  <input
                    type="file"
                    accept="audio/*"
                    className="hidden"
                    onChange={async (e) => {
                      const file = e.target.files?.[0];
                      if (!file) return;
                      try {
                        const res = await uploadApi.uploadAudio(file);
                        const url = res.data?.url;
                        if (url) {
                          setDirtyExam((p) => ({ ...p, listeningAudioUrl: url }));
                          toast.success('Đã tải lên file nghe thành công!');
                        }
                      } catch (err: any) {
                        toast.error('Upload failed: ' + (err.message || err));
                      }
                      e.target.value = '';
                    }}
                  />
                </label>
                <button
                  type="button"
                  className="btn-secondary flex items-center gap-2 whitespace-nowrap"
                  onClick={async () => {
                    const prompt = buildConsolidatedPrompt();
                    if (!prompt.trim()) {
                      toast.error('Không có prompt để copy.');
                      return;
                    }
                    await navigator.clipboard.writeText(prompt);
                    toast.success('Đã copy prompt!');
                  }}
                >
                  <FiCopy size={14} /> Copy prompt
                </button>
                <button
                  type="button"
                  disabled={isGeneratingConsolidatedAudio}
                  onClick={handleGenerateConsolidatedAudio}
                  className="btn-primary flex items-center gap-2 whitespace-nowrap disabled:opacity-50"
                >
                  {isGeneratingConsolidatedAudio ? 'Đang tạo...' : 'Tạo file nghe AI toàn bộ'}
                </button>
              </div>

              {/* Cấu hình Giọng đọc & Tốc độ */}
              <div className="mt-4 bg-gray-50 p-4 rounded-xl border border-gray-100 grid grid-cols-1 md:grid-cols-2 gap-6">
                <div className="space-y-4">
                  <h4 className="text-sm font-semibold text-gray-700">Cấu hình giọng đọc (TTS Settings)</h4>
                  
                  {/* Silence gap slider, visible for both providers */}
                  <div>
                    <div className="flex justify-between text-xs text-gray-600 mb-1">
                      <span>Khoảng nghỉ giữa các câu: <strong>{silenceSeconds} giây</strong></span>
                      <span className="text-gray-400">Khuyên dùng: 5s</span>
                    </div>
                    <input
                      type="range"
                      min={1}
                      max={15}
                      step={1}
                      className="w-full h-2 bg-gray-200 rounded-lg appearance-none cursor-pointer accent-primary-600"
                      value={silenceSeconds}
                      onChange={(e) => setSilenceSeconds(Number(e.target.value))}
                    />
                  </div>

                  {/* Local TTS only settings */}
                  {ttsProvider === 'local' ? (
                    <>
                      <div>
                        <div className="flex justify-between text-xs text-gray-600 mb-1">
                          <span>Độ trầm bổng giọng Nữ: <strong>{pitchFemale}</strong></span>
                          <span className="text-gray-400">Nhỏ hơn = cao hơn (Mặc định: 0.85)</span>
                        </div>
                        <input
                          type="range"
                          min={0.5}
                          max={1.5}
                          step={0.05}
                          className="w-full h-2 bg-gray-200 rounded-lg appearance-none cursor-pointer accent-primary-600"
                          value={pitchFemale}
                          onChange={(e) => setPitchFemale(Number(e.target.value))}
                        />
                      </div>

                      <div>
                        <div className="flex justify-between text-xs text-gray-600 mb-1">
                          <span>Độ trầm bổng giọng Nam: <strong>{pitchMale}</strong></span>
                          <span className="text-gray-400">Lớn hơn = trầm hơn (Mặc định: 1.15)</span>
                        </div>
                        <input
                          type="range"
                          min={0.8}
                          max={1.8}
                          step={0.05}
                          className="w-full h-2 bg-gray-200 rounded-lg appearance-none cursor-pointer accent-primary-600"
                          value={pitchMale}
                          onChange={(e) => setPitchMale(Number(e.target.value))}
                        />
                      </div>

                      <div>
                        <div className="flex justify-between text-xs text-gray-600 mb-1">
                          <span>Tốc độ nói: <strong>{ttsSpeed}x</strong></span>
                          <span className="text-gray-400">Nhỏ hơn = chậm hơn (Mặc định: 1.0)</span>
                        </div>
                        <input
                          type="range"
                          min={0.5}
                          max={1.5}
                          step={0.05}
                          className="w-full h-2 bg-gray-200 rounded-lg appearance-none cursor-pointer accent-primary-600"
                          value={ttsSpeed}
                          onChange={(e) => setTtsSpeed(Number(e.target.value))}
                        />
                      </div>
                    </>
                  ) : (
                    <div className="text-xs text-gray-400 bg-white p-3 rounded-lg border border-gray-100">
                      Google TTS (Gemini) sử dụng giọng đọc đa người nói tự động dựa trên script (Kore/Puck) và chưa hỗ trợ chỉnh độ trầm bổng/tốc độ nói thủ công. Chọn <strong>Local TTS</strong> để chỉnh các tùy chọn này.
                    </div>
                  )}
                </div>

                {/* Test TTS Console */}
                <div className="border-t md:border-t-0 md:border-l border-gray-200 pt-4 md:pt-0 md:pl-6 space-y-3 flex flex-col justify-between">
                  <div>
                    <h4 className="text-sm font-semibold text-gray-700 mb-2">Thử nghiệm cấu hình giọng AI (Test TTS Console)</h4>
                    <textarea
                      className="input min-h-[70px] text-xs font-mono"
                      value={testText}
                      onChange={(e) => setTestText(e.target.value)}
                      placeholder="Nhập kịch bản để sinh thử giọng..."
                    />
                  </div>
                  
                  <div className="space-y-2">
                    <button
                      type="button"
                      disabled={isTestingTts}
                      onClick={handleTestTts}
                      className="btn-secondary w-full py-1.5 flex items-center justify-center gap-2 text-xs"
                    >
                      {isTestingTts ? 'Đang sinh giọng...' : 'Sinh giọng thử'}
                    </button>

                    {testAudioUrl && (
                      <div className="bg-white p-2 rounded-lg border border-gray-100 flex flex-col gap-1">
                        <span className="text-[10px] text-gray-400 font-semibold">Kết quả thử nghiệm:</span>
                        <audio src={testAudioUrl} controls className="w-full h-8" />
                      </div>
                    )}
                  </div>
                </div>
              </div>

              <div className="text-xs text-gray-500 mt-2">
                Batch = 1 khuyên dùng cho File nghe toàn bộ để có khoảng nghỉ 5s chính xác giữa mỗi câu hỏi.
              </div>
              {listeningJobStatus && (
                <div className="text-xs text-gray-600 mt-1">
                  Trạng thái: {(() => {
                    const state = String(listeningJobStatus.state || '');
                    if (state === 'waiting') return 'Đang chờ';
                    if (state === 'active') return 'Đang xử lý';
                    if (state === 'completed') return 'Hoàn thành';
                    if (state === 'failed') return 'Lỗi';
                    if (state === 'delayed') return 'Đang chờ';
                    if (state === 'paused') return 'Tạm dừng';
                    return state || 'Không rõ';
                  })()}
                  {typeof listeningJobStatus.progress === 'number' ? ` · ${listeningJobStatus.progress}%` : ''}
                </div>
              )}
              {listeningJobStatus?.state === 'failed' && listeningJobStatus.failedReason && (
                <div className="text-xs text-red-600 mt-1">
                  Lỗi: {listeningJobStatus.failedReason}
                </div>
              )}
              {(dirtyExam.listeningAudioUrl !== undefined ? dirtyExam.listeningAudioUrl : exam.listeningAudioUrl) && (
                <div className="mt-2 bg-gray-50 p-2 rounded-lg border border-gray-100 max-w-md">
                  <audio src={String(dirtyExam.listeningAudioUrl !== undefined ? dirtyExam.listeningAudioUrl : exam.listeningAudioUrl)} controls className="w-full h-10" />
                </div>
              )}
            </div>
          )}
        </div>

        <div className="mt-4">
          <button className="btn-primary flex items-center gap-2" onClick={handleSaveExam}>
            <FiSave /> Save Exam
          </button>
        </div>
      </div>

      <div className="flex flex-col md:flex-row md:items-center justify-between gap-4 mb-6 bg-white p-4 rounded-xl shadow-sm border border-gray-100">
        <div className="flex items-center gap-3">
          <div className="p-2.5 bg-primary-50 text-primary-600 rounded-lg">
            <FiImage size={20} />
          </div>
          <div>
            <div className="text-sm font-semibold text-gray-800">Bộ lọc & Tiện ích</div>
            <div className="text-xs text-gray-500">Tìm kiếm nhanh câu hỏi cần bổ sung hình ảnh</div>
          </div>
        </div>

        <div className="flex flex-wrap items-center gap-4">
          <button
            onClick={() => handleToggleAllSections(true)}
            className="text-xs text-gray-500 hover:text-primary-600 font-semibold px-2.5 py-1.5 bg-gray-50 hover:bg-primary-50 rounded-lg transition-all duration-200 border border-gray-100 hover:border-primary-100"
          >
            Thu gọn tất cả
          </button>
          <button
            onClick={() => handleToggleAllSections(false)}
            className="text-xs text-gray-500 hover:text-primary-600 font-semibold px-2.5 py-1.5 bg-gray-50 hover:bg-primary-50 rounded-lg transition-all duration-200 border border-gray-100 hover:border-primary-100 mr-2"
          >
            Mở rộng tất cả
          </button>
          <div className="h-6 w-px bg-gray-200 hidden md:block"></div>
          <label className="relative flex items-center gap-3 cursor-pointer select-none group">
            <div className="relative">
              <input
                type="checkbox"
                checked={filterOnlyWithImage}
                onChange={(e) => setFilterOnlyWithImage(e.target.checked)}
                className="sr-only peer"
              />
              <div className="w-11 h-6 bg-gray-200 peer-focus:outline-none rounded-full peer peer-checked:after:translate-x-full peer-checked:after:border-white after:content-[''] after:absolute after:top-[2px] after:left-[2px] after:bg-white after:border-gray-300 after:border after:rounded-full after:h-5 after:w-5 after:transition-all peer-checked:bg-primary-600"></div>
            </div>
            <span className="text-sm font-medium text-gray-700 group-hover:text-primary-600 transition-colors">
              Chỉ hiển thị câu hỏi có ảnh hoặc mô tả ảnh
            </span>
          </label>
        </div>
      </div>

      <div className="space-y-6">
        {sections.map((s: any) => {
          const filteredQuestions = (Array.isArray(s.questions) ? s.questions : []).filter((q: any) => {
            if (!filterOnlyWithImage) return true;
            return !!(q.imageUrl || q.imagePrompt);
          });

          if (filteredQuestions.length === 0) return null;

          const isCollapsed = !!collapsedSections[s.id];
          const totalCount = Array.isArray(s.questions) ? s.questions.length : 0;

          return (
            <div key={s.id} className="card transition-all duration-200">
              <div
                className="flex items-center justify-between cursor-pointer select-none group"
                onClick={() => setCollapsedSections((prev) => ({ ...prev, [s.id]: !prev[s.id] }))}
              >
                <div>
                  <h3 className="text-base font-semibold text-gray-800 flex items-center gap-2 group-hover:text-primary-600 transition-colors">
                    Section {s.orderIndex}: {s.type}
                  </h3>
                  <div className="text-xs text-gray-500 mt-1">
                    duration={s.durationMinutes ?? '-'} · maxScore={s.maxScore ?? '-'} ·{' '}
                    <span className="font-medium text-gray-700">
                      questions={filteredQuestions.length}
                    </span>
                    {filterOnlyWithImage && ` (filtered from ${totalCount})`}
                  </div>
                </div>
                <div className="flex items-center gap-3">
                  <span className="text-xs text-gray-400 opacity-0 group-hover:opacity-100 transition-opacity">
                    {isCollapsed ? 'Click để mở rộng' : 'Click để thu gọn'}
                  </span>
                  <div className="p-1.5 rounded-lg bg-gray-50 text-gray-500 group-hover:bg-primary-50 group-hover:text-primary-600 transition-all duration-200">
                    {isCollapsed ? <FiChevronDown size={18} /> : <FiChevronUp size={18} />}
                  </div>
                </div>
              </div>

              {!isCollapsed && (
                <div className="mt-6 space-y-4 border-t border-gray-100 pt-4">
                  {filteredQuestions.map((q: any) => {
                    const d = loadQuestionDraft(q.id);
                    if (!d) return null;

                    const setDraft = (patch: Partial<QuestionDraft>) => {
                      setDirtyQuestions((prev) => ({
                        ...prev,
                        [q.id]: {
                          ...(prev[q.id] || questionIndex[q.id]),
                          ...patch,
                        },
                      }));
                    };

                    const isDirty = !!dirtyQuestions[q.id];

                    return (
                      <div key={q.id} className="border border-gray-100 rounded-xl p-4 hover:border-gray-200 transition-colors">
                        <div className="flex items-start justify-between gap-3">
                          <div>
                            <div className="text-sm font-semibold text-gray-800">Q{s.orderIndex}.{q.orderIndex} ({q.questionType})</div>
                            <div className="text-xs text-gray-500 mt-1">{stripHtml(d.contentHtml).slice(0, 160)}</div>
                          </div>
                          <button
                            className="btn-primary flex items-center gap-2"
                            disabled={!isDirty}
                            onClick={() => handleSaveQuestion(q.id)}
                          >
                            <FiSave /> Save
                          </button>
                        </div>

                        <div className="grid grid-cols-1 md:grid-cols-2 gap-4 mt-4">
                          <div>
                            <label className="label">Order</label>
                            <input
                              type="number"
                              className="input"
                              value={d.orderIndex}
                              onChange={(e) => setDraft({ orderIndex: Number(e.target.value) })}
                            />
                          </div>
                          <div>
                            <label className="label">Score Weight</label>
                            <input
                              type="number"
                              className="input"
                              value={d.scoreWeight ?? 1}
                              onChange={(e) => setDraft({ scoreWeight: Number(e.target.value) })}
                            />
                          </div>

                          <div className="md:col-span-2">
                            <label className="label">Content HTML</label>
                            <textarea
                              className="input min-h-[110px] font-mono"
                              value={d.contentHtml}
                              onChange={(e) => setDraft({ contentHtml: e.target.value })}
                            />
                          </div>

                          <div className="md:col-span-2">
                            <label className="label">Listening Script (only for LISTENING / when audioUrl empty)</label>
                            <textarea
                              className="input min-h-[90px] font-mono"
                              value={String(d.listeningScript || '')}
                              onChange={(e) => setDraft({ listeningScript: e.target.value })}
                            />
                          </div>

                          {s.type === 'LISTENING' && (
                            <div className="md:col-span-2">
                              <label className="label">Audio</label>
                              {exam.listeningAudioUrl ? (
                                <div className="text-xs text-amber-600 bg-amber-50 border border-amber-200 p-2.5 rounded-lg">
                                  File nghe riêng lẻ của câu hỏi bị ẩn vì đề thi này đã sử dụng <strong>File nghe toàn bộ (Consolidated Listening Audio)</strong>.
                                </div>
                              ) : (
                                <>
                                  <div className="flex items-center gap-3">
                                    <input
                                      className="input flex-1"
                                      placeholder="Audio URL (auto-filled after upload or AI gen)"
                                      value={String(d.audioUrl || '')}
                                      onChange={(e) => setDraft({ audioUrl: e.target.value })}
                                    />
                                    <label className="btn-secondary flex items-center gap-2 cursor-pointer whitespace-nowrap">
                                      <FiUpload size={14} /> Upload
                                      <input
                                        type="file"
                                        accept="audio/*"
                                        className="hidden"
                                        onChange={async (e) => {
                                          const file = e.target.files?.[0];
                                          if (!file) return;
                                          try {
                                            const res = await uploadApi.uploadAudio(file);
                                            const url = res.data?.url;
                                            if (url) {
                                              setDraft({ audioUrl: url });
                                              toast.success('Audio uploaded!');
                                            }
                                          } catch (err: any) {
                                            toast.error('Upload failed: ' + (err.message || err));
                                          }
                                          e.target.value = '';
                                        }}
                                      />
                                    </label>
                                    <button
                                      type="button"
                                      disabled={isGeneratingAudio === q.id || !d.listeningScript?.trim()}
                                      onClick={() => handleGenerateAudio(q.id)}
                                      className="btn-primary flex items-center gap-2 whitespace-nowrap disabled:opacity-50"
                                    >
                                      {isGeneratingAudio === q.id ? 'Generating...' : 'AI Gen'}
                                    </button>
                                  </div>
                                  {d.audioUrl && (
                                    <div className="mt-2">
                                      <audio src={d.audioUrl} controls className="w-full max-w-md h-10" />
                                    </div>
                                  )}
                                </>
                              )}
                            </div>
                          )}

                          {d.questionType !== 'MCQ' && (
                            <div className="md:col-span-2">
                              <label className="label">Correct Text Answer</label>
                              <input
                                className="input"
                                value={String(d.correctTextAnswer || '')}
                                onChange={(e) => setDraft({ correctTextAnswer: e.target.value })}
                              />
                            </div>
                          )}

                          <div className="md:col-span-2">
                            <label className="label">Explanation</label>
                            <textarea
                              className="input min-h-[80px]"
                              value={String(d.explanation || '')}
                              onChange={(e) => setDraft({ explanation: e.target.value })}
                            />
                          </div>

                          <div className="md:col-span-2">
                            <div className="flex items-center gap-2 mb-1">
                              <label className="label mb-0">Image Prompt</label>
                              {d.imagePrompt && (
                                <button
                                  type="button"
                                  className="text-xs flex items-center gap-1 text-primary-600 hover:text-primary-800 font-medium"
                                  onClick={() => {
                                    navigator.clipboard.writeText(d.imagePrompt || '');
                                    toast.success('Copied image prompt!');
                                  }}
                                >
                                  <FiCopy size={12} /> Copy
                                </button>
                              )}
                            </div>
                            <textarea
                              className="input min-h-[70px] font-mono text-sm"
                              placeholder="Mô tả hình ảnh/biểu đồ cho câu hỏi (nếu có)..."
                              value={String(d.imagePrompt || '')}
                              onChange={(e) => setDraft({ imagePrompt: e.target.value })}
                            />
                          </div>

                          <div className="md:col-span-2">
                            <label className="label">Image</label>
                            <div className="flex items-center gap-3">
                              <input
                                className="input flex-1"
                                placeholder="Image URL (auto-filled after upload)"
                                value={String(d.imageUrl || '')}
                                onChange={(e) => setDraft({ imageUrl: e.target.value })}
                              />
                              <label className="btn-secondary flex items-center gap-2 cursor-pointer whitespace-nowrap">
                                <FiUpload size={14} /> Upload
                                <input
                                  type="file"
                                  accept="image/*"
                                  className="hidden"
                                  onChange={async (e) => {
                                    const file = e.target.files?.[0];
                                    if (!file) return;
                                    try {
                                      const res = await uploadApi.uploadImage(file);
                                      const url = res.data?.url;
                                      if (url) {
                                        setDraft({ imageUrl: url });
                                        toast.success('Image uploaded!');
                                      }
                                    } catch (err: any) {
                                      toast.error('Upload failed: ' + (err.message || err));
                                    }
                                    e.target.value = '';
                                  }}
                                />
                              </label>
                            </div>
                            {d.imageUrl && (
                              <div className="mt-2 rounded-lg overflow-hidden border border-gray-200 inline-block">
                                <img
                                  src={d.imageUrl.startsWith('/') ? d.imageUrl : d.imageUrl}
                                  alt="Question image"
                                  className="max-h-[200px] object-contain"
                                  onError={(e) => { (e.target as HTMLImageElement).style.display = 'none'; }}
                                />
                              </div>
                            )}
                          </div>
                        </div>

                        {d.questionType === 'MCQ' && (
                          <div className="mt-4">
                            <div className="text-sm font-semibold text-gray-800 mb-2">Choices</div>
                            <div className="space-y-2">
                              {(d.choices || []).map((c, idx) => (
                                <div key={idx} className="flex items-center gap-2">
                                  <input
                                    type="number"
                                    className="input w-20"
                                    value={c.orderIndex}
                                    onChange={(e) => {
                                      const next = [...(d.choices || [])];
                                      next[idx] = { ...next[idx], orderIndex: Number(e.target.value) };
                                      setDraft({ choices: next });
                                    }}
                                  />
                                  <input
                                    className="input flex-1"
                                    value={c.content}
                                    onChange={(e) => {
                                      const next = [...(d.choices || [])];
                                      next[idx] = { ...next[idx], content: e.target.value };
                                      setDraft({ choices: next });
                                    }}
                                  />
                                  <label className="text-xs text-gray-600 flex items-center gap-2">
                                    <input
                                      type="checkbox"
                                      checked={c.isCorrect}
                                      onChange={(e) => {
                                        const next = [...(d.choices || [])].map((x, i) => ({ ...x, isCorrect: i === idx ? e.target.checked : false }));
                                        setDraft({ choices: next });
                                      }}
                                    />
                                    Correct
                                  </label>
                                </div>
                              ))}
                            </div>
                            {(!d.choices || d.choices.length === 0) && (
                              <div className="text-xs text-gray-400">No choices</div>
                            )}
                          </div>
                        )}
                      </div>
                    );
                  })}
                </div>
              )}
            </div>
          );
        })}
      </div>
    </div>
  );
}

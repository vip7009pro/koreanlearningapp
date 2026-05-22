import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query';
import { useMemo, useState } from 'react';
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

  const handleGenerateConsolidatedAudio = async () => {
    if (!examId) return;
    setIsGeneratingConsolidatedAudio(true);
    try {
      const res = await topikAdminApi.generateExamListeningAudio(examId);
      const url = res.data?.listeningAudioUrl;
      if (url) {
        toast.success('Đã tạo file nghe AI toàn bộ thành công!');
        qc.invalidateQueries({ queryKey: ['topik-exam', examId] });
      }
    } catch (err: any) {
      toast.error('Tạo file nghe AI thất bại: ' + (err.response?.data?.message || err.message));
    } finally {
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
      const res = await topikAdminApi.generateQuestionAudio(qid);
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
              <div className="flex items-center gap-3">
                <input
                  className="input flex-1"
                  placeholder="Đường dẫn file nghe (tự động điền sau khi tạo hoặc tải lên)"
                  value={String(dirtyExam.listeningAudioUrl !== undefined ? dirtyExam.listeningAudioUrl : (exam.listeningAudioUrl || ''))}
                  onChange={(e) => setDirtyExam((p) => ({ ...p, listeningAudioUrl: e.target.value }))}
                />
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
                  disabled={isGeneratingConsolidatedAudio}
                  onClick={handleGenerateConsolidatedAudio}
                  className="btn-primary flex items-center gap-2 whitespace-nowrap disabled:opacity-50"
                >
                  {isGeneratingConsolidatedAudio ? 'Đang tạo...' : 'Tạo file nghe AI toàn bộ'}
                </button>
              </div>
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

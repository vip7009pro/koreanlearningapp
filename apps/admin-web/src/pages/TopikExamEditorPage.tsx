import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query';
import { useMemo, useState } from 'react';
import { useNavigate, useParams } from 'react-router-dom';
import toast from 'react-hot-toast';
import { FiArrowLeft, FiSave, FiTrash2, FiEye, FiEyeOff } from 'react-icons/fi';
import { topikAdminApi } from '../lib/api';

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
  choices?: ChoiceDraft[];
};

export default function TopikExamEditorPage() {
  const { examId } = useParams();
  const navigate = useNavigate();
  const qc = useQueryClient();

  const [dirtyExam, setDirtyExam] = useState<Record<string, unknown>>({});
  const [dirtyQuestions, setDirtyQuestions] = useState<Record<string, QuestionDraft>>({});

  const { data, isLoading } = useQuery({
    queryKey: ['topik-exam', examId],
    enabled: !!examId,
    queryFn: () => topikAdminApi.getExam(examId as string).then((r) => r.data),
  });

  const exam = data?.exam;
  const sections = Array.isArray(exam?.sections) ? exam.sections : [];

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
        </div>

        <div className="mt-4">
          <button className="btn-primary flex items-center gap-2" onClick={handleSaveExam}>
            <FiSave /> Save Exam
          </button>
        </div>
      </div>

      <div className="space-y-6">
        {sections.map((s: any) => (
          <div key={s.id} className="card">
            <div className="flex items-center justify-between">
              <div>
                <h3 className="text-base font-semibold text-gray-800">Section {s.orderIndex}: {s.type}</h3>
                <div className="text-xs text-gray-500">
                  duration={s.durationMinutes ?? '-'} · maxScore={s.maxScore ?? '-'} · questions={Array.isArray(s.questions) ? s.questions.length : 0}
                </div>
              </div>
            </div>

            <div className="mt-4 space-y-4">
              {(Array.isArray(s.questions) ? s.questions : []).map((q: any) => {
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
                  <div key={q.id} className="border border-gray-100 rounded-xl p-4">
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
          </div>
        ))}
      </div>
    </div>
  );
}

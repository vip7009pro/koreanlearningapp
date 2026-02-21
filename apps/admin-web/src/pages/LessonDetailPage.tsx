import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query';
import { useParams, useNavigate } from 'react-router-dom';
import { lessonsApi, vocabularyApi, grammarApi, dialoguesApi, quizzesApi, aiAdminApi } from '../lib/api';
import { useState } from 'react';
import toast from 'react-hot-toast';
import { FiPlus, FiTrash2, FiArrowLeft, FiUpload, FiEdit2 } from 'react-icons/fi';
import { useAuthStore } from '../stores/authStore';

export default function LessonDetailPage() {
  const { lessonId } = useParams<{ lessonId: string }>();
  const navigate = useNavigate();
  const queryClient = useQueryClient();
  const role = useAuthStore((s) => s.user?.role);
  const [activeTab, setActiveTab] = useState<'vocab' | 'grammar' | 'dialogue' | 'quiz'>('vocab');
  const [vocabForm, setVocabForm] = useState({ korean: '', vietnamese: '', pronunciation: '', difficulty: 'EASY', exampleSentence: '', exampleMeaning: '' });
  const [grammarForm, setGrammarForm] = useState({ pattern: '', explanationVN: '', example: '' });
  const [dialogueForm, setDialogueForm] = useState({ speaker: '', koreanText: '', vietnameseText: '', orderIndex: 0 });
  const [quizForm, setQuizForm] = useState({ title: '', quizType: 'MULTIPLE_CHOICE' });
  const [expandedQuizId, setExpandedQuizId] = useState<string | null>(null);
  const [questionForm, setQuestionForm] = useState({
    quizId: '',
    questionType: 'MULTIPLE_CHOICE',
    questionText: '',
    correctAnswer: '',
    optionA: '',
    optionB: '',
    optionC: '',
    optionD: '',
    correctOptionIndex: 0,
  });
  const [showForm, setShowForm] = useState(false);
  const [showImport, setShowImport] = useState(false);
  const [importJson, setImportJson] = useState('');
  const [importing, setImporting] = useState(false);
  const [aiGenLoading, setAiGenLoading] = useState(false);
  const [aiModel, setAiModel] = useState<string>(() => localStorage.getItem('admin_ai_model') || 'google/gemini-2.0-flash-001');

  const [selectedVocabIds, setSelectedVocabIds] = useState<string[]>([]);
  const [selectedGrammarIds, setSelectedGrammarIds] = useState<string[]>([]);
  const [selectedDialogueIds, setSelectedDialogueIds] = useState<string[]>([]);
  const [selectedQuizIds, setSelectedQuizIds] = useState<string[]>([]);

  const updateAiModel = (model: string) => {
    setAiModel(model);
    localStorage.setItem('admin_ai_model', model);
  };

  const clearSelectionForTab = (tab: typeof activeTab) => {
    if (tab === 'vocab') setSelectedVocabIds([]);
    if (tab === 'grammar') setSelectedGrammarIds([]);
    if (tab === 'dialogue') setSelectedDialogueIds([]);
    if (tab === 'quiz') setSelectedQuizIds([]);
  };

  const askCount = async (label: string, defaultValue: number) => {
    const input = window.prompt(`AI gen ${label} - nhập số lượng`, String(defaultValue));
    if (!input) return null;
    const v = Number(input);
    if (!Number.isFinite(v) || v <= 0) return null;
    return Math.floor(v);
  };

  const handleAiGen = async () => {
    if (!lessonId) return;
    if (aiGenLoading) return;
    setAiGenLoading(true);
    const toastId = toast.loading('AI đang tạo nội dung...');
    try {
      if (activeTab === 'vocab') {
        const count = await askCount('Vocabulary', 10);
        if (!count) return;
        await aiAdminApi.generateVocabulary(lessonId, count, role === 'ADMIN' ? aiModel : undefined);
      } else if (activeTab === 'grammar') {
        const count = await askCount('Grammar', 5);
        if (!count) return;
        await aiAdminApi.generateGrammar(lessonId, count, role === 'ADMIN' ? aiModel : undefined);
      } else if (activeTab === 'dialogue') {
        const count = await askCount('Dialogues', 10);
        if (!count) return;
        await aiAdminApi.generateDialogues(lessonId, count, role === 'ADMIN' ? aiModel : undefined);
      } else {
        const count = await askCount('Quizzes', 1);
        if (!count) return;
        await aiAdminApi.generateQuizzes(lessonId, count, role === 'ADMIN' ? aiModel : undefined);
      }

      toast.success('AI generated & inserted!', { id: toastId });
      invalidateAll();
    } catch (e: any) {
      toast.error('AI gen failed: ' + (e?.response?.data?.message || e.message), { id: toastId });
    } finally {
      toast.dismiss(toastId);
      setAiGenLoading(false);
    }
  };

  const { data: lesson } = useQuery({
    queryKey: ['lesson', lessonId],
    queryFn: () => lessonsApi.getOne(lessonId!).then((r) => r.data),
    enabled: !!lessonId,
  });

  const { data: vocab } = useQuery({
    queryKey: ['vocab', lessonId],
    queryFn: () => vocabularyApi.getByLesson(lessonId!).then((r) => r.data.data),
    enabled: !!lessonId,
  });

  const { data: grammars } = useQuery({
    queryKey: ['grammar', lessonId],
    queryFn: () => grammarApi.getByLesson(lessonId!).then((r) => r.data),
    enabled: !!lessonId,
  });

  const { data: dialogues } = useQuery({
    queryKey: ['dialogues', lessonId],
    queryFn: () => dialoguesApi.getByLesson(lessonId!).then((r) => r.data),
    enabled: !!lessonId,
  });

  const { data: quizzes } = useQuery({
    queryKey: ['quizzes', lessonId],
    queryFn: () => quizzesApi.getByLesson(lessonId!).then((r) => r.data),
    enabled: !!lessonId,
  });

  const invalidateAll = () => {
    queryClient.invalidateQueries({ queryKey: ['vocab', lessonId] });
    queryClient.invalidateQueries({ queryKey: ['grammar', lessonId] });
    queryClient.invalidateQueries({ queryKey: ['dialogues', lessonId] });
    queryClient.invalidateQueries({ queryKey: ['quizzes', lessonId] });
  };

  const createVocab = useMutation({
    mutationFn: (data: typeof vocabForm) => vocabularyApi.create({ ...data, lessonId }),
    onSuccess: () => { invalidateAll(); toast.success('Vocabulary added'); setShowForm(false); },
  });

  const deleteVocab = useMutation({
    mutationFn: (id: string) => vocabularyApi.delete(id),
    onSuccess: () => { invalidateAll(); toast.success('Deleted'); },
  });

  const createGrammar = useMutation({
    mutationFn: (data: typeof grammarForm) => grammarApi.create({ ...data, lessonId }),
    onSuccess: () => { invalidateAll(); toast.success('Grammar added'); setShowForm(false); },
  });

  const deleteGrammar = useMutation({
    mutationFn: (id: string) => grammarApi.delete(id),
    onSuccess: () => { invalidateAll(); toast.success('Deleted'); },
  });

  const createDialogue = useMutation({
    mutationFn: (data: typeof dialogueForm) => dialoguesApi.create({ ...data, lessonId }),
    onSuccess: () => { invalidateAll(); toast.success('Dialogue added'); setShowForm(false); },
  });

  const deleteDialogue = useMutation({
    mutationFn: (id: string) => dialoguesApi.delete(id),
    onSuccess: () => { invalidateAll(); toast.success('Deleted'); },
  });

  const createQuiz = useMutation({
    mutationFn: (data: typeof quizForm) => quizzesApi.create({ ...data, lessonId }),
    onSuccess: () => {
      invalidateAll();
      toast.success('Quiz added');
      setShowForm(false);
      setQuizForm({ title: '', quizType: 'MULTIPLE_CHOICE' });
    },
  });

  const updateQuiz = useMutation({
    mutationFn: ({ id, data }: { id: string; data: Partial<typeof quizForm> }) => quizzesApi.update(id, data as any),
    onSuccess: () => {
      invalidateAll();
      toast.success('Quiz updated');
    },
  });

  const deleteQuiz = useMutation({
    mutationFn: (id: string) => quizzesApi.delete(id),
    onSuccess: () => {
      invalidateAll();
      toast.success('Deleted');
    },
  });

  const createQuizQuestion = useMutation({
    mutationFn: (data: any) => quizzesApi.createQuestion(data),
    onSuccess: () => {
      invalidateAll();
      toast.success('Question added');
      setQuestionForm({
        quizId: questionForm.quizId,
        questionType: 'MULTIPLE_CHOICE',
        questionText: '',
        correctAnswer: '',
        optionA: '',
        optionB: '',
        optionC: '',
        optionD: '',
        correctOptionIndex: 0,
      });
    },
  });

  const updateQuizQuestion = useMutation({
    mutationFn: ({ id, data }: { id: string; data: any }) => quizzesApi.updateQuestion(id, data),
    onSuccess: () => {
      invalidateAll();
      toast.success('Question updated');
    },
  });

  const deleteQuizQuestion = useMutation({
    mutationFn: (id: string) => quizzesApi.deleteQuestion(id),
    onSuccess: () => {
      invalidateAll();
      toast.success('Deleted');
    },
  });

  const bulkDeleteVocab = useMutation({
    mutationFn: (ids: string[]) => vocabularyApi.bulkDelete(ids),
    onSuccess: (r: any) => {
      invalidateAll();
      setSelectedVocabIds([]);
      toast.success(`Deleted ${(r?.data?.deleted ?? 0) as number} items`);
    },
  });
  const bulkDeleteGrammar = useMutation({
    mutationFn: (ids: string[]) => grammarApi.bulkDelete(ids),
    onSuccess: (r: any) => {
      invalidateAll();
      setSelectedGrammarIds([]);
      toast.success(`Deleted ${(r?.data?.deleted ?? 0) as number} items`);
    },
  });
  const bulkDeleteDialogues = useMutation({
    mutationFn: (ids: string[]) => dialoguesApi.bulkDelete(ids),
    onSuccess: (r: any) => {
      invalidateAll();
      setSelectedDialogueIds([]);
      toast.success(`Deleted ${(r?.data?.deleted ?? 0) as number} items`);
    },
  });
  const bulkDeleteQuizzes = useMutation({
    mutationFn: (ids: string[]) => quizzesApi.bulkDelete(ids),
    onSuccess: (r: any) => {
      invalidateAll();
      setSelectedQuizIds([]);
      toast.success(`Deleted ${(r?.data?.deleted ?? 0) as number} items`);
    },
  });

  // --- Bulk Import Handler ---
  const handleBulkImport = async () => {
    if (!importJson.trim() || !lessonId) return;
    setImporting(true);
    try {
      const items = JSON.parse(importJson);
      if (!Array.isArray(items)) { toast.error('JSON phải là một mảng []'); setImporting(false); return; }

      let count = 0;
      if (activeTab === 'vocab') {
        await vocabularyApi.createBulk(items.map((v: any) => ({ ...v, lessonId })));
        count = items.length;
      } else if (activeTab === 'grammar') {
        for (const g of items) {
          await grammarApi.create({ ...g, lessonId });
          count++;
        }
      } else if (activeTab === 'dialogue') {
        for (const d of items) {
          await dialoguesApi.create({ ...d, lessonId });
          count++;
        }
      } else if (activeTab === 'quiz') {
        for (const q of items) {
          const quizRes = await quizzesApi.create({ title: q.title, quizType: q.quizType || 'MULTIPLE_CHOICE', lessonId });
          const quizId = quizRes.data?.id;
          if (quizId && q.questions) {
            for (const qu of q.questions) {
              await quizzesApi.createQuestion({ ...qu, quizId });
            }
          }
          count++;
        }
      }
      toast.success(`Imported ${count} items!`);
      invalidateAll();
      setShowImport(false);
      setImportJson('');
    } catch (e: any) {
      toast.error('Import failed: ' + (e?.response?.data?.message || e.message));
    } finally {
      setImporting(false);
    }
  };

  const tabs = [
    { id: 'vocab' as const, label: 'Vocabulary', count: (vocab as unknown[])?.length || 0 },
    { id: 'grammar' as const, label: 'Grammar', count: (grammars as unknown[])?.length || 0 },
    { id: 'dialogue' as const, label: 'Dialogues', count: (dialogues as unknown[])?.length || 0 },
    { id: 'quiz' as const, label: 'Quizzes', count: (quizzes as unknown[])?.length || 0 },
  ];

  return (
    <div>
      <button onClick={() => navigate(-1)} className="flex items-center gap-1 text-gray-500 hover:text-gray-700 mb-4 text-sm">
        <FiArrowLeft /> Back
      </button>

      <div className="flex justify-between items-start mb-6">
        <div>
          <h1 className="text-2xl font-bold text-gray-800">{lesson?.title}</h1>
          <p className="text-gray-500 mt-1">{lesson?.description}</p>
        </div>
      <div className="flex gap-2">
        {role === 'ADMIN' && (
          <select
            className="input"
            value={aiModel}
            onChange={(e) => updateAiModel(e.target.value)}
            disabled={aiGenLoading}
            title="AI model"
          >
            <option value="google/gemini-2.0-flash-001">gemini-2.0-flash-001</option>
            <option value="meta-llama/llama-3.3-70b-instruct:free">llama-3.3-70b-instruct:free</option>
            <option value="openai/gpt-4o-mini">gpt-4o-mini</option>
            <option value="anthropic/claude-3.5-haiku">claude-3.5-haiku</option>
            <option value="meta-llama/llama-3.1-70b-instruct">llama-3.1-70b</option>
          </select>
        )}
        <button onClick={() => { setShowImport(!showImport); setShowForm(false); }} className="btn-secondary flex items-center gap-2">
          <FiUpload /> Import JSON
        </button>
        <button onClick={handleAiGen} disabled={aiGenLoading} className="btn-secondary flex items-center gap-2">
          {aiGenLoading ? '✨ AI gen...' : '✨ AI gen'}
        </button>
        <button onClick={() => { setShowForm(!showForm); setShowImport(false); }} className="btn-primary flex items-center gap-2">
          <FiPlus /> Add {activeTab === 'vocab' ? 'Vocabulary' : activeTab === 'grammar' ? 'Grammar' : activeTab === 'dialogue' ? 'Dialogue' : 'Quiz'}
        </button>
      </div>
      </div>

      {/* Tabs */}
      <div className="flex gap-1 mb-6 bg-gray-100 rounded-lg p-1">
        {tabs.map((tab) => (
          <button
            key={tab.id}
            onClick={() => { clearSelectionForTab(activeTab); setActiveTab(tab.id); setShowForm(false); }}
            className={`flex-1 px-4 py-2 rounded-lg text-sm font-medium transition-colors ${activeTab === tab.id ? 'bg-white shadow text-primary-600' : 'text-gray-600 hover:text-gray-800'}`}
          >
            {tab.label} ({tab.count})
          </button>
        ))}
      </div>

      {/* Import JSON Modal */}
      {showImport && (
        <div className="card mb-6">
          <h3 className="font-semibold mb-2">Import {activeTab === 'vocab' ? 'Vocabulary' : activeTab === 'grammar' ? 'Grammar' : activeTab === 'dialogue' ? 'Dialogues' : 'Quizzes'} from JSON</h3>
          <p className="text-xs text-gray-500 mb-3">Paste a JSON array. See sample files in the project root folder.</p>
          <textarea
            className="input w-full font-mono text-xs"
            rows={10}
            placeholder='[{"korean": "안녕하세요", "vietnamese": "Xin chào", ...}]'
            value={importJson}
            onChange={(e) => setImportJson(e.target.value)}
          />
          <div className="flex gap-2 mt-3">
            <button onClick={handleBulkImport} disabled={importing} className="btn-primary">
              {importing ? 'Importing...' : 'Start Import'}
            </button>
            <button onClick={() => { setShowImport(false); setImportJson(''); }} className="btn-secondary">Cancel</button>
          </div>
        </div>
      )}

      {/* Forms */}
      {showForm && activeTab === 'vocab' && (
        <form onSubmit={(e) => { e.preventDefault(); createVocab.mutate(vocabForm); }} className="card mb-6 grid grid-cols-2 md:grid-cols-3 gap-3">
          <div><label className="label">Korean</label><input className="input" value={vocabForm.korean} onChange={(e) => setVocabForm({ ...vocabForm, korean: e.target.value })} required /></div>
          <div><label className="label">Vietnamese</label><input className="input" value={vocabForm.vietnamese} onChange={(e) => setVocabForm({ ...vocabForm, vietnamese: e.target.value })} required /></div>
          <div><label className="label">Pronunciation</label><input className="input" value={vocabForm.pronunciation} onChange={(e) => setVocabForm({ ...vocabForm, pronunciation: e.target.value })} required /></div>
          <div><label className="label">Difficulty</label><select className="input" value={vocabForm.difficulty} onChange={(e) => setVocabForm({ ...vocabForm, difficulty: e.target.value })}><option>EASY</option><option>MEDIUM</option><option>HARD</option></select></div>
          <div><label className="label">Example</label><input className="input" value={vocabForm.exampleSentence} onChange={(e) => setVocabForm({ ...vocabForm, exampleSentence: e.target.value })} /></div>
          <div><label className="label">Meaning</label><input className="input" value={vocabForm.exampleMeaning} onChange={(e) => setVocabForm({ ...vocabForm, exampleMeaning: e.target.value })} /></div>
          <div className="col-span-full flex gap-2"><button type="submit" className="btn-primary">Create</button><button type="button" className="btn-secondary" onClick={() => setShowForm(false)}>Cancel</button></div>
        </form>
      )}

      {showForm && activeTab === 'grammar' && (
        <form onSubmit={(e) => { e.preventDefault(); createGrammar.mutate(grammarForm); }} className="card mb-6 grid grid-cols-1 md:grid-cols-3 gap-3">
          <div><label className="label">Pattern</label><input className="input" value={grammarForm.pattern} onChange={(e) => setGrammarForm({ ...grammarForm, pattern: e.target.value })} required /></div>
          <div><label className="label">Explanation (VN)</label><input className="input" value={grammarForm.explanationVN} onChange={(e) => setGrammarForm({ ...grammarForm, explanationVN: e.target.value })} required /></div>
          <div><label className="label">Example</label><input className="input" value={grammarForm.example} onChange={(e) => setGrammarForm({ ...grammarForm, example: e.target.value })} /></div>
          <div className="col-span-full flex gap-2"><button type="submit" className="btn-primary">Create</button><button type="button" className="btn-secondary" onClick={() => setShowForm(false)}>Cancel</button></div>
        </form>
      )}

      {showForm && activeTab === 'dialogue' && (
        <form onSubmit={(e) => { e.preventDefault(); createDialogue.mutate(dialogueForm); }} className="card mb-6 grid grid-cols-1 md:grid-cols-4 gap-3">
          <div><label className="label">Speaker</label><input className="input" value={dialogueForm.speaker} onChange={(e) => setDialogueForm({ ...dialogueForm, speaker: e.target.value })} required /></div>
          <div><label className="label">Korean Text</label><input className="input" value={dialogueForm.koreanText} onChange={(e) => setDialogueForm({ ...dialogueForm, koreanText: e.target.value })} required /></div>
          <div><label className="label">Vietnamese</label><input className="input" value={dialogueForm.vietnameseText} onChange={(e) => setDialogueForm({ ...dialogueForm, vietnameseText: e.target.value })} required /></div>
          <div><label className="label">Order</label><input type="number" className="input" value={dialogueForm.orderIndex} onChange={(e) => setDialogueForm({ ...dialogueForm, orderIndex: +e.target.value })} /></div>
          <div className="col-span-full flex gap-2"><button type="submit" className="btn-primary">Create</button><button type="button" className="btn-secondary" onClick={() => setShowForm(false)}>Cancel</button></div>
        </form>
      )}

      {showForm && activeTab === 'quiz' && (
        <form
          onSubmit={(e) => {
            e.preventDefault();
            if (role !== 'ADMIN') {
              toast.error('Chỉ admin mới có quyền tạo quiz');
              return;
            }
            createQuiz.mutate(quizForm);
          }}
          className="card mb-6 grid grid-cols-1 md:grid-cols-3 gap-3"
        >
          <div>
            <label className="label">Title</label>
            <input
              className="input"
              value={quizForm.title}
              onChange={(e) => setQuizForm({ ...quizForm, title: e.target.value })}
              required
            />
          </div>
          <div>
            <label className="label">Quiz type</label>
            <select
              className="input"
              value={quizForm.quizType}
              onChange={(e) => setQuizForm({ ...quizForm, quizType: e.target.value })}
            >
              <option value="MULTIPLE_CHOICE">MULTIPLE_CHOICE</option>
              <option value="FILL_IN_BLANK">FILL_IN_BLANK</option>
              <option value="LISTENING">LISTENING</option>
            </select>
          </div>
          <div className="col-span-full flex gap-2">
            <button type="submit" className="btn-primary" disabled={createQuiz.isPending}>
              {createQuiz.isPending ? 'Creating...' : 'Create'}
            </button>
            <button type="button" className="btn-secondary" onClick={() => setShowForm(false)}>
              Cancel
            </button>
          </div>
        </form>
      )}

      {/* Content Tables */}
      {activeTab === 'vocab' && (
        <div className="card overflow-hidden p-0">
          {selectedVocabIds.length > 0 && (
            <div className="p-3 flex justify-between items-center bg-gray-50 border-b">
              <div className="text-sm text-gray-600">Selected: {selectedVocabIds.length}</div>
              <button
                className="btn-secondary flex items-center gap-2"
                onClick={() => {
                  if (!confirm(`Delete ${selectedVocabIds.length} selected items?`)) return;
                  bulkDeleteVocab.mutate(selectedVocabIds);
                }}
                disabled={bulkDeleteVocab.isPending}
              >
                <FiTrash2 /> Delete selected
              </button>
            </div>
          )}
          <table className="w-full">
            <thead className="bg-gray-50"><tr>
              <th className="table-header w-10">#</th>
              <th className="table-header w-10">
                <input
                  type="checkbox"
                  checked={selectedVocabIds.length > 0 && selectedVocabIds.length === ((vocab as any[])?.length || 0)}
                  onChange={(e) => {
                    if (e.target.checked) setSelectedVocabIds(((vocab as any[]) || []).map((x) => x.id as string));
                    else setSelectedVocabIds([]);
                  }}
                />
              </th>
              <th className="table-header">Korean</th><th className="table-header">Vietnamese</th><th className="table-header">Pronunciation</th><th className="table-header">Difficulty</th><th className="table-header">Example</th><th className="table-header w-16"></th>
            </tr></thead>
            <tbody className="divide-y divide-gray-100">
              {(vocab as Record<string, unknown>[])?.map((v, idx) => (
                <tr key={v.id as string} className="hover:bg-gray-50">
                  <td className="table-cell text-xs text-gray-400">{idx + 1}</td>
                  <td className="table-cell">
                    <input
                      type="checkbox"
                      checked={selectedVocabIds.includes(v.id as string)}
                      onChange={(e) => {
                        const id = v.id as string;
                        if (e.target.checked) setSelectedVocabIds((prev) => Array.from(new Set([...prev, id])));
                        else setSelectedVocabIds((prev) => prev.filter((x) => x !== id));
                      }}
                    />
                  </td>
                  <td className="table-cell font-medium text-lg">{v.korean as string}</td>
                  <td className="table-cell">{v.vietnamese as string}</td>
                  <td className="table-cell text-gray-500 text-xs">{v.pronunciation as string}</td>
                  <td className="table-cell"><span className={`badge ${v.difficulty === 'EASY' ? 'badge-green' : v.difficulty === 'MEDIUM' ? 'badge-yellow' : 'badge-red'}`}>{v.difficulty as string}</span></td>
                  <td className="table-cell text-xs text-gray-500">{v.exampleSentence as string}</td>
                  <td className="table-cell"><button onClick={() => { if (confirm('Delete?')) deleteVocab.mutate(v.id as string); }} className="text-gray-400 hover:text-red-500"><FiTrash2 size={14} /></button></td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      )}

      {activeTab === 'grammar' && (
        <div className="space-y-3">
          {selectedGrammarIds.length > 0 && (
            <div className="card flex justify-between items-center">
              <div className="text-sm text-gray-600">Selected: {selectedGrammarIds.length}</div>
              <button
                className="btn-secondary flex items-center gap-2"
                onClick={() => {
                  if (!confirm(`Delete ${selectedGrammarIds.length} selected items?`)) return;
                  bulkDeleteGrammar.mutate(selectedGrammarIds);
                }}
                disabled={bulkDeleteGrammar.isPending}
              >
                <FiTrash2 /> Delete selected
              </button>
            </div>
          )}
          {(grammars as Record<string, unknown>[])?.map((g, idx) => (
            <div key={g.id as string} className="card flex justify-between items-start">
              <div className="flex items-start gap-3">
                <div className="text-xs text-gray-400 pt-1 w-6">{idx + 1}</div>
                <input
                  className="mt-1"
                  type="checkbox"
                  checked={selectedGrammarIds.includes(g.id as string)}
                  onChange={(e) => {
                    const id = g.id as string;
                    if (e.target.checked) setSelectedGrammarIds((prev) => Array.from(new Set([...prev, id])));
                    else setSelectedGrammarIds((prev) => prev.filter((x) => x !== id));
                  }}
                />
                <div>
                <h3 className="font-semibold text-primary-600 text-lg">{g.pattern as string}</h3>
                <p className="text-sm text-gray-700 mt-1">{g.explanationVN as string}</p>
                {(g.example as string) && <p className="text-sm text-gray-500 mt-1 italic">{g.example as string}</p>}
              </div>
              </div>
              <button onClick={() => { if (confirm('Delete?')) deleteGrammar.mutate(g.id as string); }} className="text-gray-400 hover:text-red-500"><FiTrash2 size={14} /></button>
            </div>
          ))}
        </div>
      )}

      {activeTab === 'dialogue' && (
        <div className="card">
          {selectedDialogueIds.length > 0 && (
            <div className="pb-3 flex justify-between items-center">
              <div className="text-sm text-gray-600">Selected: {selectedDialogueIds.length}</div>
              <button
                className="btn-secondary flex items-center gap-2"
                onClick={() => {
                  if (!confirm(`Delete ${selectedDialogueIds.length} selected items?`)) return;
                  bulkDeleteDialogues.mutate(selectedDialogueIds);
                }}
                disabled={bulkDeleteDialogues.isPending}
              >
                <FiTrash2 /> Delete selected
              </button>
            </div>
          )}
          <div className="space-y-3">
            {(dialogues as Record<string, unknown>[])?.map((d) => (
              <div key={d.id as string} className="flex items-start gap-3 p-3 rounded-lg bg-gray-50 group">
                <input
                  className="mt-1"
                  type="checkbox"
                  checked={selectedDialogueIds.includes(d.id as string)}
                  onChange={(e) => {
                    const id = d.id as string;
                    if (e.target.checked) setSelectedDialogueIds((prev) => Array.from(new Set([...prev, id])));
                    else setSelectedDialogueIds((prev) => prev.filter((x) => x !== id));
                  }}
                />
                <div className="w-10 h-10 rounded-full bg-primary-100 flex items-center justify-center text-primary-600 font-bold text-xs flex-shrink-0">
                  {(d.speaker as string)?.charAt(0)}
                </div>
                <div className="flex-1">
                  <p className="text-xs font-medium text-gray-500">{d.speaker as string}</p>
                  <p className="text-sm font-medium mt-0.5">{d.koreanText as string}</p>
                  <p className="text-xs text-gray-500">{d.vietnameseText as string}</p>
                </div>
                <button onClick={() => { if (confirm('Delete?')) deleteDialogue.mutate(d.id as string); }} className="text-gray-400 hover:text-red-500 opacity-0 group-hover:opacity-100"><FiTrash2 size={14} /></button>
              </div>
            ))}
          </div>
        </div>
      )}

      {activeTab === 'quiz' && (
        <div className="space-y-3">
          {selectedQuizIds.length > 0 && (
            <div className="card flex justify-between items-center">
              <div className="text-sm text-gray-600">Selected: {selectedQuizIds.length}</div>
              <button
                className="btn-secondary flex items-center gap-2"
                onClick={() => {
                  if (!confirm(`Delete ${selectedQuizIds.length} selected items?`)) return;
                  bulkDeleteQuizzes.mutate(selectedQuizIds);
                }}
                disabled={bulkDeleteQuizzes.isPending}
              >
                <FiTrash2 /> Delete selected
              </button>
            </div>
          )}
          {(quizzes as Record<string, unknown>[])?.map((q) => (
            <div key={q.id as string} className="card">
              <div className="flex justify-between items-start">
              <div className="flex items-start gap-3">
                <input
                  className="mt-1"
                  type="checkbox"
                  checked={selectedQuizIds.includes(q.id as string)}
                  onChange={(e) => {
                    const id = q.id as string;
                    if (e.target.checked) setSelectedQuizIds((prev) => Array.from(new Set([...prev, id])));
                    else setSelectedQuizIds((prev) => prev.filter((x) => x !== id));
                  }}
                />
                <div>
                  <button
                    className="text-left"
                    onClick={() => {
                      const id = q.id as string;
                      setExpandedQuizId((prev) => (prev === id ? null : id));
                      setQuestionForm((prev) => ({ ...prev, quizId: id }));
                    }}
                    title="Click to manage questions"
                  >
                    <h3 className="font-semibold">{q.title as string}</h3>
                  </button>
                  <p className="text-sm text-gray-500">{q.quizType as string} · {((q as Record<string, unknown>).questions as unknown[])?.length || 0} questions</p>
                </div>
              </div>
              {role === 'ADMIN' && (
                <div className="flex gap-2">
                  <button
                    className="text-gray-400 hover:text-gray-700"
                    title="Edit"
                    onClick={() => {
                      const id = q.id as string;
                      const currentTitle = (q.title as string) || '';
                      const currentType = (q.quizType as string) || 'MULTIPLE_CHOICE';
                      const nextTitle = window.prompt('Quiz title', currentTitle);
                      if (nextTitle == null) return;
                      const nextType = window.prompt('Quiz type (MULTIPLE_CHOICE | FILL_IN_BLANK | LISTENING)', currentType);
                      if (nextType == null) return;
                      updateQuiz.mutate({ id, data: { title: nextTitle, quizType: nextType } });
                    }}
                    disabled={updateQuiz.isPending}
                  >
                    <FiEdit2 size={14} />
                  </button>
                  <button
                    className="text-gray-400 hover:text-red-500"
                    title="Delete"
                    onClick={() => {
                      const id = q.id as string;
                      if (!confirm('Delete quiz?')) return;
                      deleteQuiz.mutate(id);
                    }}
                    disabled={deleteQuiz.isPending}
                  >
                    <FiTrash2 size={14} />
                  </button>
                </div>
              )}
            </div>

            {expandedQuizId === (q.id as string) && (
              <div className="mt-4 border-t pt-4 space-y-4">
                <div>
                  <h4 className="font-semibold text-sm mb-2">Questions</h4>
                  <div className="space-y-2">
                    {(((q as any).questions as any[]) || []).map((qu) => (
                      <div key={qu.id} className="p-3 rounded-lg bg-gray-50 flex justify-between items-start gap-3">
                        <div className="flex-1">
                          <div className="text-xs text-gray-500">{qu.questionType}</div>
                          <div className="font-medium">{qu.questionText}</div>
                          <div className="text-xs text-gray-500 mt-1">Correct: {qu.correctAnswer}</div>
                          {Array.isArray(qu.options) && qu.options.length > 0 && (
                            <div className="grid grid-cols-1 md:grid-cols-2 gap-1 mt-2">
                              {qu.options.map((op: any) => (
                                <div key={op.id} className={`text-xs px-2 py-1 rounded border ${op.isCorrect ? 'border-green-300 bg-green-50' : 'border-gray-200 bg-white'}`}>
                                  {op.text}
                                </div>
                              ))}
                            </div>
                          )}
                        </div>

                        {role === 'ADMIN' && (
                          <div className="flex gap-2">
                            <button
                              className="text-gray-400 hover:text-gray-700"
                              title="Edit question"
                              onClick={() => {
                                const nextText = window.prompt('Question text', qu.questionText || '');
                                if (nextText == null) return;
                                const nextCorrect = window.prompt('Correct answer', qu.correctAnswer || '');
                                if (nextCorrect == null) return;
                                updateQuizQuestion.mutate({
                                  id: qu.id,
                                  data: {
                                    questionText: nextText,
                                    correctAnswer: nextCorrect,
                                    questionType: qu.questionType || 'MULTIPLE_CHOICE',
                                  },
                                });
                              }}
                              disabled={updateQuizQuestion.isPending}
                            >
                              <FiEdit2 size={14} />
                            </button>
                            <button
                              className="text-gray-400 hover:text-red-500"
                              title="Delete question"
                              onClick={() => {
                                if (!confirm('Delete question?')) return;
                                deleteQuizQuestion.mutate(qu.id);
                              }}
                              disabled={deleteQuizQuestion.isPending}
                            >
                              <FiTrash2 size={14} />
                            </button>
                          </div>
                        )}
                      </div>
                    ))}
                    {((((q as any).questions as any[]) || []).length === 0) && (
                      <div className="text-sm text-gray-400">No questions yet</div>
                    )}
                  </div>
                </div>

                {role === 'ADMIN' && (
                  <form
                    className="p-4 rounded-lg border bg-white"
                    onSubmit={(e) => {
                      e.preventDefault();
                      const quizId = (q.id as string) || '';
                      if (!quizId) return;

                      const optionTexts = [
                        questionForm.optionA,
                        questionForm.optionB,
                        questionForm.optionC,
                        questionForm.optionD,
                      ].map((x) => String(x || '').trim()).filter(Boolean);

                      const correctIndex = Math.max(0, Math.min(3, Number(questionForm.correctOptionIndex) || 0));
                      const correctAnswer =
                        optionTexts[correctIndex] || String(questionForm.correctAnswer || '').trim();

                      createQuizQuestion.mutate({
                        quizId,
                        questionType: questionForm.questionType,
                        questionText: questionForm.questionText,
                        correctAnswer,
                        options: optionTexts.length
                          ? optionTexts.map((text, idx) => ({ text, isCorrect: idx === correctIndex }))
                          : undefined,
                      });
                    }}
                  >
                    <div className="font-semibold text-sm mb-3">Add question</div>
                    <div className="grid grid-cols-1 md:grid-cols-3 gap-3">
                      <div className="md:col-span-2">
                        <label className="label">Question</label>
                        <input
                          className="input"
                          value={questionForm.questionText}
                          onChange={(e) => setQuestionForm((p) => ({ ...p, questionText: e.target.value }))}
                          required
                        />
                      </div>
                      <div>
                        <label className="label">Type</label>
                        <select
                          className="input"
                          value={questionForm.questionType}
                          onChange={(e) => setQuestionForm((p) => ({ ...p, questionType: e.target.value }))}
                        >
                          <option value="MULTIPLE_CHOICE">MULTIPLE_CHOICE</option>
                          <option value="FILL_IN_BLANK">FILL_IN_BLANK</option>
                          <option value="LISTENING">LISTENING</option>
                        </select>
                      </div>
                      <div>
                        <label className="label">Option A</label>
                        <input className="input" value={questionForm.optionA} onChange={(e) => setQuestionForm((p) => ({ ...p, optionA: e.target.value }))} />
                      </div>
                      <div>
                        <label className="label">Option B</label>
                        <input className="input" value={questionForm.optionB} onChange={(e) => setQuestionForm((p) => ({ ...p, optionB: e.target.value }))} />
                      </div>
                      <div>
                        <label className="label">Option C</label>
                        <input className="input" value={questionForm.optionC} onChange={(e) => setQuestionForm((p) => ({ ...p, optionC: e.target.value }))} />
                      </div>
                      <div>
                        <label className="label">Option D</label>
                        <input className="input" value={questionForm.optionD} onChange={(e) => setQuestionForm((p) => ({ ...p, optionD: e.target.value }))} />
                      </div>
                      <div>
                        <label className="label">Correct option</label>
                        <select
                          className="input"
                          value={String(questionForm.correctOptionIndex)}
                          onChange={(e) => setQuestionForm((p) => ({ ...p, correctOptionIndex: Number(e.target.value) }))}
                        >
                          <option value="0">A</option>
                          <option value="1">B</option>
                          <option value="2">C</option>
                          <option value="3">D</option>
                        </select>
                      </div>
                      <div className="md:col-span-2">
                        <label className="label">Correct answer (optional override)</label>
                        <input className="input" value={questionForm.correctAnswer} onChange={(e) => setQuestionForm((p) => ({ ...p, correctAnswer: e.target.value }))} />
                      </div>
                    </div>
                    <div className="flex gap-2 mt-3">
                      <button className="btn-primary" type="submit" disabled={createQuizQuestion.isPending}>
                        {createQuizQuestion.isPending ? 'Adding...' : 'Add question'}
                      </button>
                      <button
                        className="btn-secondary"
                        type="button"
                        onClick={() => setExpandedQuizId(null)}
                      >
                        Close
                      </button>
                    </div>
                  </form>
                )}
              </div>
            )}
            </div>
          ))}
          {(!quizzes || (quizzes as unknown[]).length === 0) && <p className="text-center text-gray-400 py-8">No quizzes yet</p>}
        </div>
      )}
    </div>
  );
}

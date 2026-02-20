import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query';
import { useParams, useNavigate } from 'react-router-dom';
import { lessonsApi, vocabularyApi, grammarApi, dialoguesApi, quizzesApi } from '../lib/api';
import { useState } from 'react';
import toast from 'react-hot-toast';
import { FiPlus, FiTrash2, FiArrowLeft } from 'react-icons/fi';

export default function LessonDetailPage() {
  const { lessonId } = useParams<{ lessonId: string }>();
  const navigate = useNavigate();
  const queryClient = useQueryClient();
  const [activeTab, setActiveTab] = useState<'vocab' | 'grammar' | 'dialogue' | 'quiz'>('vocab');
  const [vocabForm, setVocabForm] = useState({ korean: '', vietnamese: '', pronunciation: '', difficulty: 'EASY', exampleSentence: '', exampleMeaning: '' });
  const [grammarForm, setGrammarForm] = useState({ pattern: '', explanationVN: '', example: '' });
  const [dialogueForm, setDialogueForm] = useState({ speaker: '', koreanText: '', vietnameseText: '', orderIndex: 0 });
  const [showForm, setShowForm] = useState(false);

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
        <button onClick={() => setShowForm(!showForm)} className="btn-primary flex items-center gap-2">
          <FiPlus /> Add {activeTab === 'vocab' ? 'Vocabulary' : activeTab === 'grammar' ? 'Grammar' : 'Dialogue'}
        </button>
      </div>

      {/* Tabs */}
      <div className="flex gap-1 mb-6 bg-gray-100 rounded-lg p-1">
        {tabs.map((tab) => (
          <button
            key={tab.id}
            onClick={() => { setActiveTab(tab.id); setShowForm(false); }}
            className={`flex-1 px-4 py-2 rounded-lg text-sm font-medium transition-colors ${activeTab === tab.id ? 'bg-white shadow text-primary-600' : 'text-gray-600 hover:text-gray-800'}`}
          >
            {tab.label} ({tab.count})
          </button>
        ))}
      </div>

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

      {/* Content Tables */}
      {activeTab === 'vocab' && (
        <div className="card overflow-hidden p-0">
          <table className="w-full">
            <thead className="bg-gray-50"><tr>
              <th className="table-header">Korean</th><th className="table-header">Vietnamese</th><th className="table-header">Pronunciation</th><th className="table-header">Difficulty</th><th className="table-header">Example</th><th className="table-header w-16"></th>
            </tr></thead>
            <tbody className="divide-y divide-gray-100">
              {(vocab as Record<string, unknown>[])?.map((v) => (
                <tr key={v.id as string} className="hover:bg-gray-50">
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
          {(grammars as Record<string, unknown>[])?.map((g) => (
            <div key={g.id as string} className="card flex justify-between items-start">
              <div>
                <h3 className="font-semibold text-primary-600 text-lg">{g.pattern as string}</h3>
                <p className="text-sm text-gray-700 mt-1">{g.explanationVN as string}</p>
                {(g.example as string) && <p className="text-sm text-gray-500 mt-1 italic">{g.example as string}</p>}
              </div>
              <button onClick={() => { if (confirm('Delete?')) deleteGrammar.mutate(g.id as string); }} className="text-gray-400 hover:text-red-500"><FiTrash2 size={14} /></button>
            </div>
          ))}
        </div>
      )}

      {activeTab === 'dialogue' && (
        <div className="card">
          <div className="space-y-3">
            {(dialogues as Record<string, unknown>[])?.map((d) => (
              <div key={d.id as string} className="flex items-start gap-3 p-3 rounded-lg bg-gray-50 group">
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
          {(quizzes as Record<string, unknown>[])?.map((q) => (
            <div key={q.id as string} className="card">
              <h3 className="font-semibold">{q.title as string}</h3>
              <p className="text-sm text-gray-500">{q.quizType as string} · {((q as Record<string, unknown>).questions as unknown[])?.length || 0} questions</p>
            </div>
          ))}
          {(!quizzes || (quizzes as unknown[]).length === 0) && <p className="text-center text-gray-400 py-8">No quizzes yet</p>}
        </div>
      )}
    </div>
  );
}

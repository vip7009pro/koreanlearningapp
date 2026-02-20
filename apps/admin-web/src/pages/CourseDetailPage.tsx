import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query';
import { useParams, useNavigate } from 'react-router-dom';
import { coursesApi, sectionsApi, lessonsApi } from '../lib/api';
import { useState } from 'react';
import toast from 'react-hot-toast';
import { FiPlus, FiTrash2, FiChevronRight, FiArrowLeft } from 'react-icons/fi';

export default function CourseDetailPage() {
  const { courseId } = useParams<{ courseId: string }>();
  const navigate = useNavigate();
  const queryClient = useQueryClient();
  const [sectionForm, setSectionForm] = useState({ title: '', orderIndex: 0 });
  const [lessonForm, setLessonForm] = useState({ title: '', description: '', orderIndex: 0, estimatedMinutes: 15 });
  const [showSectionForm, setShowSectionForm] = useState(false);
  const [showLessonForm, setShowLessonForm] = useState<string | null>(null);

  const { data: course } = useQuery({
    queryKey: ['course', courseId],
    queryFn: () => coursesApi.getOne(courseId!).then((r) => r.data),
    enabled: !!courseId,
  });

  const { data: sections } = useQuery({
    queryKey: ['sections', courseId],
    queryFn: () => sectionsApi.getByCourse(courseId!).then((r) => r.data),
    enabled: !!courseId,
  });

  const createSection = useMutation({
    mutationFn: (data: typeof sectionForm) => sectionsApi.create({ ...data, courseId }),
    onSuccess: () => { queryClient.invalidateQueries({ queryKey: ['sections', courseId] }); toast.success('Section created'); setShowSectionForm(false); },
  });

  const deleteSection = useMutation({
    mutationFn: (id: string) => sectionsApi.delete(id),
    onSuccess: () => { queryClient.invalidateQueries({ queryKey: ['sections', courseId] }); toast.success('Section deleted'); },
  });

  const createLesson = useMutation({
    mutationFn: ({ sectionId, data }: { sectionId: string; data: typeof lessonForm }) => lessonsApi.create({ ...data, sectionId }),
    onSuccess: () => { queryClient.invalidateQueries({ queryKey: ['sections', courseId] }); toast.success('Lesson created'); setShowLessonForm(null); },
  });

  const deleteLesson = useMutation({
    mutationFn: (id: string) => lessonsApi.delete(id),
    onSuccess: () => { queryClient.invalidateQueries({ queryKey: ['sections', courseId] }); toast.success('Lesson deleted'); },
  });

  return (
    <div>
      <button onClick={() => navigate('/courses')} className="flex items-center gap-1 text-gray-500 hover:text-gray-700 mb-4 text-sm">
        <FiArrowLeft /> Back to Courses
      </button>

      <div className="flex justify-between items-start mb-6">
        <div>
          <h1 className="text-2xl font-bold text-gray-800">{course?.title}</h1>
          <p className="text-gray-500 mt-1">{course?.description}</p>
          <div className="flex gap-2 mt-2">
            <span className="badge badge-blue">{course?.level}</span>
            {course?.isPremium && <span className="badge badge-yellow">Premium</span>}
            {course?.published ? <span className="badge badge-green">Published</span> : <span className="badge badge-red">Draft</span>}
          </div>
        </div>
        <button onClick={() => setShowSectionForm(!showSectionForm)} className="btn-primary flex items-center gap-2">
          <FiPlus /> Add Section
        </button>
      </div>

      {showSectionForm && (
        <form onSubmit={(e) => { e.preventDefault(); createSection.mutate(sectionForm); }} className="card mb-6 grid grid-cols-1 md:grid-cols-3 gap-4">
          <div className="md:col-span-2">
            <label className="label">Section Title</label>
            <input className="input" value={sectionForm.title} onChange={(e) => setSectionForm({ ...sectionForm, title: e.target.value })} required />
          </div>
          <div>
            <label className="label">Order</label>
            <input type="number" className="input" value={sectionForm.orderIndex} onChange={(e) => setSectionForm({ ...sectionForm, orderIndex: +e.target.value })} />
          </div>
          <div className="md:col-span-3 flex gap-2">
            <button type="submit" className="btn-primary">Create Section</button>
            <button type="button" onClick={() => setShowSectionForm(false)} className="btn-secondary">Cancel</button>
          </div>
        </form>
      )}

      <div className="space-y-4">
        {(sections as Record<string, unknown>[])?.map((section) => (
          <div key={section.id as string} className="card">
            <div className="flex justify-between items-center mb-4">
              <h2 className="text-lg font-semibold text-gray-800">{section.title as string}</h2>
              <div className="flex gap-2">
                <button onClick={() => setShowLessonForm(showLessonForm === section.id ? null : section.id as string)} className="btn-secondary text-xs flex items-center gap-1">
                  <FiPlus size={12} /> Add Lesson
                </button>
                <button onClick={() => { if (confirm('Delete section?')) deleteSection.mutate(section.id as string); }} className="text-red-500 hover:text-red-700">
                  <FiTrash2 size={16} />
                </button>
              </div>
            </div>

            {showLessonForm === section.id && (
              <form onSubmit={(e) => { e.preventDefault(); createLesson.mutate({ sectionId: section.id as string, data: lessonForm }); }} className="grid grid-cols-1 md:grid-cols-4 gap-3 mb-4 p-4 bg-gray-50 rounded-lg">
                <div className="md:col-span-2">
                  <label className="label">Title</label>
                  <input className="input" value={lessonForm.title} onChange={(e) => setLessonForm({ ...lessonForm, title: e.target.value })} required />
                </div>
                <div>
                  <label className="label">Order</label>
                  <input type="number" className="input" value={lessonForm.orderIndex} onChange={(e) => setLessonForm({ ...lessonForm, orderIndex: +e.target.value })} />
                </div>
                <div>
                  <label className="label">Minutes</label>
                  <input type="number" className="input" value={lessonForm.estimatedMinutes} onChange={(e) => setLessonForm({ ...lessonForm, estimatedMinutes: +e.target.value })} />
                </div>
                <div className="md:col-span-4 flex gap-2">
                  <button type="submit" className="btn-primary text-xs">Create</button>
                  <button type="button" onClick={() => setShowLessonForm(null)} className="btn-secondary text-xs">Cancel</button>
                </div>
              </form>
            )}

            <div className="space-y-1">
              {((section as Record<string, unknown>).lessons as Record<string, unknown>[] || []).map((lesson: Record<string, unknown>) => (
                <div key={lesson.id as string} onClick={() => navigate(`/lessons/${lesson.id}`)} className="flex items-center justify-between p-3 rounded-lg hover:bg-gray-50 cursor-pointer group">
                  <div className="flex items-center gap-3">
                    <span className="text-sm text-gray-400">{(lesson.orderIndex as number) + 1}.</span>
                    <span className="text-sm font-medium text-gray-800">{lesson.title as string}</span>
                    <span className="text-xs text-gray-400">{lesson.estimatedMinutes as number} min</span>
                  </div>
                  <div className="flex items-center gap-2">
                    <button onClick={(e) => { e.stopPropagation(); if (confirm('Delete lesson?')) deleteLesson.mutate(lesson.id as string); }} className="text-gray-400 hover:text-red-500 opacity-0 group-hover:opacity-100">
                      <FiTrash2 size={14} />
                    </button>
                    <FiChevronRight className="text-gray-400" size={14} />
                  </div>
                </div>
              ))}
              {(!((section as Record<string, unknown>).lessons as unknown[]) || ((section as Record<string, unknown>).lessons as unknown[]).length === 0) && (
                <p className="text-sm text-gray-400 text-center py-2">No lessons yet</p>
              )}
            </div>
          </div>
        ))}
      </div>
    </div>
  );
}

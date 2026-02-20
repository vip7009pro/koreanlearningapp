import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query';
import { coursesApi } from '../lib/api';
import { useNavigate } from 'react-router-dom';
import { useState } from 'react';
import toast from 'react-hot-toast';
import { FiPlus, FiEdit2, FiTrash2, FiEye, FiEyeOff } from 'react-icons/fi';

export default function CoursesPage() {
  const queryClient = useQueryClient();
  const navigate = useNavigate();
  const [showForm, setShowForm] = useState(false);
  const [editId, setEditId] = useState<string | null>(null);
  const [form, setForm] = useState({ title: '', description: '', level: 'BEGINNER', isPremium: false });

  const { data: courses, isLoading } = useQuery({
    queryKey: ['courses'],
    queryFn: () => coursesApi.getAll().then((r) => r.data.data),
  });

  const createMut = useMutation({
    mutationFn: (data: typeof form) => coursesApi.create(data),
    onSuccess: () => { queryClient.invalidateQueries({ queryKey: ['courses'] }); toast.success('Course created'); resetForm(); },
  });

  const updateMut = useMutation({
    mutationFn: ({ id, data }: { id: string; data: typeof form }) => coursesApi.update(id, data),
    onSuccess: () => { queryClient.invalidateQueries({ queryKey: ['courses'] }); toast.success('Course updated'); resetForm(); },
  });

  const deleteMut = useMutation({
    mutationFn: (id: string) => coursesApi.delete(id),
    onSuccess: () => { queryClient.invalidateQueries({ queryKey: ['courses'] }); toast.success('Course deleted'); },
  });

  const publishMut = useMutation({
    mutationFn: ({ id, publish }: { id: string; publish: boolean }) => publish ? coursesApi.publish(id) : coursesApi.unpublish(id),
    onSuccess: () => { queryClient.invalidateQueries({ queryKey: ['courses'] }); toast.success('Status updated'); },
  });

  const resetForm = () => { setShowForm(false); setEditId(null); setForm({ title: '', description: '', level: 'BEGINNER', isPremium: false }); };

  const handleEdit = (course: Record<string, unknown>) => {
    setEditId(course.id as string);
    setForm({ title: course.title as string, description: course.description as string, level: course.level as string, isPremium: course.isPremium as boolean });
    setShowForm(true);
  };

  const handleSubmit = (e: React.FormEvent) => {
    e.preventDefault();
    if (editId) updateMut.mutate({ id: editId, data: form });
    else createMut.mutate(form);
  };

  if (isLoading) return <div className="text-center py-12 text-gray-500">Loading...</div>;

  return (
    <div>
      <div className="flex justify-between items-center mb-6">
        <h1 className="text-2xl font-bold text-gray-800">Courses</h1>
        <button onClick={() => setShowForm(!showForm)} className="btn-primary flex items-center gap-2">
          <FiPlus /> {showForm ? 'Cancel' : 'Add Course'}
        </button>
      </div>

      {showForm && (
        <form onSubmit={handleSubmit} className="card mb-6 grid grid-cols-1 md:grid-cols-2 gap-4">
          <div className="md:col-span-2">
            <label className="label">Title</label>
            <input className="input" value={form.title} onChange={(e) => setForm({ ...form, title: e.target.value })} required />
          </div>
          <div className="md:col-span-2">
            <label className="label">Description</label>
            <textarea className="input" rows={3} value={form.description} onChange={(e) => setForm({ ...form, description: e.target.value })} required />
          </div>
          <div>
            <label className="label">Level</label>
            <select className="input" value={form.level} onChange={(e) => setForm({ ...form, level: e.target.value })}>
              <option value="BEGINNER">Beginner</option>
              <option value="ELEMENTARY">Elementary</option>
              <option value="INTERMEDIATE">Intermediate</option>
              <option value="ADVANCED">Advanced</option>
            </select>
          </div>
          <div className="flex items-center gap-2 mt-6">
            <input type="checkbox" checked={form.isPremium} onChange={(e) => setForm({ ...form, isPremium: e.target.checked })} />
            <span className="text-sm">Premium Only</span>
          </div>
          <div className="md:col-span-2 flex gap-2">
            <button type="submit" className="btn-primary">{editId ? 'Update' : 'Create'}</button>
            <button type="button" onClick={resetForm} className="btn-secondary">Cancel</button>
          </div>
        </form>
      )}

      <div className="card overflow-hidden p-0">
        <table className="w-full">
          <thead className="bg-gray-50">
            <tr>
              <th className="table-header">Title</th>
              <th className="table-header">Level</th>
              <th className="table-header">Premium</th>
              <th className="table-header">Published</th>
              <th className="table-header">Actions</th>
            </tr>
          </thead>
          <tbody className="divide-y divide-gray-100">
            {(courses as Record<string, unknown>[])?.map((course) => (
              <tr key={course.id as string} className="hover:bg-gray-50 cursor-pointer" onClick={() => navigate(`/courses/${course.id}`)}>
                <td className="table-cell font-medium text-gray-900">{course.title as string}</td>
                <td className="table-cell"><span className="badge badge-blue">{course.level as string}</span></td>
                <td className="table-cell">{(course.isPremium as boolean) ? <span className="badge badge-yellow">Premium</span> : <span className="badge badge-green">Free</span>}</td>
                <td className="table-cell">{(course.published as boolean) ? <span className="badge badge-green">Published</span> : <span className="badge badge-red">Draft</span>}</td>
                <td className="table-cell" onClick={(e) => e.stopPropagation()}>
                  <div className="flex gap-2">
                    <button onClick={() => publishMut.mutate({ id: course.id as string, publish: !(course.published as boolean) })} className="text-gray-500 hover:text-primary-600" title={course.published ? 'Unpublish' : 'Publish'}>
                      {(course.published as boolean) ? <FiEyeOff size={16} /> : <FiEye size={16} />}
                    </button>
                    <button onClick={() => handleEdit(course)} className="text-gray-500 hover:text-primary-600"><FiEdit2 size={16} /></button>
                    <button onClick={() => { if (confirm('Delete?')) deleteMut.mutate(course.id as string); }} className="text-gray-500 hover:text-red-600"><FiTrash2 size={16} /></button>
                  </div>
                </td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>
    </div>
  );
}

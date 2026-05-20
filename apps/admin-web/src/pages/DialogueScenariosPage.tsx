import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query';
import { aiDialoguesApi } from '../lib/api';
import { useState } from 'react';
import toast from 'react-hot-toast';
import { FiPlus, FiEdit2, FiTrash2, FiMessageSquare } from 'react-icons/fi';

interface ScenarioForm {
  title: string;
  description: string;
  difficulty: 'EASY' | 'MEDIUM' | 'HARD';
  initialPrompt: string;
  starterMessage: string;
}

const initialFormState: ScenarioForm = {
  title: '',
  description: '',
  difficulty: 'EASY',
  initialPrompt: '',
  starterMessage: '',
};

export default function DialogueScenariosPage() {
  const queryClient = useQueryClient();
  const [showForm, setShowForm] = useState(false);
  const [editId, setEditId] = useState<string | null>(null);
  const [form, setForm] = useState<ScenarioForm>(initialFormState);

  const { data: scenarios, isLoading } = useQuery({
    queryKey: ['dialogueScenarios'],
    queryFn: () => aiDialoguesApi.getScenarios().then((r) => r.data),
  });

  const createMut = useMutation({
    mutationFn: (data: ScenarioForm) => aiDialoguesApi.createScenario(data),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['dialogueScenarios'] });
      toast.success('Đã tạo kịch bản mới thành công!');
      resetForm();
    },
    onError: (err: any) => {
      toast.error('Lỗi khi tạo kịch bản: ' + (err.response?.data?.message || err.message));
    },
  });

  const updateMut = useMutation({
    mutationFn: ({ id, data }: { id: string; data: ScenarioForm }) =>
      aiDialoguesApi.updateScenario(id, data),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['dialogueScenarios'] });
      toast.success('Đã cập nhật kịch bản thành công!');
      resetForm();
    },
    onError: (err: any) => {
      toast.error('Lỗi khi cập nhật kịch bản: ' + (err.response?.data?.message || err.message));
    },
  });

  const deleteMut = useMutation({
    mutationFn: (id: string) => aiDialoguesApi.deleteScenario(id),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['dialogueScenarios'] });
      toast.success('Đã xóa kịch bản thành công!');
    },
    onError: (err: any) => {
      toast.error('Lỗi khi xóa kịch bản: ' + (err.response?.data?.message || err.message));
    },
  });

  const resetForm = () => {
    setShowForm(false);
    setEditId(null);
    setForm(initialFormState);
  };

  const handleEdit = (scenario: any) => {
    setEditId(scenario.id);
    setForm({
      title: scenario.title,
      description: scenario.description,
      difficulty: scenario.difficulty,
      initialPrompt: scenario.initialPrompt,
      starterMessage: scenario.starterMessage,
    });
    setShowForm(true);
  };

  const handleSubmit = (e: React.FormEvent) => {
    e.preventDefault();
    if (editId) {
      updateMut.mutate({ id: editId, data: form });
    } else {
      createMut.mutate(form);
    }
  };

  const getDifficultyBadge = (difficulty: string) => {
    switch (difficulty) {
      case 'EASY':
        return 'badge-green';
      case 'MEDIUM':
        return 'badge-blue';
      case 'HARD':
        return 'badge-red';
      default:
        return 'badge-blue';
    }
  };

  if (isLoading) return <div className="text-center py-12 text-gray-500">Đang tải danh sách kịch bản...</div>;

  return (
    <div>
      <div className="flex justify-between items-center mb-6">
        <h1 className="text-2xl font-bold text-gray-800 flex items-center gap-2">
          <FiMessageSquare className="text-indigo-600" /> Quản lý Kịch bản AI Hội thoại
        </h1>
        <button
          onClick={() => {
            if (showForm) resetForm();
            else setShowForm(true);
          }}
          className="btn-primary flex items-center gap-2"
        >
          <FiPlus /> {showForm ? 'Hủy bỏ' : 'Thêm Kịch bản'}
        </button>
      </div>

      {showForm && (
        <form onSubmit={handleSubmit} className="card mb-6 grid grid-cols-1 md:grid-cols-2 gap-4">
          <h2 className="md:col-span-2 text-lg font-bold text-gray-700 border-b pb-2 mb-2">
            {editId ? 'Chỉnh sửa kịch bản' : 'Thêm kịch bản hội thoại mới'}
          </h2>
          
          <div className="md:col-span-2">
            <label className="label">Tiêu đề kịch bản</label>
            <input
              className="input"
              value={form.title}
              onChange={(e) => setForm({ ...form, title: e.target.value })}
              placeholder="Ví dụ: Phỏng vấn xin việc tại công ty Hàn Quốc"
              required
            />
          </div>

          <div className="md:col-span-2">
            <label className="label">Mô tả kịch bản</label>
            <textarea
              className="input"
              rows={2}
              value={form.description}
              onChange={(e) => setForm({ ...form, description: e.target.value })}
              placeholder="Mô tả bối cảnh để người dùng chuẩn bị trước khi vào hội thoại..."
              required
            />
          </div>

          <div>
            <label className="label">Độ khó</label>
            <select
              className="input"
              value={form.difficulty}
              onChange={(e) => setForm({ ...form, difficulty: e.target.value as any })}
            >
              <option value="EASY">Dễ (Easy)</option>
              <option value="MEDIUM">Trung bình (Medium)</option>
              <option value="HARD">Khó (Hard)</option>
            </select>
          </div>

          <div>
            <label className="label">Lời mở đầu (Starter Message bằng tiếng Hàn)</label>
            <input
              className="input font-mono"
              value={form.starterMessage}
              onChange={(e) => setForm({ ...form, starterMessage: e.target.value })}
              placeholder="Ví dụ: 안녕하세요! 면접에 참석해 주셔서 감사합니다. 자기소개를 해보세요."
              required
            />
          </div>

          <div className="md:col-span-2">
            <label className="label">System Prompt (Yêu cầu huấn luyện AI)</label>
            <textarea
              className="input font-mono text-sm"
              rows={5}
              value={form.initialPrompt}
              onChange={(e) => setForm({ ...form, initialPrompt: e.target.value })}
              placeholder="Bạn là Giám đốc Nhân sự của một tập đoàn lớn tại Seoul. Hãy phỏng vấn ứng viên bằng tiếng Hàn một cách trang trọng. Phản hồi của bạn nên ngắn gọn, từ 1-2 câu để kích thích ứng viên tiếp tục trò chuyện..."
              required
            />
          </div>

          <div className="md:col-span-2 flex gap-2 justify-end mt-4">
            <button type="submit" disabled={createMut.isPending || updateMut.isPending} className="btn-primary">
              {editId ? 'Cập nhật' : 'Tạo mới'}
            </button>
            <button type="button" onClick={resetForm} className="btn-secondary">
              Hủy bỏ
            </button>
          </div>
        </form>
      )}

      <div className="card overflow-hidden p-0">
        <div className="overflow-x-auto">
          <table className="w-full text-left border-collapse">
            <thead className="bg-gray-50">
              <tr>
                <th className="table-header w-1/4">Tiêu đề / Mô tả</th>
                <th className="table-header w-12 text-center">Độ khó</th>
                <th className="table-header">Lời mở đầu (Starter)</th>
                <th className="table-header">Prompt huấn luyện</th>
                <th className="table-header w-24 text-center">Thao tác</th>
              </tr>
            </thead>
            <tbody className="divide-y divide-gray-100">
              {scenarios && scenarios.length === 0 ? (
                <tr>
                  <td colSpan={5} className="text-center py-10 text-gray-400">
                    Chưa có kịch bản hội thoại nào được thiết lập.
                  </td>
                </tr>
              ) : (
                scenarios?.map((scenario: any) => (
                  <tr key={scenario.id} className="hover:bg-gray-50 align-top">
                    <td className="table-cell">
                      <div className="font-bold text-gray-900 mb-1">{scenario.title}</div>
                      <div className="text-xs text-gray-500 line-clamp-2">{scenario.description}</div>
                    </td>
                    <td className="table-cell text-center">
                      <span className={`badge ${getDifficultyBadge(scenario.difficulty)}`}>
                        {scenario.difficulty}
                      </span>
                    </td>
                    <td className="table-cell font-mono text-xs text-gray-600 line-clamp-2 max-w-xs">
                      {scenario.starterMessage}
                    </td>
                    <td className="table-cell text-xs text-gray-500">
                      <div className="line-clamp-2 max-w-sm" title={scenario.initialPrompt}>
                        {scenario.initialPrompt}
                      </div>
                    </td>
                    <td className="table-cell">
                      <div className="flex gap-3 justify-center">
                        <button
                          onClick={() => handleEdit(scenario)}
                          className="text-gray-500 hover:text-indigo-600 transition-colors"
                          title="Chỉnh sửa"
                        >
                          <FiEdit2 size={16} />
                        </button>
                        <button
                          onClick={() => {
                            if (confirm(`Bạn chắc chắn muốn xóa kịch bản "${scenario.title}"?`)) {
                              deleteMut.mutate(scenario.id);
                            }
                          }}
                          className="text-gray-500 hover:text-red-600 transition-colors"
                          title="Xóa kịch bản"
                        >
                          <FiTrash2 size={16} />
                        </button>
                      </div>
                    </td>
                  </tr>
                ))
              )}
            </tbody>
          </table>
        </div>
      </div>
    </div>
  );
}

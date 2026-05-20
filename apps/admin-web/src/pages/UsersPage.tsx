import { useState } from 'react';
import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query';
import { usersApi } from '../lib/api';
import toast from 'react-hot-toast';
import { FiTrash2, FiChevronLeft, FiChevronRight } from 'react-icons/fi';

export default function UsersPage() {
  const queryClient = useQueryClient();
  const [page, setPage] = useState(1);
  const [limit, setLimit] = useState(20);

  const { data, isLoading } = useQuery({
    queryKey: ['users', page, limit],
    queryFn: () => usersApi.getAll({ page, limit }).then((r) => r.data),
  });

  const deleteMut = useMutation({
    mutationFn: (id: string) => usersApi.delete(id),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['users'] });
      toast.success('User deleted');
    },
  });

  if (isLoading) return <div className="text-center py-12 text-gray-500">Loading...</div>;

  const users = data?.data || [];
  const total = data?.total || 0;
  const totalPages = data?.totalPages || 1;

  const handleNext = () => {
    if (page < totalPages) {
      setPage((p) => p + 1);
    }
  };

  const handlePrev = () => {
    if (page > 1) {
      setPage((p) => p - 1);
    }
  };

  return (
    <div>
      <div className="flex justify-between items-center mb-6">
        <h1 className="text-2xl font-bold text-gray-800">Users</h1>
        <div className="text-sm text-gray-500 font-medium bg-white px-3 py-1.5 rounded-lg border border-gray-100 shadow-sm">
          Tổng số thành viên: <span className="text-primary-600 font-bold">{total}</span>
        </div>
      </div>
      
      <div className="card overflow-hidden p-0">
        <table className="w-full">
          <thead className="bg-gray-50">
            <tr>
              <th className="table-header">Name</th>
              <th className="table-header">Email</th>
              <th className="table-header">Role</th>
              <th className="table-header">XP</th>
              <th className="table-header">Streak</th>
              <th className="table-header">Joined</th>
              <th className="table-header w-16"></th>
            </tr>
          </thead>
          <tbody className="divide-y divide-gray-100">
            {(users as Record<string, unknown>[])?.map((user) => (
              <tr key={user.id as string} className="hover:bg-gray-50">
                <td className="table-cell font-medium">{user.displayName as string}</td>
                <td className="table-cell text-gray-500">{user.email as string}</td>
                <td className="table-cell">
                  <span className={`badge ${user.role === 'ADMIN' ? 'badge-red' : 'badge-blue'}`}>{user.role as string}</span>
                </td>
                <td className="table-cell">{(user.totalXP as number) || 0} XP</td>
                <td className="table-cell">🔥 {(user.streakDays as number) || 0}</td>
                <td className="table-cell text-xs text-gray-400">{new Date(user.createdAt as string).toLocaleDateString()}</td>
                <td className="table-cell">
                  {user.role !== 'ADMIN' && (
                    <button onClick={() => { if (confirm('Delete user?')) deleteMut.mutate(user.id as string); }} className="text-gray-400 hover:text-red-500">
                      <FiTrash2 size={14} />
                    </button>
                  )}
                </td>
              </tr>
            ))}
          </tbody>
        </table>

        {/* Pagination Section */}
        <div className="flex flex-col sm:flex-row justify-between items-center gap-4 px-6 py-4 bg-gray-50 border-t border-gray-100">
          <div className="flex items-center gap-2">
            <span className="text-xs text-gray-500 font-medium">Hiển thị:</span>
            <select
              value={limit}
              onChange={(e) => {
                setLimit(Number(e.target.value));
                setPage(1);
              }}
              className="text-xs border border-gray-300 rounded px-2.5 py-1 bg-white focus:outline-none focus:ring-1 focus:ring-primary-500 cursor-pointer"
            >
              <option value={10}>10 dòng</option>
              <option value={20}>20 dòng</option>
              <option value={50}>50 dòng</option>
              <option value={100}>100 dòng</option>
            </select>
            {total > 0 && (
              <span className="text-xs text-gray-400 ml-1">
                (Dòng {Math.min(total, (page - 1) * limit + 1)} - {Math.min(total, page * limit)} của {total})
              </span>
            )}
          </div>

          <div className="flex items-center gap-3">
            <button
              onClick={handlePrev}
              disabled={page === 1}
              className={`p-1.5 rounded-lg border transition-all ${
                page === 1
                  ? 'border-gray-200 text-gray-300 cursor-not-allowed bg-gray-50'
                  : 'border-gray-300 text-gray-600 hover:bg-gray-100 hover:text-gray-800 bg-white'
              }`}
              title="Trang trước"
            >
              <FiChevronLeft size={16} />
            </button>
            
            <span className="text-xs text-gray-600 font-medium select-none">
              Trang {page} / {totalPages}
            </span>

            <button
              onClick={handleNext}
              disabled={page === totalPages}
              className={`p-1.5 rounded-lg border transition-all ${
                page === totalPages
                  ? 'border-gray-200 text-gray-300 cursor-not-allowed bg-gray-50'
                  : 'border-gray-300 text-gray-600 hover:bg-gray-100 hover:text-gray-800 bg-white'
              }`}
              title="Trang sau"
            >
              <FiChevronRight size={16} />
            </button>
          </div>
        </div>
      </div>
    </div>
  );
}

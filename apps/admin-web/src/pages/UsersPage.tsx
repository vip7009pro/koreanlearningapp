import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query';
import { usersApi } from '../lib/api';
import toast from 'react-hot-toast';
import { FiTrash2 } from 'react-icons/fi';

export default function UsersPage() {
  const queryClient = useQueryClient();

  const { data: users, isLoading } = useQuery({
    queryKey: ['users'],
    queryFn: () => usersApi.getAll().then((r) => r.data.data),
  });

  const deleteMut = useMutation({
    mutationFn: (id: string) => usersApi.delete(id),
    onSuccess: () => { queryClient.invalidateQueries({ queryKey: ['users'] }); toast.success('User deleted'); },
  });

  if (isLoading) return <div className="text-center py-12 text-gray-500">Loading...</div>;

  return (
    <div>
      <h1 className="text-2xl font-bold text-gray-800 mb-6">Users</h1>
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
      </div>
    </div>
  );
}

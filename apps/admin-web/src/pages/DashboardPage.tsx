import { useQuery } from '@tanstack/react-query';
import { analyticsApi } from '../lib/api';
import { FiUsers, FiBook, FiFileText, FiType, FiStar } from 'react-icons/fi';

export default function DashboardPage() {
  const { data, isLoading } = useQuery({
    queryKey: ['dashboard'],
    queryFn: () => analyticsApi.getDashboard().then((r) => r.data),
  });

  if (isLoading) return <div className="text-center py-12 text-gray-500">Loading dashboard...</div>;

  const stats = [
    { label: 'Total Users', value: data?.totalUsers || 0, icon: <FiUsers />, color: 'bg-blue-100 text-blue-600' },
    { label: 'Total Courses', value: data?.totalCourses || 0, icon: <FiBook />, color: 'bg-green-100 text-green-600' },
    { label: 'Total Lessons', value: data?.totalLessons || 0, icon: <FiFileText />, color: 'bg-purple-100 text-purple-600' },
    { label: 'Total Vocabulary', value: data?.totalVocab || 0, icon: <FiType />, color: 'bg-orange-100 text-orange-600' },
    { label: 'Active Subscriptions', value: data?.activeSubscriptions || 0, icon: <FiStar />, color: 'bg-yellow-100 text-yellow-600' },
  ];

  return (
    <div>
      <h1 className="text-2xl font-bold text-gray-800 mb-6">Dashboard</h1>

      <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-5 gap-4 mb-8">
        {stats.map((stat) => (
          <div key={stat.label} className="stat-card">
            <div className={`stat-icon ${stat.color}`}>{stat.icon}</div>
            <div>
              <p className="text-2xl font-bold text-gray-800">{stat.value}</p>
              <p className="text-xs text-gray-500">{stat.label}</p>
            </div>
          </div>
        ))}
      </div>

      <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
        <div className="card">
          <h2 className="text-lg font-semibold text-gray-800 mb-4">Top Learners</h2>
          <div className="space-y-3">
            {data?.topLearners?.map((user: { id: string; displayName: string; totalXP: number; streakDays: number }, i: number) => (
              <div key={user.id} className="flex items-center gap-3 p-2 rounded-lg hover:bg-gray-50">
                <span className="text-lg font-bold text-gray-400 w-6">#{i + 1}</span>
                <div className="flex-1">
                  <p className="text-sm font-medium text-gray-800">{user.displayName}</p>
                  <p className="text-xs text-gray-500">{user.totalXP} XP · {user.streakDays} day streak</p>
                </div>
              </div>
            ))}
          </div>
        </div>

        <div className="card">
          <h2 className="text-lg font-semibold text-gray-800 mb-4">Event Activity</h2>
          <div className="space-y-3">
            {data?.recentEvents?.map((event: { eventType: string; count: number }) => (
              <div key={event.eventType} className="flex items-center justify-between p-2">
                <span className="text-sm text-gray-700">{event.eventType}</span>
                <span className="badge badge-blue">{event.count}</span>
              </div>
            ))}
            {(!data?.recentEvents || data.recentEvents.length === 0) && (
              <p className="text-sm text-gray-400 text-center py-4">No events yet</p>
            )}
          </div>
        </div>
      </div>
    </div>
  );
}

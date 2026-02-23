import { Outlet, NavLink, useNavigate } from 'react-router-dom';
import { useAuthStore } from '../stores/authStore';
import { FiHome, FiBook, FiUsers, FiLogOut, FiMenu, FiFileText } from 'react-icons/fi';
import { useState } from 'react';

export default function Layout() {
  const { user, logout } = useAuthStore();
  const navigate = useNavigate();
  const [sidebarOpen, setSidebarOpen] = useState(true);

  const handleLogout = () => {
    logout();
    navigate('/login');
  };

  const navItems = [
    { to: '/', icon: <FiHome size={20} />, label: 'Dashboard' },
    { to: '/courses', icon: <FiBook size={20} />, label: 'Courses' },
    { to: '/topik', icon: <FiFileText size={20} />, label: 'TOPIK' },
    { to: '/users', icon: <FiUsers size={20} />, label: 'Users' },
  ];

  return (
    <div className="flex h-screen bg-gray-50">
      {/* Sidebar */}
      <aside className={`${sidebarOpen ? 'w-64' : 'w-20'} bg-white border-r border-gray-200 flex flex-col transition-all duration-300`}>
        <div className="p-4 border-b border-gray-100 flex items-center gap-3">
          <span className="text-2xl">🇰🇷</span>
          {sidebarOpen && <h1 className="text-lg font-bold text-gray-800">Korean Admin</h1>}
        </div>

        <nav className="flex-1 p-4 space-y-1">
          {navItems.map((item) => (
            <NavLink
              key={item.to}
              to={item.to}
              end={item.to === '/'}
              className={({ isActive }) => `sidebar-link ${isActive ? 'active' : ''}`}
            >
              {item.icon}
              {sidebarOpen && <span>{item.label}</span>}
            </NavLink>
          ))}
        </nav>

        <div className="p-4 border-t border-gray-100">
          {sidebarOpen && (
            <div className="mb-3 px-2">
              <p className="text-sm font-medium text-gray-800">{user?.displayName}</p>
              <p className="text-xs text-gray-500">{user?.email}</p>
            </div>
          )}
          <button onClick={handleLogout} className="sidebar-link w-full text-red-500 hover:bg-red-50 hover:text-red-600">
            <FiLogOut size={20} />
            {sidebarOpen && <span>Logout</span>}
          </button>
        </div>
      </aside>

      {/* Main Content */}
      <main className="flex-1 overflow-auto">
        <header className="bg-white border-b border-gray-200 px-6 py-4 flex items-center gap-4">
          <button onClick={() => setSidebarOpen(!sidebarOpen)} className="text-gray-500 hover:text-gray-700">
            <FiMenu size={20} />
          </button>
        </header>
        <div className="p-6">
          <Outlet />
        </div>
      </main>
    </div>
  );
}

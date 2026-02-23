import { Routes, Route, Navigate } from 'react-router-dom';
import { useAuthStore } from './stores/authStore';
import Layout from './components/Layout';
import LoginPage from './pages/LoginPage';
import DashboardPage from './pages/DashboardPage';
import CoursesPage from './pages/CoursesPage';
import CourseDetailPage from './pages/CourseDetailPage';
import LessonDetailPage from './pages/LessonDetailPage';
import UsersPage from './pages/UsersPage';
import TopikPage from './pages/TopikPage';
import TopikExamEditorPage from './pages/TopikExamEditorPage';

function ProtectedRoute({ children }: { children: React.ReactNode }) {
  const isAuthenticated = useAuthStore((s) => s.isAuthenticated);
  if (!isAuthenticated) return <Navigate to="/login" replace />;
  return <>{children}</>;
}

export default function App() {
  return (
    <Routes>
      <Route path="/login" element={<LoginPage />} />
      <Route path="/" element={<ProtectedRoute><Layout /></ProtectedRoute>}>
        <Route index element={<DashboardPage />} />
        <Route path="courses" element={<CoursesPage />} />
        <Route path="courses/:courseId" element={<CourseDetailPage />} />
        <Route path="lessons/:lessonId" element={<LessonDetailPage />} />
        <Route path="users" element={<UsersPage />} />
        <Route path="topik" element={<TopikPage />} />
        <Route path="topik/exams/:examId" element={<TopikExamEditorPage />} />
      </Route>
    </Routes>
  );
}

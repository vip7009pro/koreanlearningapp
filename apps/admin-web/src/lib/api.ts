import axios from 'axios';
import { useAuthStore } from '../stores/authStore';

const API_BASE = import.meta.env.VITE_API_URL || '/api';

const api = axios.create({
  baseURL: API_BASE,
  headers: { 'Content-Type': 'application/json' },
});

api.interceptors.request.use((config) => {
  const token = useAuthStore.getState().token;
  if (token) {
    config.headers.Authorization = `Bearer ${token}`;
  }
  return config;
});

api.interceptors.response.use(
  (response) => response,
  (error) => {
    if (error.response?.status === 401) {
      useAuthStore.getState().logout();
      window.location.href = '/login';
    }
    return Promise.reject(error);
  },
);

// Auth
export const authApi = {
  login: (email: string, password: string) => api.post('/auth/login', { email, password }),
  profile: () => api.get('/auth/profile'),
};

// AI (Admin)
export const aiAdminApi = {
  generateVocabulary: (lessonId: string, count: number, model?: string) =>
    api.post(`/ai/admin/lessons/${lessonId}/generate-vocabulary`, {}, {
      params: { count, model },
    }),
  generateGrammar: (lessonId: string, count: number, model?: string) =>
    api.post(`/ai/admin/lessons/${lessonId}/generate-grammar`, {}, {
      params: { count, model },
    }),
  generateDialogues: (lessonId: string, count: number, model?: string) =>
    api.post(`/ai/admin/lessons/${lessonId}/generate-dialogues`, {}, {
      params: { count, model },
    }),
  generateQuizzes: (lessonId: string, count: number, model?: string) =>
    api.post(`/ai/admin/lessons/${lessonId}/generate-quizzes`, {}, {
      params: { count, model },
    }),
  generateTopikExam: (data: Record<string, unknown>, model?: string) =>
    api.post('/ai/admin/topik/generate-exam', data, {
      params: { model },
    }),
};

export const topikAdminApi = {
  importExam: (payload: any) => api.post('/topik/admin/import', { payload }),
  listExams: () => api.get('/topik/admin/exams'),
  getExam: (id: string) => api.get(`/topik/admin/exams/${id}`),
  updateExam: (id: string, data: Record<string, unknown>) => api.patch(`/topik/admin/exams/${id}`, data),
  publishExam: (id: string) => api.post(`/topik/admin/exams/${id}/publish`),
  unpublishExam: (id: string) => api.post(`/topik/admin/exams/${id}/unpublish`),
  deleteExam: (id: string) => api.delete(`/topik/admin/exams/${id}`),
  updateSection: (id: string, data: Record<string, unknown>) => api.patch(`/topik/admin/sections/${id}`, data),
  updateQuestion: (id: string, data: Record<string, unknown>) => api.patch(`/topik/admin/questions/${id}`, data),
};

// Courses
export const coursesApi = {
  getAll: (params?: Record<string, unknown>) => api.get('/courses', { params }),
  getOne: (id: string) => api.get(`/courses/${id}`),
  create: (data: Record<string, unknown>) => api.post('/courses', data),
  update: (id: string, data: Record<string, unknown>) => api.patch(`/courses/${id}`, data),
  delete: (id: string) => api.delete(`/courses/${id}`),
  publish: (id: string) => api.post(`/courses/${id}/publish`),
  unpublish: (id: string) => api.post(`/courses/${id}/unpublish`),
  importCourse: (data: any) => api.post('/courses/import', data),
};

// Sections
export const sectionsApi = {
  getByCourse: (courseId: string) => api.get('/sections', { params: { courseId } }),
  create: (data: Record<string, unknown>) => api.post('/sections', data),
  update: (id: string, data: Record<string, unknown>) => api.patch(`/sections/${id}`, data),
  delete: (id: string) => api.delete(`/sections/${id}`),
};

// Lessons
export const lessonsApi = {
  getBySection: (sectionId: string) => api.get('/lessons', { params: { sectionId } }),
  getOne: (id: string) => api.get(`/lessons/${id}`),
  create: (data: Record<string, unknown>) => api.post('/lessons', data),
  update: (id: string, data: Record<string, unknown>) => api.patch(`/lessons/${id}`, data),
  delete: (id: string) => api.delete(`/lessons/${id}`),
};

// Vocabulary
export const vocabularyApi = {
  getByLesson: (lessonId: string, params?: Record<string, unknown>) => api.get('/vocabulary', { params: { lessonId, ...params } }),
  create: (data: Record<string, unknown>) => api.post('/vocabulary', data),
  createBulk: (data: Record<string, unknown>[]) => api.post('/vocabulary/bulk', data),
  update: (id: string, data: Record<string, unknown>) => api.patch(`/vocabulary/${id}`, data),
  delete: (id: string) => api.delete(`/vocabulary/${id}`),
  bulkDelete: (ids: string[]) => api.post('/vocabulary/bulk-delete', { ids }),
};

// Grammar
export const grammarApi = {
  getByLesson: (lessonId: string) => api.get('/grammar', { params: { lessonId } }),
  create: (data: Record<string, unknown>) => api.post('/grammar', data),
  update: (id: string, data: Record<string, unknown>) => api.patch(`/grammar/${id}`, data),
  delete: (id: string) => api.delete(`/grammar/${id}`),
  bulkDelete: (ids: string[]) => api.post('/grammar/bulk-delete', { ids }),
};

// Dialogues
export const dialoguesApi = {
  getByLesson: (lessonId: string) => api.get('/dialogues', { params: { lessonId } }),
  create: (data: Record<string, unknown>) => api.post('/dialogues', data),
  update: (id: string, data: Record<string, unknown>) => api.patch(`/dialogues/${id}`, data),
  delete: (id: string) => api.delete(`/dialogues/${id}`),
  bulkDelete: (ids: string[]) => api.post('/dialogues/bulk-delete', { ids }),
};

// Quizzes
export const quizzesApi = {
  getByLesson: (lessonId: string) => api.get('/quizzes', { params: { lessonId } }),
  create: (data: Record<string, unknown>) => api.post('/quizzes', data),
  update: (id: string, data: Record<string, unknown>) => api.patch(`/quizzes/${id}`, data),
  delete: (id: string) => api.delete(`/quizzes/${id}`),
  bulkDelete: (ids: string[]) => api.post('/quizzes/bulk-delete', { ids }),
  createQuestion: (data: Record<string, unknown>) => api.post('/quizzes/questions', data),
  updateQuestion: (id: string, data: Record<string, unknown>) => api.patch(`/quizzes/questions/${id}`, data),
  deleteQuestion: (id: string) => api.delete(`/quizzes/questions/${id}`),
};

// Users
export const usersApi = {
  getAll: (params?: Record<string, unknown>) => api.get('/users', { params }),
  getOne: (id: string) => api.get(`/users/${id}`),
  update: (id: string, data: Record<string, unknown>) => api.patch(`/users/${id}`, data),
  delete: (id: string) => api.delete(`/users/${id}`),
};

// Analytics
export const analyticsApi = {
  getDashboard: () => api.get('/analytics/dashboard'),
};

// Upload
export const uploadApi = {
  uploadAudio: (file: File) => {
    const form = new FormData();
    form.append('file', file);
    return api.post('/upload/audio', form, { headers: { 'Content-Type': 'multipart/form-data' } });
  },
  uploadImage: (file: File) => {
    const form = new FormData();
    form.append('file', file);
    return api.post('/upload/image', form, { headers: { 'Content-Type': 'multipart/form-data' } });
  },
};

export default api;

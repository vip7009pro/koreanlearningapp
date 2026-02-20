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

// Courses
export const coursesApi = {
  getAll: (params?: Record<string, unknown>) => api.get('/courses', { params }),
  getOne: (id: string) => api.get(`/courses/${id}`),
  create: (data: Record<string, unknown>) => api.post('/courses', data),
  update: (id: string, data: Record<string, unknown>) => api.patch(`/courses/${id}`, data),
  delete: (id: string) => api.delete(`/courses/${id}`),
  publish: (id: string) => api.post(`/courses/${id}/publish`),
  unpublish: (id: string) => api.post(`/courses/${id}/unpublish`),
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
};

// Grammar
export const grammarApi = {
  getByLesson: (lessonId: string) => api.get('/grammar', { params: { lessonId } }),
  create: (data: Record<string, unknown>) => api.post('/grammar', data),
  update: (id: string, data: Record<string, unknown>) => api.patch(`/grammar/${id}`, data),
  delete: (id: string) => api.delete(`/grammar/${id}`),
};

// Dialogues
export const dialoguesApi = {
  getByLesson: (lessonId: string) => api.get('/dialogues', { params: { lessonId } }),
  create: (data: Record<string, unknown>) => api.post('/dialogues', data),
  update: (id: string, data: Record<string, unknown>) => api.patch(`/dialogues/${id}`, data),
  delete: (id: string) => api.delete(`/dialogues/${id}`),
};

// Quizzes
export const quizzesApi = {
  getByLesson: (lessonId: string) => api.get('/quizzes', { params: { lessonId } }),
  create: (data: Record<string, unknown>) => api.post('/quizzes', data),
  update: (id: string, data: Record<string, unknown>) => api.patch(`/quizzes/${id}`, data),
  delete: (id: string) => api.delete(`/quizzes/${id}`),
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

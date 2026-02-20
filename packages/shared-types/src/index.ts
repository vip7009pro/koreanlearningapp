export enum UserRole {
  USER = 'USER',
  ADMIN = 'ADMIN',
}

export enum PlanType {
  FREE = 'FREE',
  PREMIUM = 'PREMIUM',
  LIFETIME = 'LIFETIME',
}

export enum SubscriptionStatus {
  ACTIVE = 'ACTIVE',
  EXPIRED = 'EXPIRED',
  CANCELLED = 'CANCELLED',
}

export enum QuizType {
  MULTIPLE_CHOICE = 'MULTIPLE_CHOICE',
  FILL_IN_BLANK = 'FILL_IN_BLANK',
  LISTENING = 'LISTENING',
  MATCHING = 'MATCHING',
}

export enum QuestionType {
  MULTIPLE_CHOICE = 'MULTIPLE_CHOICE',
  TRUE_FALSE = 'TRUE_FALSE',
  FILL_IN_BLANK = 'FILL_IN_BLANK',
  AUDIO = 'AUDIO',
}

export enum CourseLevel {
  BEGINNER = 'BEGINNER',
  INTERMEDIATE = 'INTERMEDIATE',
  ADVANCED = 'ADVANCED',
}

export enum Difficulty {
  EASY = 'EASY',
  MEDIUM = 'MEDIUM',
  HARD = 'HARD',
}

export enum EventType {
  LESSON_STARTED = 'LESSON_STARTED',
  LESSON_COMPLETED = 'LESSON_COMPLETED',
  QUIZ_COMPLETED = 'QUIZ_COMPLETED',
  VOCABULARY_REVIEWED = 'VOCABULARY_REVIEWED',
  WRITING_PRACTICED = 'WRITING_PRACTICED',
  SPEAKING_PRACTICED = 'SPEAKING_PRACTICED',
  LOGIN = 'LOGIN',
  STREAK_UPDATED = 'STREAK_UPDATED',
  BADGE_EARNED = 'BADGE_EARNED',
  XP_EARNED = 'XP_EARNED',
}

export interface UserDto {
  id: string;
  email: string;
  displayName: string;
  avatarUrl: string | null;
  role: UserRole;
  totalXP: number;
  streakDays: number;
  createdAt: string;
}

export interface CourseDto {
  id: string;
  title: string;
  description: string;
  level: CourseLevel;
  isPremium: boolean;
  thumbnailUrl: string | null;
  sections: SectionDto[];
}

export interface SectionDto {
  id: string;
  courseId: string;
  title: string;
  orderIndex: number;
  lessons: LessonDto[];
}

export interface LessonDto {
  id: string;
  sectionId: string;
  title: string;
  description: string;
  orderIndex: number;
  estimatedMinutes: number;
}

export interface VocabularyDto {
  id: string;
  lessonId: string;
  korean: string;
  vietnamese: string;
  pronunciation: string;
  exampleSentence: string;
  exampleMeaning: string;
  audioUrl: string | null;
  difficulty: Difficulty;
}

export interface GrammarDto {
  id: string;
  lessonId: string;
  pattern: string;
  explanationVN: string;
  example: string;
}

export interface DialogueDto {
  id: string;
  lessonId: string;
  speaker: string;
  koreanText: string;
  vietnameseText: string;
  audioUrl: string | null;
  orderIndex: number;
}

export interface QuizDto {
  id: string;
  lessonId: string;
  title: string;
  quizType: QuizType;
  questions: QuestionDto[];
}

export interface QuestionDto {
  id: string;
  quizId: string;
  questionType: QuestionType;
  questionText: string;
  audioUrl: string | null;
  correctAnswer: string;
  options: OptionDto[];
}

export interface OptionDto {
  id: string;
  questionId: string;
  text: string;
  isCorrect: boolean;
}

export interface UserProgressDto {
  id: string;
  userId: string;
  lessonId: string;
  completed: boolean;
  score: number;
  completedAt: string | null;
}

export interface SubscriptionDto {
  id: string;
  userId: string;
  planType: PlanType;
  startDate: string;
  endDate: string | null;
  status: SubscriptionStatus;
}

export interface UserVocabularyReviewDto {
  id: string;
  userId: string;
  vocabularyId: string;
  reviewLevel: number;
  nextReviewAt: string;
  correctStreak: number;
  wrongCount: number;
}

export interface AIWritingPracticeDto {
  id: string;
  userId: string;
  prompt: string;
  userAnswer: string;
  aiFeedback: string | null;
  score: number | null;
}

export interface AnalyticsEventDto {
  id: string;
  userId: string;
  eventType: EventType;
  metadata: Record<string, unknown>;
  createdAt: string;
}

export interface BadgeDto {
  id: string;
  name: string;
  description: string;
  iconUrl: string;
  requiredXP: number;
}

export interface UserBadgeDto {
  id: string;
  userId: string;
  badgeId: string;
  earnedAt: string;
}

export interface LeaderboardEntryDto {
  userId: string;
  displayName: string;
  avatarUrl: string | null;
  totalXP: number;
  rank: number;
}

export interface DailyGoalDto {
  id: string;
  userId: string;
  targetXP: number;
  currentXP: number;
  date: string;
  completed: boolean;
}

export interface LoginRequestDto {
  email: string;
  password: string;
}

export interface RegisterRequestDto {
  email: string;
  password: string;
  displayName: string;
}

export interface AuthResponseDto {
  accessToken: string;
  refreshToken: string;
  user: UserDto;
}

export interface PaginatedResponseDto<T> {
  data: T[];
  total: number;
  page: number;
  limit: number;
  totalPages: number;
}

export interface ApiResponseDto<T> {
  success: boolean;
  data: T;
  message: string;
}

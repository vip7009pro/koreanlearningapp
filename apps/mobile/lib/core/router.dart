import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/foundation.dart';
import 'package:go_router/go_router.dart';
import '../screens/splash_screen.dart';
import '../screens/login_screen.dart';
import '../screens/home_screen.dart';
import '../screens/course_detail_screen.dart';
import '../screens/lesson_detail_screen.dart';
import '../screens/quiz_screen.dart';
import '../screens/profile_screen.dart';
import '../screens/subscription_screen.dart';
import '../screens/ai_writing_screen.dart';
import '../screens/leaderboard_screen.dart';
import '../screens/review_screen.dart';
import '../screens/writing_history_screen.dart';
import '../screens/writing_detail_screen.dart';
import '../screens/settings_screen.dart';
import '../screens/theme_picker_screen.dart';
import '../screens/admin/admin_home_screen.dart';
import '../screens/admin/admin_dashboard_screen.dart';
import '../screens/admin/admin_courses_screen.dart';
import '../screens/admin/admin_course_detail_screen.dart';
import '../screens/admin/admin_course_form_screen.dart';
import '../screens/admin/admin_lesson_detail_screen.dart';
import '../screens/admin/admin_users_screen.dart';
import '../screens/admin/admin_upload_screen.dart';
import '../providers/auth_provider.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final authRefresh = ValueNotifier<int>(0);
  ref.onDispose(authRefresh.dispose);
  ref.listen<AuthState>(authProvider, (_, __) {
    authRefresh.value++;
  });

  return GoRouter(
    initialLocation: '/splash',
    refreshListenable: authRefresh,
    redirect: (context, state) {
      final isLoggedIn = ref.read(authProvider).isAuthenticated;
      final loggingIn = state.matchedLocation == '/login';
      final isSplash = state.matchedLocation == '/splash';

      if (isSplash) return null;
      if (!isLoggedIn && !loggingIn) return '/login';
      if (isLoggedIn && loggingIn) return '/';
      return null;
    },
    routes: [
      GoRoute(path: '/splash', builder: (_, __) => const SplashScreen()),
      GoRoute(path: '/login', builder: (_, __) => const LoginScreen()),
      GoRoute(path: '/', builder: (_, __) => const HomeScreen()),
      GoRoute(
        path: '/course/:courseId',
        builder: (_, state) =>
            CourseDetailScreen(courseId: state.pathParameters['courseId']!),
      ),
      GoRoute(
        path: '/lesson/:lessonId',
        builder: (_, state) =>
            LessonDetailScreen(lessonId: state.pathParameters['lessonId']!),
      ),
      GoRoute(
        path: '/quiz/:quizId',
        builder: (_, state) =>
            QuizScreen(quizId: state.pathParameters['quizId']!),
      ),
      GoRoute(path: '/profile', builder: (_, __) => const ProfileScreen()),
      GoRoute(
          path: '/subscription',
          builder: (_, __) => const SubscriptionScreen()),
      GoRoute(
          path: '/ai-practice', builder: (_, __) => const AiWritingScreen()),
      GoRoute(
          path: '/leaderboard', builder: (_, __) => const LeaderboardScreen()),
      GoRoute(path: '/review', builder: (_, __) => const ReviewScreen()),
      GoRoute(path: '/settings', builder: (_, __) => const SettingsScreen()),
      GoRoute(
        path: '/settings/theme',
        builder: (_, __) => const ThemePickerScreen(),
      ),
      GoRoute(
          path: '/writing-history',
          builder: (_, __) => const WritingHistoryScreen()),
      GoRoute(
        path: '/writing-detail',
        builder: (_, state) =>
            WritingDetailScreen(item: state.extra as Map<String, dynamic>),
      ),
      GoRoute(path: '/admin', builder: (_, __) => const AdminHomeScreen()),
      GoRoute(
          path: '/admin/dashboard',
          builder: (_, __) => const AdminDashboardScreen()),
      GoRoute(
          path: '/admin/courses',
          builder: (_, __) => const AdminCoursesScreen()),
      GoRoute(
        path: '/admin/courses/new',
        builder: (_, __) => const AdminCourseFormScreen(),
      ),
      GoRoute(
        path: '/admin/courses/:courseId',
        builder: (_, state) => AdminCourseDetailScreen(
          courseId: state.pathParameters['courseId']!,
        ),
      ),
      GoRoute(
        path: '/admin/courses/:courseId/edit',
        builder: (_, state) => AdminCourseFormScreen(
          courseId: state.pathParameters['courseId']!,
        ),
      ),
      GoRoute(
        path: '/admin/lessons/:lessonId',
        builder: (_, state) => AdminLessonDetailScreen(
          lessonId: state.pathParameters['lessonId']!,
        ),
      ),
      GoRoute(
          path: '/admin/users', builder: (_, __) => const AdminUsersScreen()),
      GoRoute(
          path: '/admin/upload', builder: (_, __) => const AdminUploadScreen()),
    ],
  );
});

import 'package:flutter_riverpod/flutter_riverpod.dart';
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
import '../providers/auth_provider.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final auth = ref.watch(authProvider);

  return GoRouter(
    initialLocation: '/splash',
    redirect: (context, state) {
      final isLoggedIn = auth.isAuthenticated;
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
      GoRoute(
          path: '/writing-history',
          builder: (_, __) => const WritingHistoryScreen()),
      GoRoute(
        path: '/writing-detail',
        builder: (_, state) =>
            WritingDetailScreen(item: state.extra as Map<String, dynamic>),
      ),
    ],
  );
});

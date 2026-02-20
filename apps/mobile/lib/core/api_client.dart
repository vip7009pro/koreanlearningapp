import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final apiClientProvider = Provider<ApiClient>((ref) {
  return ApiClient();
});

class ApiClient {
  late final Dio _dio;
  String? _token;

  ApiClient() {
    _dio = Dio(
      BaseOptions(
        //baseUrl: 'http://10.0.2.2:3000/api', // Android emulator -> host
        baseUrl: 'http://14.160.33.94:3000/api', // Android emulator -> host
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 10),
        headers: {'Content-Type': 'application/json'},
      ),
    );

    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          if (_token != null) {
            options.headers['Authorization'] = 'Bearer $_token';
          }
          handler.next(options);
        },
      ),
    );
  }

  void setToken(String? token) => _token = token;

  // Auth
  Future<Response> login(String email, String password) =>
      _dio.post('/auth/login', data: {'email': email, 'password': password});

  Future<Response> register(
    String email,
    String password,
    String displayName,
  ) =>
      _dio.post(
        '/auth/register',
        data: {
          'email': email,
          'password': password,
          'displayName': displayName
        },
      );

  Future<Response> getProfile() => _dio.get('/auth/profile');

  // Courses
  Future<Response> getCourses({String? level, bool? published}) => _dio.get(
        '/courses',
        queryParameters: {'level': level, 'published': published},
      );

  Future<Response> getCourse(String id) => _dio.get('/courses/$id');

  // Sections
  Future<Response> getSections(String courseId) =>
      _dio.get('/sections', queryParameters: {'courseId': courseId});

  // Lessons
  Future<Response> getLesson(String id) => _dio.get('/lessons/$id');
  Future<Response> getLessons(String sectionId) =>
      _dio.get('/lessons', queryParameters: {'sectionId': sectionId});

  // Vocabulary
  Future<Response> getVocabulary(String lessonId) =>
      _dio.get('/vocabulary', queryParameters: {'lessonId': lessonId});

  // Grammar
  Future<Response> getGrammar(String lessonId) =>
      _dio.get('/grammar', queryParameters: {'lessonId': lessonId});

  // Dialogues
  Future<Response> getDialogues(String lessonId) =>
      _dio.get('/dialogues', queryParameters: {'lessonId': lessonId});

  // Quizzes
  Future<Response> getQuizzes(String lessonId) =>
      _dio.get('/quizzes', queryParameters: {'lessonId': lessonId});

  Future<Response> submitQuiz(
    String quizId,
    List<Map<String, dynamic>> answers,
  ) =>
      _dio.post('/quizzes/$quizId/submit', data: {'answers': answers});

  // Progress
  Future<Response> updateProgress(
    String lessonId, {
    bool? completed,
    int? score,
  }) =>
      _dio.post(
        '/progress',
        data: {'lessonId': lessonId, 'completed': completed, 'score': score},
      );

  Future<Response> getCourseProgress(String courseId) =>
      _dio.get('/progress/course/$courseId');

  // Reviews (SRS)
  Future<Response> getDueReviews() => _dio.get('/reviews/due');
  Future<Response> submitReview(String vocabId, bool correct) => _dio.post(
        '/reviews/submit',
        data: {'vocabularyId': vocabId, 'correct': correct},
      );
  Future<Response> getReviewStats() => _dio.get('/reviews/stats');

  // Gamification
  Future<Response> getLeaderboard() => _dio.get('/gamification/leaderboard');
  Future<Response> addXP(int amount) =>
      _dio.post('/gamification/xp', data: {'amount': amount});
  Future<Response> updateStreak() => _dio.post('/gamification/streak');
  Future<Response> getDailyGoal() => _dio.get('/gamification/daily-goal');
  Future<Response> getUserBadges() => _dio.get('/gamification/badges');

  // Subscriptions
  Future<Response> getPlans() => _dio.get('/subscriptions/plans');
  Future<Response> subscribe(String planType) =>
      _dio.post('/subscriptions', data: {'planType': planType});
  Future<Response> checkPremium() => _dio.get('/subscriptions/check-premium');
}

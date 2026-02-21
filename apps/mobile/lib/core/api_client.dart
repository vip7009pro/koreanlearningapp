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
        connectTimeout: const Duration(seconds: 100),
        receiveTimeout: const Duration(seconds: 100),
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

  String absoluteUrl(String? url) {
    if (url == null || url.isEmpty) return '';
    if (url.startsWith('http://') || url.startsWith('https://')) return url;

    final base = _dio.options.baseUrl;
    final host = base.endsWith('/api')
        ? base.substring(0, base.length - 4)
        : (base.endsWith('/api/') ? base.substring(0, base.length - 5) : base);

    return '$host$url';
  }

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

  Future<Response> createCourse(Map<String, dynamic> data) =>
      _dio.post('/courses', data: data);
  Future<Response> updateCourse(String id, Map<String, dynamic> data) =>
      _dio.patch('/courses/$id', data: data);
  Future<Response> deleteCourse(String id) => _dio.delete('/courses/$id');
  Future<Response> publishCourse(String id) =>
      _dio.post('/courses/$id/publish');
  Future<Response> unpublishCourse(String id) =>
      _dio.post('/courses/$id/unpublish');
  Future<Response> importCourse(Map<String, dynamic> data) =>
      _dio.post('/courses/import', data: data);

  // Sections
  Future<Response> getSections(String courseId) =>
      _dio.get('/sections', queryParameters: {'courseId': courseId});

  Future<Response> createSection(Map<String, dynamic> data) =>
      _dio.post('/sections', data: data);
  Future<Response> updateSection(String id, Map<String, dynamic> data) =>
      _dio.patch('/sections/$id', data: data);
  Future<Response> deleteSection(String id) => _dio.delete('/sections/$id');

  // Lessons
  Future<Response> getLesson(String id) => _dio.get('/lessons/$id');
  Future<Response> getLessons(String sectionId) =>
      _dio.get('/lessons', queryParameters: {'sectionId': sectionId});

  Future<Response> createLesson(Map<String, dynamic> data) =>
      _dio.post('/lessons', data: data);
  Future<Response> updateLesson(String id, Map<String, dynamic> data) =>
      _dio.patch('/lessons/$id', data: data);
  Future<Response> deleteLesson(String id) => _dio.delete('/lessons/$id');

  // Vocabulary
  Future<Response> getVocabulary(String lessonId) =>
      _dio.get('/vocabulary', queryParameters: {'lessonId': lessonId});

  Future<Response> createVocabulary(Map<String, dynamic> data) =>
      _dio.post('/vocabulary', data: data);
  Future<Response> updateVocabulary(String id, Map<String, dynamic> data) =>
      _dio.patch('/vocabulary/$id', data: data);
  Future<Response> deleteVocabulary(String id) =>
      _dio.delete('/vocabulary/$id');
  Future<Response> createVocabularyBulk(List<Map<String, dynamic>> items) =>
      _dio.post('/vocabulary/bulk', data: items);

  // Grammar
  Future<Response> getGrammar(String lessonId) =>
      _dio.get('/grammar', queryParameters: {'lessonId': lessonId});

  Future<Response> createGrammar(Map<String, dynamic> data) =>
      _dio.post('/grammar', data: data);
  Future<Response> updateGrammar(String id, Map<String, dynamic> data) =>
      _dio.patch('/grammar/$id', data: data);
  Future<Response> deleteGrammar(String id) => _dio.delete('/grammar/$id');

  // Dialogues
  Future<Response> getDialogues(String lessonId) =>
      _dio.get('/dialogues', queryParameters: {'lessonId': lessonId});

  Future<Response> createDialogue(Map<String, dynamic> data) =>
      _dio.post('/dialogues', data: data);
  Future<Response> updateDialogue(String id, Map<String, dynamic> data) =>
      _dio.patch('/dialogues/$id', data: data);
  Future<Response> deleteDialogue(String id) => _dio.delete('/dialogues/$id');

  // Quizzes
  Future<Response> getQuizzes(String lessonId) =>
      _dio.get('/quizzes', queryParameters: {'lessonId': lessonId});

  Future<Response> getQuiz(String quizId) => _dio.get('/quizzes/$quizId');

  Future<Response> createQuiz(Map<String, dynamic> data) =>
      _dio.post('/quizzes', data: data);
  Future<Response> updateQuiz(String id, Map<String, dynamic> data) =>
      _dio.patch('/quizzes/$id', data: data);
  Future<Response> deleteQuiz(String id) => _dio.delete('/quizzes/$id');

  Future<Response> createQuizQuestion(Map<String, dynamic> data) =>
      _dio.post('/quizzes/questions', data: data);
  Future<Response> updateQuizQuestion(String id, Map<String, dynamic> data) =>
      _dio.patch('/quizzes/questions/$id', data: data);
  Future<Response> deleteQuizQuestion(String id) =>
      _dio.delete('/quizzes/questions/$id');

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

  Future<Response> getUserProgress() => _dio.get('/progress');

  Future<Response> getCourseProgress(String courseId) =>
      _dio.get('/progress/course/$courseId');

  // Reviews (SRS)
  Future<Response> getDueReviews() => _dio.get('/reviews/due');
  Future<Response> addToReview(String vocabId) =>
      _dio.post('/reviews/add', data: {'vocabularyId': vocabId});
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
  Future<Response> checkPremiumStatus() =>
      _dio.get('/subscriptions/check-premium');

  // AI
  Future<Response> correctWriting(String prompt, String userAnswer) =>
      _dio.post('/ai/writing-correction',
          data: {'prompt': prompt, 'userAnswer': userAnswer});
  Future<Response> getWritingHistory({int page = 1, int limit = 20}) =>
      _dio.get('/ai/writing-history',
          queryParameters: {'page': page, 'limit': limit});

  // AI (Admin)
  Future<Response> adminGenerateVocabulary(
    String lessonId, {
    int count = 10,
    String? model,
  }) =>
      _dio.post(
        '/ai/admin/lessons/$lessonId/generate-vocabulary',
        queryParameters: {'count': count, if (model != null) 'model': model},
      );
  Future<Response> adminGenerateGrammar(
    String lessonId, {
    int count = 5,
    String? model,
  }) =>
      _dio.post(
        '/ai/admin/lessons/$lessonId/generate-grammar',
        queryParameters: {'count': count, if (model != null) 'model': model},
      );
  Future<Response> adminGenerateDialogues(
    String lessonId, {
    int count = 10,
    String? model,
  }) =>
      _dio.post(
        '/ai/admin/lessons/$lessonId/generate-dialogues',
        queryParameters: {'count': count, if (model != null) 'model': model},
      );
  Future<Response> adminGenerateQuizzes(
    String lessonId, {
    int count = 1,
    String? model,
  }) =>
      _dio.post(
        '/ai/admin/lessons/$lessonId/generate-quizzes',
        queryParameters: {'count': count, if (model != null) 'model': model},
      );

  // Bulk delete (Admin)
  Future<Response> deleteVocabularyBulk(List<String> ids) =>
      _dio.post('/vocabulary/bulk-delete', data: {'ids': ids});
  Future<Response> deleteGrammarBulk(List<String> ids) =>
      _dio.post('/grammar/bulk-delete', data: {'ids': ids});
  Future<Response> deleteDialoguesBulk(List<String> ids) =>
      _dio.post('/dialogues/bulk-delete', data: {'ids': ids});
  Future<Response> deleteQuizzesBulk(List<String> ids) =>
      _dio.post('/quizzes/bulk-delete', data: {'ids': ids});

  // Profile
  Future<Response> updateMyProfile({String? displayName, String? avatarUrl}) =>
      _dio.patch('/auth/profile',
          data: {'displayName': displayName, 'avatarUrl': avatarUrl});

  Future<Response> uploadAvatar(String filePath) async {
    final form = FormData.fromMap({
      'file': await MultipartFile.fromFile(filePath),
    });
    return _dio.post(
      '/upload/avatar',
      data: form,
      options: Options(headers: {'Content-Type': 'multipart/form-data'}),
    );
  }

  // Admin
  Future<Response> getAdminDashboard() => _dio.get('/analytics/dashboard');

  // Users (Admin)
  Future<Response> getUsers({int page = 1, int limit = 20}) =>
      _dio.get('/users', queryParameters: {'page': page, 'limit': limit});
  Future<Response> updateUser(String id, Map<String, dynamic> data) =>
      _dio.patch('/users/$id', data: data);
  Future<Response> deleteUser(String id) => _dio.delete('/users/$id');

  // Upload (Admin)
  Future<Response> uploadImage(String filePath) async {
    final form = FormData.fromMap({
      'file': await MultipartFile.fromFile(filePath),
    });
    return _dio.post(
      '/upload/image',
      data: form,
      options: Options(headers: {'Content-Type': 'multipart/form-data'}),
    );
  }

  Future<Response> uploadAudio(String filePath) async {
    final form = FormData.fromMap({
      'file': await MultipartFile.fromFile(filePath),
    });
    return _dio.post(
      '/upload/audio',
      data: form,
      options: Options(headers: {'Content-Type': 'multipart/form-data'}),
    );
  }
}

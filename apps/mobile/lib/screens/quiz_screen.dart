import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/api_client.dart';

class QuizScreen extends ConsumerStatefulWidget {
  final String quizId;
  const QuizScreen({super.key, required this.quizId});

  @override
  ConsumerState<QuizScreen> createState() => _QuizScreenState();
}

class _QuizScreenState extends ConsumerState<QuizScreen> {
  int _currentQuestion = 0;
  final Map<String, String> _answers = {};
  bool _submitted = false;
  Map<String, dynamic>? _result;
  List<dynamic> _questions = [];
  String _quizTitle = '';
  bool _loading = true;
  String? _error;
  bool _reviewMode = false;

  @override
  void initState() {
    super.initState();
    _loadQuiz();
  }

  Future<void> _loadQuiz() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    final api = ref.read(apiClientProvider);
    try {
      final res = await api.getQuiz(widget.quizId);
      final data = res.data as Map<String, dynamic>;
      final questions = (data['questions'] as List?) ?? [];

      if (!mounted) return;
      setState(() {
        _quizTitle = (data['title'] ?? '').toString().trim();
        _questions = questions;
        _currentQuestion = 0;
        _answers.clear();
        _submitted = false;
        _reviewMode = false;
        _result = null;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Không tải được bài tập. Vui lòng thử lại.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_quizTitle.isNotEmpty ? _quizTitle : 'Bài kiểm tra'),
        actions: [
          if (!_submitted && _questions.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Center(
                child: Text(
                  '${_currentQuestion + 1}/${_questions.length}',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.error_outline,
                            size: 48, color: Colors.redAccent),
                        const SizedBox(height: 12),
                        Text(
                          _error!,
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 14),
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: _loadQuiz,
                          child: const Text('Thử lại'),
                        ),
                      ],
                    ),
                  ),
                )
              : _questions.isEmpty
                  ? const Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.quiz_outlined,
                              size: 64, color: Colors.grey),
                          SizedBox(height: 16),
                          Text(
                            'Chưa có câu hỏi cho bài tập này',
                            style: TextStyle(fontSize: 16, color: Colors.grey),
                          ),
                        ],
                      ),
                    )
                  : _submitted
                      ? (_reviewMode ? _buildReview() : _buildResults())
                      : _buildQuestion(),
    );
  }

  bool _isCorrect(dynamic question) {
    final qId = (question['id'] ?? '').toString();
    final userAnswer = _answers[qId];
    final correct = (question['correctAnswer'] ?? '').toString();
    if (userAnswer == null) return false;
    return userAnswer.trim() == correct.trim();
  }

  Widget _buildQuestion() {
    if (_questions.isEmpty) {
      return const SizedBox();
    }
    final q = _questions[_currentQuestion];
    final options = (q['options'] as List?) ?? [];

    final qId = (q['id'] ?? '').toString();
    final primary = Theme.of(context).colorScheme.primary;

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Progress bar
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: (_currentQuestion + 1) / _questions.length,
              minHeight: 6,
              backgroundColor: Colors.grey.shade200,
              valueColor: AlwaysStoppedAnimation(primary),
            ),
          ),
          const SizedBox(height: 24),

          Text(
            q['questionText'] ?? '',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 24),

          ...options.map<Widget>((opt) {
            final optText = (opt['text'] ?? '').toString().trim();
            final selected = _answers[qId] == optText;
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: InkWell(
                onTap: optText.isEmpty
                    ? null
                    : () => setState(() => _answers[qId] = optText),
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: selected ? primary : Colors.grey.shade300,
                      width: selected ? 2 : 1,
                    ),
                    color: selected ? primary.withValues(alpha: 0.05) : null,
                  ),
                  child: Text(
                    optText,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight:
                          selected ? FontWeight.w600 : FontWeight.normal,
                      color: selected ? primary : null,
                    ),
                  ),
                ),
              ),
            );
          }),

          const Spacer(),

          Row(
            children: [
              if (_currentQuestion > 0)
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => setState(() => _currentQuestion--),
                    child: const Text('Trước'),
                  ),
                ),
              if (_currentQuestion > 0) const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: _answers.containsKey(
                          (_questions[_currentQuestion]['id'] ?? '').toString())
                      ? () {
                          if (_currentQuestion < _questions.length - 1) {
                            setState(() => _currentQuestion++);
                          } else {
                            _submitQuiz();
                          }
                        }
                      : null,
                  child: Text(
                    _currentQuestion < _questions.length - 1
                        ? 'Tiếp theo'
                        : 'Nộp bài',
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildResults() {
    final score = _result?['score'] ?? 0;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(30),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                color: score >= 70
                    ? const Color(0xFF10B981).withValues(alpha: 0.1)
                    : Colors.orange.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(
                  score >= 70 ? '🎉' : '📝',
                  style: const TextStyle(fontSize: 50),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              '$score%',
              style: const TextStyle(fontSize: 48, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              score >= 70 ? 'Xuất sắc!' : 'Cần cố gắng thêm!',
              style: TextStyle(fontSize: 18, color: Colors.grey.shade600),
            ),
            const SizedBox(height: 30),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => setState(() => _reviewMode = true),
                icon: const Icon(Icons.fact_check_outlined),
                label: const Text('Xem lại bài đã làm'),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Quay lại'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReview() {
    return Column(
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color:
                Theme.of(context).colorScheme.primary.withValues(alpha: 0.08),
            border: Border(
              bottom: BorderSide(
                color: Colors.grey.shade200,
              ),
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  'Xem lại bài làm',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
              TextButton.icon(
                onPressed: () => setState(() => _reviewMode = false),
                icon: const Icon(Icons.arrow_back),
                label: const Text('Kết quả'),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: _questions.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (_, idx) {
              final q = _questions[idx];
              final qId = (q['id'] ?? '').toString();
              final userAnswer = _answers[qId];
              final correct = (q['correctAnswer'] ?? '').toString();
              final ok = _isCorrect(q);

              final borderColor =
                  ok ? const Color(0xFF10B981) : Colors.redAccent;

              return Card(
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: borderColor.withValues(alpha: 0.35),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: borderColor.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              'Câu ${idx + 1}',
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                color: borderColor,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Icon(
                            ok ? Icons.check_circle : Icons.cancel,
                            color: borderColor,
                            size: 18,
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Text(
                        (q['questionText'] ?? '').toString(),
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'Bạn chọn: ${userAnswer ?? '(chưa chọn)'}',
                        style: TextStyle(
                          color:
                              ok ? const Color(0xFF10B981) : Colors.redAccent,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Đáp án đúng: $correct',
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Future<void> _submitQuiz() async {
    final api = ref.read(apiClientProvider);

    final answers = _questions
        .map<Map<String, dynamic>>((q) {
          final qId = (q['id'] ?? '').toString();
          final a = _answers[qId];
          if (qId.isEmpty || a == null) return {};
          return {'questionId': qId, 'answer': a};
        })
        .where((x) => x.isNotEmpty)
        .toList();

    setState(() => _loading = true);
    try {
      final res = await api.submitQuiz(widget.quizId, answers);
      if (!mounted) return;
      setState(() {
        _submitted = true;
        _reviewMode = false;
        _result = (res.data as Map?)?.cast<String, dynamic>();
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nộp bài thất bại. Vui lòng thử lại.')),
      );
    }
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
  final List<dynamic> _questions = [];
  final String _quizTitle = '';

  @override
  void initState() {
    super.initState();
    _loadQuiz();
  }

  Future<void> _loadQuiz() async {
    // For now, load from the lesson detail API
    // In a real app, you'd have a dedicated quiz endpoint
    setState(() {});
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
      body: _questions.isEmpty
          ? const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.quiz_outlined, size: 64, color: Colors.grey),
                  SizedBox(height: 16),
                  Text(
                    'Bài kiểm tra sẽ sớm có',
                    style: TextStyle(fontSize: 16, color: Colors.grey),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Chức năng đang phát triển',
                    style: TextStyle(fontSize: 13, color: Colors.grey),
                  ),
                ],
              ),
            )
          : _submitted
              ? _buildResults()
              : _buildQuestion(),
    );
  }

  Widget _buildQuestion() {
    if (_questions.isEmpty) {
      return const SizedBox();
    }
    final q = _questions[_currentQuestion];
    final options = (q['options'] as List?) ?? [];

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
              valueColor: const AlwaysStoppedAnimation(Color(0xFF2563EB)),
            ),
          ),
          const SizedBox(height: 24),

          Text(
            q['questionText'] ?? '',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 24),

          ...options.map<Widget>((opt) {
            final selected = _answers[q['id']] == opt['text'];
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: InkWell(
                onTap: () => setState(() => _answers[q['id']] = opt['text']),
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: selected
                          ? const Color(0xFF2563EB)
                          : Colors.grey.shade300,
                      width: selected ? 2 : 1,
                    ),
                    color: selected
                        ? const Color(0xFF2563EB).withValues(alpha: 0.05)
                        : null,
                  ),
                  child: Text(
                    opt['text'] ?? '',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight:
                          selected ? FontWeight.w600 : FontWeight.normal,
                      color: selected ? const Color(0xFF2563EB) : null,
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
                  onPressed:
                      _answers.containsKey(_questions[_currentQuestion]['id'])
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

  Future<void> _submitQuiz() async {
    setState(() {
      _submitted = true;
      _result = {'score': 85};
    }); // Mock
  }
}

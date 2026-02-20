import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../core/api_client.dart';
import '../core/tts_service.dart';

class ReviewScreen extends ConsumerStatefulWidget {
  const ReviewScreen({super.key});

  @override
  ConsumerState<ReviewScreen> createState() => _ReviewScreenState();
}

class _ReviewScreenState extends ConsumerState<ReviewScreen> {
  bool _isLoading = true;
  List<dynamic> _reviews = [];
  int _currentIndex = 0;
  bool _showMeaning = false;
  final Set<int> _answered = {};

  @override
  void initState() {
    super.initState();
    _loadReviews();
  }

  Future<void> _loadReviews() async {
    final api = ref.read(apiClientProvider);
    try {
      final res = await api.getDueReviews();
      if (mounted) {
        setState(() {
          _reviews = res.data ?? [];
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _speakKorean(String text) {
    ref.read(ttsProvider).speak(text);
  }

  Future<void> _submitResult(bool correct) async {
    if (_currentIndex >= _reviews.length) return;
    final r = _reviews[_currentIndex];
    final vocabId = r['vocabularyId'];

    setState(() {
      _answered.add(_currentIndex);
      _showMeaning = false;
    });

    try {
      final api = ref.read(apiClientProvider);
      await api.submitReview(vocabId, correct);
      // Award XP: 5 for correct, 2 for attempted
      await api.addXP(correct ? 5 : 2);
    } catch (_) {}

    // Auto advance to next unanswered or finish
    _goToNextUnanswered();
  }

  void _goToNextUnanswered() {
    for (int i = _currentIndex + 1; i < _reviews.length; i++) {
      if (!_answered.contains(i)) {
        setState(() => _currentIndex = i);
        return;
      }
    }
    // Check backward
    for (int i = 0; i < _currentIndex; i++) {
      if (!_answered.contains(i)) {
        setState(() => _currentIndex = i);
        return;
      }
    }
    // All answered
    if (_answered.length >= _reviews.length) {
      setState(() => _currentIndex = _reviews.length);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Ôn tập SRS 📚'),
        elevation: 0,
        backgroundColor: const Color(0xFF2563EB),
        foregroundColor: Colors.white,
        actions: [
          if (_reviews.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Center(
                child: Text('${_answered.length}/${_reviews.length}',
                    style: const TextStyle(fontWeight: FontWeight.bold)),
              ),
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _reviews.isEmpty
              ? _buildEmptyState()
              : _currentIndex >= _reviews.length
                  ? _buildFinishedState()
                  : _buildFlashcard(),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.check_circle_outline,
              size: 80, color: Colors.green.shade300),
          const SizedBox(height: 16),
          const Text(
            'Không có từ vựng nào cần ôn!',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            'Hãy thêm từ vựng vào danh sách ôn tập\ntừ các bài học để bắt đầu.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey.shade600),
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: () => context.pop(),
            child: const Text('Quay lại trang chủ'),
          )
        ],
      ),
    );
  }

  Widget _buildFinishedState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text('🎉', style: TextStyle(fontSize: 80)),
          const SizedBox(height: 16),
          Text(
            'Hoàn thành ${_reviews.length} từ vựng!',
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: () => context.pop(),
            child: const Text('Hoàn tất'),
          )
        ],
      ),
    );
  }

  Widget _buildFlashcard() {
    final r = _reviews[_currentIndex];
    final vocab = r['vocabulary'] ?? {};
    final alreadyAnswered = _answered.contains(_currentIndex);

    return GestureDetector(
      onHorizontalDragEnd: (details) {
        if (details.primaryVelocity == null) return;
        if (details.primaryVelocity! < 0 &&
            _currentIndex < _reviews.length - 1) {
          setState(() {
            _currentIndex++;
            _showMeaning = false;
          });
        } else if (details.primaryVelocity! > 0 && _currentIndex > 0) {
          setState(() {
            _currentIndex--;
            _showMeaning = false;
          });
        }
      },
      child: Column(
        children: [
          LinearProgressIndicator(
            value: _reviews.isEmpty ? 0 : _answered.length / _reviews.length,
            minHeight: 8,
            backgroundColor: Colors.grey.shade200,
            valueColor: const AlwaysStoppedAnimation(Color(0xFF2563EB)),
          ),
          Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _showMeaning = true),
              child: Container(
                margin: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: alreadyAnswered ? Colors.green.shade50 : Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.1),
                      blurRadius: 10,
                      offset: const Offset(0, 5),
                    )
                  ],
                  border: Border.all(
                      color: alreadyAnswered
                          ? Colors.green.shade200
                          : Colors.grey.shade200),
                ),
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (alreadyAnswered)
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 4),
                            margin: const EdgeInsets.only(bottom: 16),
                            decoration: BoxDecoration(
                              color: Colors.green,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: const Text('Đã ôn ✓',
                                style: TextStyle(
                                    color: Colors.white, fontSize: 12)),
                          ),
                        Text(
                          vocab['korean'] ?? 'Unknown',
                          style: const TextStyle(
                              fontSize: 48, fontWeight: FontWeight.bold),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 16),
                        IconButton(
                          icon: const Icon(Icons.volume_up,
                              size: 32, color: Color(0xFF2563EB)),
                          onPressed: () => _speakKorean(vocab['korean'] ?? ''),
                        ),
                        const SizedBox(height: 16),
                        if (_showMeaning) ...[
                          Text(
                            vocab['pronunciation'] ?? '',
                            style: TextStyle(
                                fontSize: 18, color: Colors.grey.shade600),
                          ),
                          const SizedBox(height: 16),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 20, vertical: 10),
                            decoration: BoxDecoration(
                              color: const Color(0xFF10B981)
                                  .withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              vocab['vietnamese'] ?? '',
                              style: const TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF10B981),
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                          if (vocab['exampleSentence'] != null &&
                              vocab['exampleSentence']
                                  .toString()
                                  .isNotEmpty) ...[
                            const SizedBox(height: 24),
                            GestureDetector(
                              onTap: () =>
                                  _speakKorean(vocab['exampleSentence'] ?? ''),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.volume_up,
                                      size: 14, color: Color(0xFF2563EB)),
                                  const SizedBox(width: 4),
                                  Flexible(
                                    child: Text(
                                      vocab['exampleSentence'],
                                      style: TextStyle(
                                          color: Colors.grey.shade800,
                                          fontSize: 16,
                                          fontStyle: FontStyle.italic),
                                      textAlign: TextAlign.center,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              vocab['exampleMeaning'] ?? '',
                              style: TextStyle(
                                  color: Colors.grey.shade500, fontSize: 14),
                              textAlign: TextAlign.center,
                            ),
                          ]
                        ] else ...[
                          Text(
                            'Chạm để lật thẻ',
                            style: TextStyle(
                                color: Colors.grey.shade400, fontSize: 16),
                          )
                        ]
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),

          // Navigation row
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back_ios_rounded),
                  onPressed: _currentIndex > 0
                      ? () => setState(() {
                            _currentIndex--;
                            _showMeaning = false;
                          })
                      : null,
                ),
                Text(
                  '${_currentIndex + 1} / ${_reviews.length}',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                IconButton(
                  icon: const Icon(Icons.arrow_forward_ios_rounded),
                  onPressed: _currentIndex < _reviews.length - 1
                      ? () => setState(() {
                            _currentIndex++;
                            _showMeaning = false;
                          })
                      : null,
                ),
              ],
            ),
          ),

          // Actions
          if (_showMeaning && !alreadyAnswered)
            Padding(
              padding: const EdgeInsets.only(bottom: 24, left: 24, right: 24),
              child: Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red.shade50,
                        foregroundColor: Colors.red,
                        padding: const EdgeInsets.symmetric(vertical: 18),
                        elevation: 0,
                      ),
                      onPressed: () => _submitResult(false),
                      icon: const Icon(Icons.close),
                      label: const Text('Chưa thuộc',
                          style: TextStyle(
                              fontSize: 16, fontWeight: FontWeight.bold)),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green.shade50,
                        foregroundColor: Colors.green,
                        padding: const EdgeInsets.symmetric(vertical: 18),
                        elevation: 0,
                      ),
                      onPressed: () => _submitResult(true),
                      icon: const Icon(Icons.check),
                      label: const Text('Đã thuộc',
                          style: TextStyle(
                              fontSize: 16, fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            )
          else
            const SizedBox(height: 24),
        ],
      ),
    );
  }
}

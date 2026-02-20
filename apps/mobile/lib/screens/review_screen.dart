import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:audioplayers/audioplayers.dart';
import '../core/api_client.dart';

class ReviewScreen extends ConsumerStatefulWidget {
  const ReviewScreen({super.key});

  @override
  ConsumerState<ReviewScreen> createState() => _ReviewScreenState();
}

class _ReviewScreenState extends ConsumerState<ReviewScreen>
    with SingleTickerProviderStateMixin {
  bool _isLoading = true;
  List<dynamic> _reviews = [];
  int _currentIndex = 0;
  bool _showMeaning = false;
  late AudioPlayer _audioPlayer;

  @override
  void initState() {
    super.initState();
    _audioPlayer = AudioPlayer();
    _loadReviews();
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
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

  Future<void> _playAudio(String url) async {
    try {
      await _audioPlayer.play(UrlSource(url));
    } catch (_) {}
  }

  Future<void> _submitResult(bool correct) async {
    if (_currentIndex >= _reviews.length) return;
    final r = _reviews[_currentIndex];
    final vocabId = r['vocabularyId'];

    // Optimistic UI update
    setState(() {
      _currentIndex++;
      _showMeaning = false;
    });

    try {
      final api = ref.read(apiClientProvider);
      await api.submitReview(vocabId, correct);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Ôn tập SRS 📚'),
        elevation: 0,
        backgroundColor: const Color(0xFF2563EB),
        foregroundColor: Colors.white,
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
            'Bạn đã hoàn thành rất tốt hôm nay.',
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
            onPressed: () {
              // Refresh review stats on profile if needed
              context.pop();
            },
            child: const Text('Hoàn tất'),
          )
        ],
      ),
    );
  }

  Widget _buildFlashcard() {
    final r = _reviews[_currentIndex];
    final vocab = r['vocabulary'] ?? {};

    return Column(
      children: [
        LinearProgressIndicator(
          value: _reviews.isEmpty ? 0 : _currentIndex / _reviews.length,
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
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 10,
                    offset: const Offset(0, 5),
                  )
                ],
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        vocab['korean'] ?? 'Unknown',
                        style: const TextStyle(
                            fontSize: 48, fontWeight: FontWeight.bold),
                        textAlign: TextAlign.center,
                      ),
                      if (vocab['audioUrl'] != null &&
                          vocab['audioUrl'].toString().isNotEmpty) ...[
                        const SizedBox(height: 16),
                        IconButton(
                          icon: const Icon(Icons.volume_up,
                              size: 32, color: Color(0xFF2563EB)),
                          onPressed: () => _playAudio(vocab['audioUrl']),
                        ),
                      ],
                      const SizedBox(height: 32),
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
                            color:
                                const Color(0xFF10B981).withValues(alpha: 0.1),
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
                            vocab['exampleSentence'].toString().isNotEmpty) ...[
                          const SizedBox(height: 24),
                          Text(
                            vocab['exampleSentence'],
                            style: TextStyle(
                                color: Colors.grey.shade800,
                                fontSize: 16,
                                fontStyle: FontStyle.italic),
                            textAlign: TextAlign.center,
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

        // Actions
        if (_showMeaning)
          Padding(
            padding: const EdgeInsets.only(bottom: 40, left: 24, right: 24),
            child: Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red.shade50,
                      foregroundColor: Colors.red,
                      padding: const EdgeInsets.symmetric(vertical: 20),
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
                      padding: const EdgeInsets.symmetric(vertical: 20),
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
          const SizedBox(height: 100), // Placeholder to keep height consistent
      ],
    );
  }
}

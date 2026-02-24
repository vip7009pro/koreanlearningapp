import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/api_client.dart';

class TopikReviewScreen extends ConsumerStatefulWidget {
  final String sessionId;
  const TopikReviewScreen({super.key, required this.sessionId});

  @override
  ConsumerState<TopikReviewScreen> createState() => _TopikReviewScreenState();
}

class _TopikReviewScreenState extends ConsumerState<TopikReviewScreen> {
  bool _loading = true;
  String? _error;
  Map<String, dynamic>? _data;
  Timer? _poll;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _poll?.cancel();
    super.dispose();
  }

  bool _aiPending(Map<String, dynamic> data) {
    final session = (data['session'] as Map?)?.cast<String, dynamic>();
    final answers = (session?['answers'] as List?) ?? [];
    for (final a in answers) {
      final m = (a as Map).cast<String, dynamic>();
      final q = (m['question'] as Map?)?.cast<String, dynamic>();
      final qType = (q?['questionType'] ?? '').toString();
      if (qType == 'ESSAY' && m['aiReviewedAt'] == null) return true;
    }
    return false;
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final api = ref.read(apiClientProvider);
      final res = await api.getTopikSessionReview(widget.sessionId);
      final data = res.data as Map<String, dynamic>;
      if (!mounted) return;
      setState(() {
        _data = data;
        _loading = false;
      });

      _poll?.cancel();
      if (_aiPending(data)) {
        _poll = Timer.periodic(const Duration(seconds: 5), (_) async {
          if (!mounted) return;
          try {
            final r = await api.getTopikSessionReview(widget.sessionId);
            final d = r.data as Map<String, dynamic>;
            if (!mounted) return;
            setState(() => _data = d);
            if (!_aiPending(d)) {
              _poll?.cancel();
            }
          } catch (_) {
            // ignore poll errors
          }
        });
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Không tải được kết quả. Vui lòng thử lại.';
      });
    }
  }

  String _stripHtml(String html) {
    return html.replaceAll(RegExp(r'<[^>]*>'), '').replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  @override
  Widget build(BuildContext context) {
    final data = _data;
    final session = (data?['session'] as Map?)?.cast<String, dynamic>();
    final sectionScores = (data?['sectionScores'] as List?) ?? [];
    final achievedLevel = data?['achievedLevel'];
    final maxTotalScore = data?['maxTotalScore'];

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        // Ensure back always returns to TOPIK list instead of exiting app.
        Navigator.of(context).popUntil((route) => route.isFirst);
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Kết quả TOPIK'),
          leading: IconButton(
            onPressed: () {
              Navigator.of(context).popUntil((route) => route.isFirst);
            },
            icon: const Icon(Icons.arrow_back),
          ),
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
                          const Icon(Icons.error_outline, size: 48, color: Colors.redAccent),
                          const SizedBox(height: 12),
                          Text(_error!, textAlign: TextAlign.center),
                          const SizedBox(height: 16),
                          ElevatedButton(onPressed: _load, child: const Text('Thử lại')),
                        ],
                      ),
                    ),
                  )
                : session == null
                    ? const Center(child: Text('Không có dữ liệu'))
                    : RefreshIndicator(
                        onRefresh: _load,
                        child: ListView(
                          padding: const EdgeInsets.all(16),
                          children: [
                          Card(
                            child: Padding(
                              padding: const EdgeInsets.all(14),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      const Icon(Icons.emoji_events_outlined),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Text(
                                          'Tổng điểm',
                                          style: TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w800,
                                            color: Colors.grey.shade800,
                                          ),
                                        ),
                                      ),
                                      Text(
                                        '${session['totalScore'] ?? 0}${maxTotalScore != null ? '/$maxTotalScore' : ''}',
                                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
                                      ),
                                    ],
                                  ),
                                  if (achievedLevel != null) ...[
                                    const SizedBox(height: 8),
                                    Text(
                                      'Đạt Level: $achievedLevel',
                                      style: const TextStyle(fontWeight: FontWeight.w800),
                                    ),
                                  ],
                                  const SizedBox(height: 12),
                                  ...sectionScores.map((s) {
                                    final m = (s as Map).cast<String, dynamic>();
                                    return Padding(
                                      padding: const EdgeInsets.only(bottom: 6),
                                      child: Row(
                                        children: [
                                          Expanded(
                                            child: Text(
                                              (m['type'] ?? '').toString(),
                                              style: TextStyle(color: Colors.grey.shade800, fontWeight: FontWeight.w700),
                                            ),
                                          ),
                                          Text(
                                            '${m['score'] ?? 0}/${m['maxScore'] ?? ''}',
                                            style: TextStyle(color: Colors.grey.shade700, fontWeight: FontWeight.w700),
                                          ),
                                        ],
                                      ),
                                    );
                                  }),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          if (_aiPending(data!))
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.blue.withValues(alpha: 0.08),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: Colors.blue.withValues(alpha: 0.2)),
                              ),
                              child: const Row(
                                children: [
                                  SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(strokeWidth: 2),
                                  ),
                                  SizedBox(width: 10),
                                  Expanded(
                                    child: Text('Đang chấm phần Viết bằng AI...'),
                                  ),
                                ],
                              ),
                            ),
                          const SizedBox(height: 12),
                          const Text(
                            'Chi tiết câu trả lời',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
                          ),
                          const SizedBox(height: 10),
                          ..._buildAnswers(session),
                          ],
                        ),
                      ),
      ),
    );
  }

  List<Widget> _buildAnswers(Map<String, dynamic> session) {
    final answers = (session['answers'] as List?) ?? [];

    return answers.map((a) {
      final m = (a as Map).cast<String, dynamic>();
      final q = (m['question'] as Map?)?.cast<String, dynamic>() ?? {};
      final qType = (q['questionType'] ?? '').toString();
      final section = (q['section'] as Map?)?.cast<String, dynamic>();
      final sectionType = (section?['type'] ?? '').toString();
      final content = _stripHtml((q['contentHtml'] ?? '').toString());
      final listeningScript = (q['listeningScript'] ?? '').toString().trim();

      final selectedChoice = (m['selectedChoice'] as Map?)?.cast<String, dynamic>();
      final selectedChoiceText = selectedChoice != null ? _stripHtml((selectedChoice['content'] ?? '').toString()) : null;

      final textAnswer = (m['textAnswer'] ?? '').toString();
      final score = m['score'];
      final aiScore = m['aiScore'];
      final aiFeedback = (m['aiFeedback'] as Map?)?.cast<String, dynamic>();

      return Card(
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                content,
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
              if (sectionType == 'LISTENING' && listeningScript.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  'Script (Listening):',
                  style: TextStyle(color: Colors.grey.shade800, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 4),
                Text(
                  listeningScript,
                  style: TextStyle(color: Colors.grey.shade700),
                ),
              ],
              const SizedBox(height: 10),
              if (qType == 'MCQ')
                Text('Bạn chọn: ${selectedChoiceText ?? '—'}')
              else
                Text('Trả lời: ${textAnswer.isEmpty ? '—' : textAnswer}'),
              const SizedBox(height: 8),
              if (score != null)
                Text(
                  'Điểm: $score',
                  style: TextStyle(color: Colors.grey.shade800, fontWeight: FontWeight.w800),
                ),
              if (qType == 'ESSAY') ...[
                const SizedBox(height: 8),
                Text(
                  'AI Score: ${aiScore ?? '—'}',
                  style: TextStyle(color: Colors.grey.shade800, fontWeight: FontWeight.w800),
                ),
                if (aiFeedback != null) ...[
                  const SizedBox(height: 8),
                  _feedbackBlock('Điểm mạnh', (aiFeedback['strengths'] as List?)?.cast<dynamic>().map((e) => e.toString()).toList() ?? []),
                  _feedbackBlock('Điểm yếu', (aiFeedback['weaknesses'] as List?)?.cast<dynamic>().map((e) => e.toString()).toList() ?? []),
                  _feedbackBlock('Gợi ý cải thiện', (aiFeedback['improvementSuggestions'] as List?)?.cast<dynamic>().map((e) => e.toString()).toList() ?? []),
                  if ((aiFeedback['detailedFeedback'] ?? '').toString().trim().isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Text(
                      (aiFeedback['detailedFeedback'] ?? '').toString(),
                      style: TextStyle(color: Colors.grey.shade700),
                    ),
                  ],
                ],
              ],
            ],
          ),
        ),
      );
    }).toList();
  }

  Widget _feedbackBlock(String title, List<String> items) {
    if (items.isEmpty) return const SizedBox();
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.w900)),
          const SizedBox(height: 4),
          ...items.take(5).map((s) => Padding(
                padding: const EdgeInsets.only(bottom: 2),
                child: Text('• $s', style: TextStyle(color: Colors.grey.shade700)),
              )),
        ],
      ),
    );
  }
}

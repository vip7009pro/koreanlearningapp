import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/api_client.dart';
import '../widgets/app_banner_ad.dart';

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
    return html
        .replaceAll(RegExp(r'<[^>]*>'), '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
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
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (context.mounted) context.go('/');
        });
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Kết quả TOPIK'),
          leading: IconButton(
            onPressed: () {
              context.go('/');
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
                          const Icon(Icons.error_outline,
                              size: 48, color: Colors.redAccent),
                          const SizedBox(height: 12),
                          Text(_error!, textAlign: TextAlign.center),
                          const SizedBox(height: 16),
                          ElevatedButton(
                              onPressed: _load, child: const Text('Thử lại')),
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
                                          style: const TextStyle(
                                              fontSize: 18,
                                              fontWeight: FontWeight.w900),
                                        ),
                                      ],
                                    ),
                                    if (achievedLevel != null) ...[
                                      const SizedBox(height: 8),
                                      Text(
                                        'Đạt Level: $achievedLevel',
                                        style: const TextStyle(
                                            fontWeight: FontWeight.w800),
                                      ),
                                    ],
                                    const SizedBox(height: 12),
                                    ...sectionScores.map((s) {
                                      final m =
                                          (s as Map).cast<String, dynamic>();
                                      return Padding(
                                        padding:
                                            const EdgeInsets.only(bottom: 6),
                                        child: Row(
                                          children: [
                                            Expanded(
                                              child: Text(
                                                (m['type'] ?? '').toString(),
                                                style: TextStyle(
                                                    color: Colors.grey.shade800,
                                                    fontWeight:
                                                        FontWeight.w700),
                                              ),
                                            ),
                                            Text(
                                              '${m['score'] ?? 0}/${m['maxScore'] ?? ''}',
                                              style: TextStyle(
                                                  color: Colors.grey.shade700,
                                                  fontWeight: FontWeight.w700),
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
                                  border: Border.all(
                                      color:
                                          Colors.blue.withValues(alpha: 0.2)),
                                ),
                                child: const Row(
                                  children: [
                                    SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                          strokeWidth: 2),
                                    ),
                                    SizedBox(width: 10),
                                    Expanded(
                                      child: Text(
                                          'Đang chấm phần Viết bằng AI...'),
                                    ),
                                  ],
                                ),
                              ),
                            const SizedBox(height: 12),
                            const Text(
                              'Chi tiết câu trả lời',
                              style: TextStyle(
                                  fontSize: 16, fontWeight: FontWeight.w900),
                            ),
                            const SizedBox(height: 10),
                            ..._buildAnswers(session),
                            const SizedBox(height: 16),
                            const AppBannerAd(),
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
      final parts = _parseQuestionText((q['contentHtml'] ?? '').toString());
      final listeningScript = (q['listeningScript'] ?? '').toString().trim();

      final selectedChoice =
          (m['selectedChoice'] as Map?)?.cast<String, dynamic>();
      final selectedChoiceText = selectedChoice != null
          ? _stripHtml((selectedChoice['content'] ?? '').toString())
          : null;

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
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    parts.instruction,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      height: 1.4,
                    ),
                  ),
                  if (parts.body != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      parts.body!,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.normal,
                        height: 1.45,
                      ),
                    ),
                  ],
                ],
              ),
              // --- Image / Image Prompt ---
              Builder(builder: (_) {
                final imageUrl = (q['imageUrl'] ?? '').toString().trim();
                final imagePrompt = (q['imagePrompt'] ?? '').toString().trim();
                if (imageUrl.isEmpty && imagePrompt.isEmpty) return const SizedBox.shrink();

                void showPromptDialog() {
                  if (imagePrompt.isEmpty) return;
                  showDialog(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: const Text('Mô tả hình ảnh'),
                      content: SingleChildScrollView(
                        child: Text(imagePrompt, style: const TextStyle(fontSize: 14, height: 1.5)),
                      ),
                      actions: [
                        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Đóng')),
                      ],
                    ),
                  );
                }

                if (imageUrl.isNotEmpty) {
                  final api = ref.read(apiClientProvider);
                  final fullUrl = api.absoluteUrl(imageUrl);
                  return Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: GestureDetector(
                      onTap: showPromptDialog,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.network(
                          fullUrl,
                          width: double.infinity,
                          fit: BoxFit.contain,
                          errorBuilder: (_, __, ___) => Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.red.shade50,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Text('Không tải được ảnh', style: TextStyle(color: Colors.red)),
                          ),
                        ),
                      ),
                    ),
                  );
                }

                // Placeholder when imagePrompt exists but no imageUrl
                return Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: GestureDetector(
                    onTap: showPromptDialog,
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                      child: Column(
                        children: [
                          Icon(Icons.image_outlined, size: 40, color: Colors.grey.shade400),
                          const SizedBox(height: 8),
                          Text(
                            'Đề bài dạng tranh ảnh (Chưa cập nhật)',
                            style: TextStyle(
                              color: Colors.grey.shade600,
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Chạm để xem mô tả',
                            style: TextStyle(
                              color: Colors.grey.shade500,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }),
              if (sectionType == 'LISTENING' && listeningScript.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  'Script (Listening):',
                  style: TextStyle(
                      color: Colors.grey.shade800, fontWeight: FontWeight.w800),
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
                  style: TextStyle(
                      color: Colors.grey.shade800, fontWeight: FontWeight.w800),
                ),
              if (qType == 'ESSAY') ...[
                const SizedBox(height: 8),
                Text(
                  'AI Score: ${aiScore ?? '—'}',
                  style: TextStyle(
                      color: Colors.grey.shade800, fontWeight: FontWeight.w800),
                ),
                if (aiFeedback != null) ...[
                  const SizedBox(height: 8),
                  _feedbackBlock(
                      'Điểm mạnh',
                      (aiFeedback['strengths'] as List?)
                              ?.cast<dynamic>()
                              .map((e) => e.toString())
                              .toList() ??
                          []),
                  _feedbackBlock(
                      'Điểm yếu',
                      (aiFeedback['weaknesses'] as List?)
                              ?.cast<dynamic>()
                              .map((e) => e.toString())
                              .toList() ??
                          []),
                  _feedbackBlock(
                      'Gợi ý cải thiện',
                      (aiFeedback['improvementSuggestions'] as List?)
                              ?.cast<dynamic>()
                              .map((e) => e.toString())
                              .toList() ??
                          []),
                  if ((aiFeedback['detailedFeedback'] ?? '')
                      .toString()
                      .trim()
                      .isNotEmpty) ...[
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
                child:
                    Text('• $s', style: TextStyle(color: Colors.grey.shade700)),
              )),
        ],
      ),
    );
  }
}

class QuestionTextParts {
  final String instruction;
  final String? body;
  QuestionTextParts(this.instruction, this.body);
}

QuestionTextParts _parseQuestionText(String html) {
  if (html.isEmpty) return QuestionTextParts('', null);
  
  final regex = RegExp(r'<br\s*\/?>', caseSensitive: false);
  
  // Custom helper to strip tags locally
  String strip(String text) {
    return text.replaceAll(RegExp(r'<[^>]*>'), '').replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  if (!html.contains(regex)) {
    final newlineRegex = RegExp(r'\r?\n');
    if (html.contains(newlineRegex)) {
      final index = html.indexOf(newlineRegex);
      final first = html.substring(0, index);
      final second = html.substring(index).trim();
      return QuestionTextParts(strip(first), second.isNotEmpty ? strip(second) : null);
    }
    return QuestionTextParts(strip(html), null);
  }
  
  final matches = regex.allMatches(html).toList();
  final firstMatch = matches.first;
  final firstPart = html.substring(0, firstMatch.start);
  
  int secondPartStart = firstMatch.end;
  for (int i = 1; i < matches.length; i++) {
    final prevMatch = matches[i - 1];
    final currentMatch = matches[i];
    final between = html.substring(prevMatch.end, currentMatch.start).trim();
    if (between.isEmpty) {
      secondPartStart = currentMatch.end;
    } else {
      break;
    }
  }
  
  final secondPart = html.substring(secondPartStart);
  
  return QuestionTextParts(
    strip(firstPart),
    secondPart.trim().isNotEmpty ? strip(secondPart) : null,
  );
}

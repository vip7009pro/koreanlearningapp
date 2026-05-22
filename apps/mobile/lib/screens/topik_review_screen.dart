import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:audioplayers/audioplayers.dart';

import '../core/api_client.dart';
import '../providers/app_settings_provider.dart';
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

  final AudioPlayer _audio = AudioPlayer();
  String _audioQuestionId = '';
  String _audioUrl = '';
  Duration _audioDuration = Duration.zero;
  Duration _audioPosition = Duration.zero;
  PlayerState _audioState = PlayerState.stopped;
  StreamSubscription<PlayerState>? _audioStateSub;
  StreamSubscription<Duration>? _audioDurationSub;
  StreamSubscription<Duration>? _audioPositionSub;
  StreamSubscription<void>? _audioCompleteSub;

  bool _showDetails = false;
  List<GlobalKey> _questionKeys = [];
  final ScrollController _scrollController = ScrollController();
  bool _showScrollToTop = false;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _audioStateSub = _audio.onPlayerStateChanged.listen((s) {
      if (!mounted) return;
      setState(() => _audioState = s);
    });
    _audioDurationSub = _audio.onDurationChanged.listen((d) {
      if (!mounted) return;
      setState(() => _audioDuration = d);
    });
    _audioPositionSub = _audio.onPositionChanged.listen((p) {
      if (!mounted) return;
      setState(() => _audioPosition = p);
    });
    _audioCompleteSub = _audio.onPlayerComplete.listen((_) async {
      try {
        await _audio.seek(Duration.zero);
      } catch (_) {}
      if (!mounted) return;
      setState(() {
        _audioPosition = Duration.zero;
        _audioState = PlayerState.stopped;
      });
    });
    _load();
  }

  void _onScroll() {
    final shouldShow = _scrollController.offset > 300;
    if (shouldShow != _showScrollToTop) {
      setState(() => _showScrollToTop = shouldShow);
    }
  }

  @override
  void dispose() {
    _poll?.cancel();
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _audioStateSub?.cancel();
    _audioDurationSub?.cancel();
    _audioPositionSub?.cancel();
    _audioCompleteSub?.cancel();
    _audio.dispose();
    super.dispose();
  }

  Future<void> _stopAudio() async {
    try {
      await _audio.stop();
    } catch (_) {}
    if (!mounted) return;
    setState(() {
      _audioQuestionId = '';
      _audioUrl = '';
      _audioDuration = Duration.zero;
      _audioPosition = Duration.zero;
      _audioState = PlayerState.stopped;
    });
  }

  Future<void> _ensureConsolidatedAudio(String url) async {
    if (url.isEmpty) return;

    if (_audioQuestionId == 'EXAM_CONSOLIDATED' &&
        _audioUrl == url &&
        _audioState != PlayerState.stopped &&
        _audioState != PlayerState.completed) {
      return;
    }

    await _stopAudio();
    if (!mounted) return;
    setState(() {
      _audioQuestionId = 'EXAM_CONSOLIDATED';
      _audioUrl = url;
    });

    try {
      final api = ref.read(apiClientProvider);
      final absoluteUrl = api.absoluteUrl(url);
      await _audio.setSourceUrl(absoluteUrl);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _audioUrl = url;
      });
    }
  }

  String _formatTime(int seconds) {
    final m = (seconds ~/ 60).toString().padLeft(2, '0');
    final s = (seconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
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

  Widget _buildConsolidatedAudioPlayer(AppThemeOption palette, String listeningAudioUrl) {
    final isCurrentPlaying = _audioQuestionId == 'EXAM_CONSOLIDATED';
    final isPlaying = isCurrentPlaying && _audioState == PlayerState.playing;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: palette.gradient,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: palette.seedColor.withValues(alpha: 0.3),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.headphones_outlined,
                  color: Colors.white,
                  size: 24,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Âm thanh nghe toàn bộ đề',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Phát toàn bộ bài nghe giải thích đề thi',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.8),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: () async {
                  await _stopAudio();
                },
                icon: const Icon(Icons.stop_circle_outlined, color: Colors.white, size: 28),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              IconButton(
                padding: EdgeInsets.zero,
                onPressed: () async {
                  await _ensureConsolidatedAudio(listeningAudioUrl);
                  try {
                    if (isCurrentPlaying && _audioState == PlayerState.playing) {
                      await _audio.pause();
                    } else {
                      if (_audioState == PlayerState.completed || _audioState == PlayerState.stopped) {
                        await _audio.seek(Duration.zero);
                      }
                      await _audio.resume();
                    }
                  } catch (_) {
                    if (!mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Không thể phát audio.')),
                    );
                  }
                },
                icon: Icon(
                  isPlaying ? Icons.pause_circle_filled : Icons.play_circle_fill,
                  color: Colors.white,
                  size: 48,
                ),
              ),
              Expanded(
                child: Column(
                  children: [
                    SliderTheme(
                      data: SliderTheme.of(context).copyWith(
                        activeTrackColor: Colors.white,
                        inactiveTrackColor: Colors.white.withValues(alpha: 0.3),
                        thumbColor: Colors.white,
                        overlayColor: Colors.white.withValues(alpha: 0.1),
                        trackHeight: 4,
                      ),
                      child: Slider(
                        value: (isCurrentPlaying ? _audioPosition.inMilliseconds : 0)
                            .clamp(
                              0,
                              (isCurrentPlaying && _audioDuration.inMilliseconds > 0)
                                  ? _audioDuration.inMilliseconds
                                  : 0,
                            )
                            .toDouble(),
                        max: ((isCurrentPlaying && _audioDuration.inMilliseconds > 0)
                                ? _audioDuration.inMilliseconds
                                : 1)
                            .toDouble(),
                        onChanged: isCurrentPlaying
                            ? (v) async {
                                try {
                                  await _audio.seek(Duration(milliseconds: v.toInt()));
                                } catch (_) {}
                              }
                            : null,
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            _formatTime(
                              (isCurrentPlaying ? _audioPosition.inSeconds : 0).clamp(0, 999999),
                            ),
                            style: const TextStyle(color: Colors.white, fontSize: 11),
                          ),
                          Text(
                            _formatTime(
                              (isCurrentPlaying ? _audioDuration.inSeconds : 0).clamp(0, 999999),
                            ),
                            style: const TextStyle(color: Colors.white, fontSize: 11),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(appSettingsProvider);
    final palette = AppSettingsNotifier.themeById(settings.themeId);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final data = _data;
    final session = (data?['session'] as Map?)?.cast<String, dynamic>();
    final sectionScores = (data?['sectionScores'] as List?) ?? [];
    final achievedLevel = data?['achievedLevel'];
    final maxTotalScore = data?['maxTotalScore'];

    final exam = (session?['exam'] as Map?)?.cast<String, dynamic>();
    final listeningAudioUrl = (exam?['listeningAudioUrl'] ?? '').toString().trim();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Kết quả TOPIK'),
      ),
      floatingActionButton: _showScrollToTop
          ? FloatingActionButton.small(
              onPressed: () {
                _scrollController.animateTo(
                  0,
                  duration: const Duration(milliseconds: 400),
                  curve: Curves.easeOut,
                );
              },
              child: const Icon(Icons.arrow_upward),
            )
          : null,
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
                      child: Builder(builder: (context) {
                        final answers = List.from((session['answers'] as List?) ?? []);
                        answers.sort((a, b) {
                          final qa = (a as Map)['question'] as Map?;
                          final qb = (b as Map)['question'] as Map?;
                          final sa = ((qa?['section'] as Map?)?['orderIndex'] ?? 0) as num;
                          final sb = ((qb?['section'] as Map?)?['orderIndex'] ?? 0) as num;
                          if (sa != sb) return sa.compareTo(sb);
                          final oa = (qa?['orderIndex'] ?? 0) as num;
                          final ob = (qb?['orderIndex'] ?? 0) as num;
                          return oa.compareTo(ob);
                        });

                        if (_questionKeys.length != answers.length) {
                          _questionKeys = List.generate(answers.length, (_) => GlobalKey());
                        }

                        return SingleChildScrollView(
                          controller: _scrollController,
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                            if (listeningAudioUrl.isNotEmpty)
                              _buildConsolidatedAudioPlayer(palette, listeningAudioUrl),
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
                                            'Tổng điểm đạt được',
                                            style: TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.w800,
                                              color: isDark ? Colors.white70 : Colors.grey.shade800,
                                            ),
                                          ),
                                        ),
                                        Text(
                                          '${session['totalScore'] ?? 0}${maxTotalScore != null ? '/$maxTotalScore' : ''}',
                                          style: const TextStyle(
                                              fontSize: 22,
                                              fontWeight: FontWeight.w900),
                                        ),
                                      ],
                                    ),
                                    if (achievedLevel != null) ...[
                                      const SizedBox(height: 8),
                                      Text(
                                        'Đạt Level: $achievedLevel',
                                        style: const TextStyle(
                                            fontWeight: FontWeight.w800,
                                            fontSize: 15,
                                            color: Colors.green),
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
                                                    color: isDark ? Colors.white70 : Colors.grey.shade800,
                                                    fontWeight:
                                                        FontWeight.w700),
                                              ),
                                            ),
                                            Text(
                                              '${m['score'] ?? 0}/${m['maxScore'] ?? ''}',
                                              style: TextStyle(
                                                  color: isDark ? Colors.white60 : Colors.grey.shade700,
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
                            const SizedBox(height: 16),
                            // Matrix grid of question dots
                            Text(
                              'Ma trận kết quả câu hỏi',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w800,
                                color: isDark ? Colors.white70 : Colors.grey.shade800,
                              ),
                            ),
                            const SizedBox(height: 10),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: List.generate(answers.length, (idx) {
                                final a = answers[idx] as Map<String, dynamic>;
                                final score = a['score'];
                                final isCorrect = a['isCorrect'] == true || (score is num && score > 0);
                                final color = isCorrect ? Colors.green : Colors.red;

                                return InkWell(
                                  onTap: () {
                                    final wasShowingDetails = _showDetails;
                                    setState(() {
                                      _showDetails = true;
                                    });
                                    // Use double-frame callback to ensure all detail
                                    // cards are laid out before scrolling (especially
                                    // for questions further down in the list).
                                    void doScroll() {
                                      if (!mounted) return;
                                      final targetContext = _questionKeys[idx].currentContext;
                                      if (targetContext != null) {
                                        Scrollable.ensureVisible(
                                          targetContext,
                                          duration: const Duration(milliseconds: 300),
                                          curve: Curves.easeOut,
                                          alignment: 0.1,
                                        );
                                      }
                                    }
                                    if (wasShowingDetails) {
                                      // Details already rendered, single frame is fine
                                      WidgetsBinding.instance.addPostFrameCallback((_) => doScroll());
                                    } else {
                                      // Details just expanded: wait two frames for layout
                                      WidgetsBinding.instance.addPostFrameCallback((_) {
                                        WidgetsBinding.instance.addPostFrameCallback((_) => doScroll());
                                      });
                                    }
                                  },
                                  borderRadius: BorderRadius.circular(999),
                                  child: Container(
                                    width: 44,
                                    height: 44,
                                    alignment: Alignment.center,
                                    decoration: BoxDecoration(
                                      color: color.withValues(alpha: 0.15),
                                      shape: BoxShape.circle,
                                      border: Border.all(color: color, width: 2),
                                    ),
                                    child: Text(
                                      '${idx + 1}',
                                      style: TextStyle(
                                        color: isDark ? Colors.white : color.shade900,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14,
                                      ),
                                    ),
                                  ),
                                );
                              }),
                            ),
                            const SizedBox(height: 20),
                            // View details button
                            Center(
                              child: ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                onPressed: () {
                                  setState(() {
                                    _showDetails = !_showDetails;
                                  });
                                },
                                icon: Icon(_showDetails ? Icons.expand_less : Icons.expand_more),
                                label: Text(_showDetails ? 'Thu gọn chi tiết' : 'Xem chi tiết câu trả lời'),
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
                            if (_showDetails) ...[
                              const SizedBox(height: 16),
                              Text(
                                'Chi tiết câu trả lời',
                                style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w900,
                                    color: isDark ? Colors.white : Colors.black),
                              ),
                              const SizedBox(height: 10),
                              ..._buildAnswers(answers, isDark),
                            ],
                            const SizedBox(height: 16),
                            const AppBannerAd(),
                          ],
                          ),
                        );
                      }),
                    ),
    );
  }

  List<Widget> _buildAnswers(List<dynamic> answers, bool isDark) {
    return answers.map((a) {
      final m = (a as Map).cast<String, dynamic>();
      final index = answers.indexOf(a);
      final q = (m['question'] as Map?)?.cast<String, dynamic>() ?? {};
      final qType = (q['questionType'] ?? '').toString();
      final section = (q['section'] as Map?)?.cast<String, dynamic>();
      final sectionType = (section?['type'] ?? '').toString();
      final parts = _parseQuestionText((q['contentHtml'] ?? '').toString());
      final listeningScript = (q['listeningScript'] ?? '').toString().trim();

      final selectedChoice =
          (m['selectedChoice'] as Map?)?.cast<String, dynamic>();
      final selectedChoiceId = selectedChoice?['id']?.toString();

      final textAnswer = (m['textAnswer'] ?? '').toString();
      final score = m['score'];
      final aiScore = m['aiScore'];
      final aiFeedback = (m['aiFeedback'] as Map?)?.cast<String, dynamic>();
      final explanation = (q['explanation'] ?? '').toString().trim();

      final choices = (q['choices'] as List?) ?? [];
      final correctChoice = choices.firstWhere(
        (c) => (c as Map)['isCorrect'] == true,
        orElse: () => null,
      );
      final correctChoiceId = correctChoice?['id']?.toString();

      final isCorrect = m['isCorrect'] == true || (score is num && score > 0);
      final cardColor = isCorrect
          ? (isDark ? Colors.green.withValues(alpha: 0.08) : Colors.green.shade50)
          : (isDark ? Colors.red.withValues(alpha: 0.08) : Colors.red.shade50);
      final borderColor = isCorrect
          ? (isDark ? Colors.green.withValues(alpha: 0.25) : Colors.green.shade200)
          : (isDark ? Colors.red.withValues(alpha: 0.25) : Colors.red.shade200);

      Widget buildChoicesList() {
        return Column(
          children: Iterable<int>.generate(choices.length).map((idx) {
            final c = choices[idx] as Map<String, dynamic>;
            final choiceId = c['id']?.toString();
            final isSelected = choiceId == selectedChoiceId;
            final isCorrectChoice = choiceId == correctChoiceId;
            final content = _stripHtml((c['content'] ?? '').toString());
            final prefix = '${String.fromCharCode(65 + idx)}. ';

            Color? borderColor;
            Color? bgColor;
            Widget? trailingIcon;
            TextStyle textStyle = const TextStyle(fontWeight: FontWeight.w500);

            if (isCorrectChoice) {
              borderColor = Colors.green.shade400;
              bgColor = isDark ? Colors.green.withValues(alpha: 0.15) : Colors.green.shade50;
              trailingIcon = const Icon(Icons.check_circle, color: Colors.green, size: 20);
              textStyle = TextStyle(fontWeight: FontWeight.bold, color: isDark ? Colors.green.shade200 : Colors.green.shade900);
            } else if (isSelected) {
              borderColor = Colors.red.shade400;
              bgColor = isDark ? Colors.red.withValues(alpha: 0.15) : Colors.red.shade50;
              trailingIcon = const Icon(Icons.cancel, color: Colors.red, size: 20);
              textStyle = TextStyle(fontWeight: FontWeight.bold, color: isDark ? Colors.red.shade200 : Colors.red.shade900);
            } else {
              borderColor = isDark ? Colors.grey.shade700 : Colors.grey.shade300;
              bgColor = isDark ? const Color(0xFF1E1E24) : Colors.white;
            }

            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: bgColor,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: borderColor,
                  width: isSelected || isCorrectChoice ? 2 : 1,
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      '$prefix$content',
                      style: textStyle,
                    ),
                  ),
                  if (trailingIcon != null) ...[
                    const SizedBox(width: 8),
                    trailingIcon,
                  ],
                ],
              ),
            );
          }).toList(),
        );
      }

      Widget buildExplanationBlock(String text) {
        return Container(
          margin: const EdgeInsets.only(top: 14),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isDark ? Colors.blue.withValues(alpha: 0.12) : Colors.blue.shade50,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isDark ? Colors.blue.withValues(alpha: 0.25) : Colors.blue.shade200,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.info_outline, color: isDark ? Colors.blue.shade300 : Colors.blue.shade700, size: 18),
                  const SizedBox(width: 8),
                  Text(
                    'Giải thích chi tiết:',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                      color: isDark ? Colors.blue.shade200 : Colors.blue.shade800,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                text,
                style: TextStyle(
                  fontSize: 13,
                  height: 1.45,
                  color: isDark ? Colors.grey.shade300 : Colors.grey.shade800,
                ),
              ),
            ],
          ),
        );
      }

      return Card(
        key: _questionKeys[index],
        color: cardColor,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: borderColor, width: 1.5),
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    '${index + 1}.',
                    style: const TextStyle(fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(width: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: isDark ? Colors.grey.shade800 : Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      sectionType,
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? Colors.white70 : Colors.grey.shade800,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const Spacer(),
                  Icon(
                    isCorrect ? Icons.check_circle_outline : Icons.error_outline,
                    color: isCorrect ? Colors.green : Colors.red,
                  ),
                ],
              ),
              const SizedBox(height: 12),
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
                        color: isDark ? Colors.grey.shade800 : Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: isDark ? Colors.grey.shade700 : Colors.grey.shade300),
                      ),
                      child: Column(
                        children: [
                          Icon(Icons.image_outlined, size: 40, color: Colors.grey.shade400),
                          const SizedBox(height: 8),
                          Text(
                            'Đề bài dạng tranh ảnh (Chưa cập nhật)',
                            style: TextStyle(
                              color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Chạm để xem mô tả',
                            style: TextStyle(
                              color: isDark ? Colors.grey.shade500 : Colors.grey.shade500,
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
                      fontWeight: FontWeight.w800,
                      color: isDark ? Colors.white70 : Colors.grey.shade800),
                ),
                const SizedBox(height: 4),
                Text(
                  listeningScript,
                  style: TextStyle(color: isDark ? Colors.grey.shade300 : Colors.grey.shade700),
                ),
              ],
              const SizedBox(height: 14),
              if (qType == 'MCQ') ...[
                buildChoicesList(),
              ] else ...[
                Text(
                  'Trả lời: ${textAnswer.isEmpty ? '—' : textAnswer}',
                  style: const TextStyle(fontWeight: FontWeight.w500),
                ),
              ],
              const SizedBox(height: 8),
              if (score != null)
                Text(
                  'Điểm: $score',
                  style: TextStyle(
                      fontWeight: FontWeight.w800,
                      color: isDark ? Colors.white70 : Colors.grey.shade800),
                ),
              if (qType == 'ESSAY') ...[
                const SizedBox(height: 8),
                Text(
                  'AI Score: ${aiScore ?? '—'}',
                  style: TextStyle(
                      fontWeight: FontWeight.w800,
                      color: isDark ? Colors.white70 : Colors.grey.shade800),
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
                      style: TextStyle(color: isDark ? Colors.grey.shade300 : Colors.grey.shade700),
                    ),
                  ],
                ],
              ],
              if (explanation.isNotEmpty)
                buildExplanationBlock(explanation),
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
                    Text('• $s', style: const TextStyle(color: Colors.grey)),
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

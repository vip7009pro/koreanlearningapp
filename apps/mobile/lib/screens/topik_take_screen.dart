import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter_tts/flutter_tts.dart';

import '../core/api_client.dart';

class TopikTakeScreen extends ConsumerStatefulWidget {
  final String sessionId;
  final Map<String, dynamic>? exam;
  const TopikTakeScreen({super.key, required this.sessionId, this.exam});

  @override
  ConsumerState<TopikTakeScreen> createState() => _TopikTakeScreenState();
}

class _TopikTakeScreenState extends ConsumerState<TopikTakeScreen> {
  bool _loading = true;
  String? _error;
  Map<String, dynamic>? _exam;

  List<dynamic> _questions = [];
  int _currentIndex = 0;
  int _remainingSeconds = 0;

  final Map<String, dynamic> _draft = {};
  Timer? _timer;
  Timer? _autosave;

  final AudioPlayer _audio = AudioPlayer();
  String _audioQuestionId = '';
  String _audioUrl = '';
  Duration _audioDuration = Duration.zero;
  Duration _audioPosition = Duration.zero;
  PlayerState _audioState = PlayerState.stopped;
  StreamSubscription<PlayerState>? _audioStateSub;
  StreamSubscription<Duration>? _audioDurationSub;
  StreamSubscription<Duration>? _audioPositionSub;

  bool _navFlaggedOnly = false;

  final FlutterTts _tts = FlutterTts();
  bool _ttsSpeaking = false;

  @override
  void initState() {
    super.initState();
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
    _load();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _autosave?.cancel();
    _audioStateSub?.cancel();
    _audioDurationSub?.cancel();
    _audioPositionSub?.cancel();
    _audio.dispose();
    _tts.stop();
    super.dispose();
  }

  Future<void> _stopTts() async {
    try {
      await _tts.stop();
    } catch (_) {
      // ignore
    }
    if (!mounted) return;
    setState(() => _ttsSpeaking = false);
  }

  Future<void> _speakTts(String script) async {
    final text = script.trim();
    if (text.isEmpty) return;
    try {
      await _tts.setLanguage('ko-KR');
      await _tts.setSpeechRate(0.45);
      await _tts.setPitch(1.0);
      await _tts.awaitSpeakCompletion(true);
      if (!mounted) return;
      setState(() => _ttsSpeaking = true);
      await _tts.speak(text);
      if (!mounted) return;
      setState(() => _ttsSpeaking = false);
    } catch (_) {
      if (!mounted) return;
      setState(() => _ttsSpeaking = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Không thể đọc TTS.')),
      );
    }
  }

  Future<void> _stopAudio() async {
    try {
      await _audio.stop();
    } catch (_) {
      // ignore
    }
    if (!mounted) return;
    setState(() {
      _audioQuestionId = '';
      _audioUrl = '';
      _audioDuration = Duration.zero;
      _audioPosition = Duration.zero;
      _audioState = PlayerState.stopped;
    });
  }

  Future<void> _ensureAudioForQuestion(Map<String, dynamic> q) async {
    final qId = (q['id'] ?? '').toString();
    final url = (q['audioUrl'] ?? '').toString().trim();
    if (url.isEmpty) {
      if (_audioQuestionId.isNotEmpty) {
        await _stopAudio();
      }
      return;
    }

    if (_audioQuestionId == qId && _audioUrl == url) return;

    await _stopAudio();
    if (!mounted) return;
    setState(() {
      _audioQuestionId = qId;
      _audioUrl = url;
    });

    try {
      await _audio.setSourceUrl(url);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _audioUrl = url;
      });
    }
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

      final session = data['session'] as Map<String, dynamic>;
      final exam = (widget.exam ?? session['exam']) as Map<String, dynamic>;

      final answers = (session['answers'] as List?) ?? [];
      List<Map<String, dynamic>> qs;
      if (answers.isEmpty) {
        final examId = (exam['id'] ?? session['examId'] ?? '').toString();
        if (examId.isNotEmpty) {
          final examRes = await api.getTopikExamDetail(examId);
          final examDetail = examRes.data as Map<String, dynamic>;
          final examObj = (examDetail['exam'] as Map?)?.cast<String, dynamic>();
          final sections = (examObj?['sections'] as List?) ?? [];
          final tmp = <Map<String, dynamic>>[];
          for (final s in sections) {
            final sm = (s as Map).cast<String, dynamic>();
            final questions = (sm['questions'] as List?) ?? [];
            for (final q in questions) {
              final qm = (q as Map).cast<String, dynamic>();
              // Make sure each question carries its section for UI/grouping
              tmp.add({
                ...qm,
                'section': sm,
              });
            }
          }
          qs = tmp;
        } else {
          qs = <Map<String, dynamic>>[];
        }
      } else {
        qs = answers
            .map((a) => (a as Map<String, dynamic>)['question'])
            .whereType<Map<String, dynamic>>()
            .toList();
      }

      qs.sort((a, b) {
        final sa = ((a['section'] as Map?)?['orderIndex'] ?? 0) as num;
        final sb = ((b['section'] as Map?)?['orderIndex'] ?? 0) as num;
        if (sa != sb) return sa.compareTo(sb);
        final oa = (a['orderIndex'] ?? 0) as num;
        final ob = (b['orderIndex'] ?? 0) as num;
        return oa.compareTo(ob);
      });

      final byQ = <String, Map<String, dynamic>>{};
      for (final a in answers) {
        final m = a as Map<String, dynamic>;
        final q = (m['question'] as Map?)?.cast<String, dynamic>();
        final qId = (q?['id'] ?? '').toString();
        if (qId.isEmpty) continue;
        byQ[qId] = m;
      }

      final currentIdx = (session['currentQuestionIndex'] is num)
          ? (session['currentQuestionIndex'] as num).toInt()
          : 0;
      final remaining = (session['remainingSeconds'] is num)
          ? (session['remainingSeconds'] as num).toInt()
          : 0;

      if (!mounted) return;
      setState(() {
        _exam = exam;
        _questions = qs;
        _currentIndex = currentIdx.clamp(0, qs.isNotEmpty ? qs.length - 1 : 0);
        _remainingSeconds = remaining;
        _loading = false;
      });

      for (final q in qs) {
        final qId = (q['id'] ?? '').toString();
        final ans = byQ[qId];
        if (ans == null) {
          _draft[qId] = {
            'selectedChoiceId': null,
            'textAnswer': '',
            'flagged': false,
          };
          continue;
        }
        if (ans['selectedChoiceId'] != null) {
          _draft[qId] = {
            'selectedChoiceId': ans['selectedChoiceId'],
            'textAnswer': null,
            'flagged': ans['flagged'] == true,
          };
        } else if (ans['textAnswer'] != null) {
          _draft[qId] = {
            'selectedChoiceId': null,
            'textAnswer': (ans['textAnswer'] ?? '').toString(),
            'flagged': ans['flagged'] == true,
          };
        } else {
          _draft[qId] = {
            'selectedChoiceId': null,
            'textAnswer': '',
            'flagged': ans['flagged'] == true,
          };
        }
      }

      _startTimers();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Không tải được bài thi. Vui lòng thử lại.';
      });
    }
  }

  void _startTimers() {
    _timer?.cancel();
    _autosave?.cancel();

    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      if (_remainingSeconds <= 0) {
        _timer?.cancel();
        _onSubmit(auto: true);
        return;
      }
      setState(() => _remainingSeconds--);
    });

    _autosave = Timer.periodic(const Duration(seconds: 10), (_) {
      _saveCurrent(bestEffort: true);
    });
  }

  String _stripHtml(String html) {
    return html.replaceAll(RegExp(r'<[^>]*>'), '').replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  Map<String, dynamic> _currentQuestion() {
    return (_questions[_currentIndex] as Map).cast<String, dynamic>();
  }

  Map<String, dynamic> _currentDraft(String qId) {
    return (_draft[qId] as Map?)?.cast<String, dynamic>() ?? {
      'selectedChoiceId': null,
      'textAnswer': '',
      'flagged': false,
    };
  }

  Future<void> _saveCurrent({required bool bestEffort}) async {
    if (_questions.isEmpty) return;
    final q = _currentQuestion();
    final qId = (q['id'] ?? '').toString();
    if (qId.isEmpty) return;

    final d = _currentDraft(qId);

    final api = ref.read(apiClientProvider);
    try {
      await api.saveTopikAnswer(
        widget.sessionId,
        questionId: qId,
        selectedChoiceId: d['selectedChoiceId'] as String?,
        textAnswer: d['textAnswer'] as String?,
        currentQuestionIndex: _currentIndex,
        remainingSeconds: _remainingSeconds,
        flagged: d['flagged'] == true,
      );
    } catch (_) {
      if (!bestEffort && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Không thể lưu đáp án.')),
        );
      }
    }
  }

  Future<void> _onNext() async {
    await _saveCurrent(bestEffort: true);
    if (!mounted) return;
    if (_currentIndex < _questions.length - 1) {
      await _stopAudio();
      await _stopTts();
      if (!mounted) return;
      setState(() => _currentIndex++);
    }
  }

  Future<void> _onPrev() async {
    await _saveCurrent(bestEffort: true);
    if (!mounted) return;
    if (_currentIndex > 0) {
      await _stopAudio();
      await _stopTts();
      if (!mounted) return;
      setState(() => _currentIndex--);
    }
  }

  Future<void> _onSubmit({bool auto = false}) async {
    await _saveCurrent(bestEffort: true);
    await _stopAudio();
    await _stopTts();

    final api = ref.read(apiClientProvider);
    try {
      final res = await api.submitTopikSession(
        widget.sessionId,
        remainingSeconds: _remainingSeconds,
      );

      if (!mounted) return;
      final session = res.data as Map<String, dynamic>;
      context.go('/topik/session/${session['id']}/review');
    } catch (_) {
      if (!mounted) return;
      if (!auto) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Không thể nộp bài. Vui lòng thử lại.')),
        );
      }
    }
  }

  String _formatTime(int seconds) {
    final m = (seconds ~/ 60).toString().padLeft(2, '0');
    final s = (seconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  bool _isAnswered(String qId) {
    final d = _currentDraft(qId);
    final selected = d['selectedChoiceId'];
    if (selected != null && selected.toString().isNotEmpty) return true;
    final t = (d['textAnswer'] ?? '').toString().trim();
    return t.isNotEmpty;
  }

  bool _isFlagged(String qId) {
    final d = _currentDraft(qId);
    return d['flagged'] == true;
  }

  Widget _legendChip({
    required String label,
    required Color bg,
    required Color fg,
    Color? border,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
        border: border != null ? Border.all(color: border) : null,
      ),
      child: Text(
        label,
        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: fg),
      ),
    );
  }

  Map<String, List<int>> _questionIndexesBySectionType() {
    final out = <String, List<int>>{};
    for (var i = 0; i < _questions.length; i++) {
      final q = (_questions[i] as Map).cast<String, dynamic>();
      final section = (q['section'] as Map?)?.cast<String, dynamic>();
      final type = (section?['type'] ?? 'UNKNOWN').toString();
      (out[type] ??= []).add(i);
    }
    return out;
  }

  Future<void> _jumpTo(int index) async {
    if (index < 0 || index >= _questions.length) return;
    if (index == _currentIndex) return;
    await _saveCurrent(bestEffort: true);
    await _stopAudio();
    if (!mounted) return;
    setState(() => _currentIndex = index);
  }

  void _openNavigator() {
    if (_questions.isEmpty) return;
    final groups = _questionIndexesBySectionType();
    final order = <String>['LISTENING', 'WRITING', 'READING'];
    final keys = [
      ...order.where(groups.containsKey),
      ...groups.keys.where((k) => !order.contains(k)).toList()..sort(),
    ];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 6, 16, 16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Expanded(
                          child: Text(
                            'Danh sách câu hỏi',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                          ),
                        ),
                        TextButton.icon(
                          onPressed: () {
                            setModalState(() => _navFlaggedOnly = !_navFlaggedOnly);
                            setState(() {});
                          },
                          icon: Icon(_navFlaggedOnly ? Icons.flag : Icons.outlined_flag),
                          label: Text(_navFlaggedOnly ? 'Đang lọc' : 'Chỉ flagged'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 10,
                      runSpacing: 8,
                      children: [
                        _legendChip(
                          label: 'Current',
                          bg: Theme.of(context).colorScheme.primary,
                          fg: Colors.white,
                        ),
                        _legendChip(
                          label: 'Answered',
                          bg: Colors.green.withValues(alpha: 0.12),
                          fg: Colors.green.shade900,
                          border: Colors.green.withValues(alpha: 0.25),
                        ),
                        _legendChip(
                          label: 'Flagged',
                          bg: Colors.orange.withValues(alpha: 0.14),
                          fg: Colors.orange.shade900,
                          border: Colors.orange.withValues(alpha: 0.35),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Flexible(
                      child: ListView(
                        shrinkWrap: true,
                        children: keys.map((sectionType) {
                          final indexes = groups[sectionType] ?? const [];
                          final visible = _navFlaggedOnly
                              ? indexes.where((i) {
                                  final q = (_questions[i] as Map).cast<String, dynamic>();
                                  final qId = (q['id'] ?? '').toString();
                                  return _isFlagged(qId);
                                }).toList()
                              : indexes;

                          return Card(
                            elevation: 0,
                            color: Colors.grey.shade50,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                              side: BorderSide(color: Colors.grey.shade200),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '$sectionType (${visible.length})',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w800,
                                      color: Colors.grey.shade800,
                                    ),
                                  ),
                                  const SizedBox(height: 10),
                                  if (visible.isEmpty)
                                    Text(
                                      _navFlaggedOnly ? 'Không có câu đã đánh dấu.' : 'Không có câu.',
                                      style: TextStyle(color: Colors.grey.shade700),
                                    )
                                  else
                                    Wrap(
                                      spacing: 8,
                                      runSpacing: 8,
                                      children: visible.map((i) {
                                        final q = (_questions[i] as Map).cast<String, dynamic>();
                                        final qId = (q['id'] ?? '').toString();
                                        final answered = _isAnswered(qId);
                                        final flagged = _isFlagged(qId);
                                        final isCur = i == _currentIndex;

                                        Color bg;
                                        Color fg;
                                        BorderSide? side;

                                        if (isCur) {
                                          bg = Theme.of(context).colorScheme.primary;
                                          fg = Colors.white;
                                          side = null;
                                        } else if (flagged) {
                                          bg = Colors.orange.withValues(alpha: 0.14);
                                          fg = Colors.orange.shade900;
                                          side = BorderSide(color: Colors.orange.withValues(alpha: 0.35));
                                        } else if (answered) {
                                          bg = Colors.green.withValues(alpha: 0.12);
                                          fg = Colors.green.shade900;
                                          side = BorderSide(color: Colors.green.withValues(alpha: 0.25));
                                        } else {
                                          bg = Colors.white;
                                          fg = Colors.grey.shade800;
                                          side = BorderSide(color: Colors.grey.shade300);
                                        }

                                        return InkWell(
                                          onTap: () async {
                                            Navigator.of(ctx).pop();
                                            await _jumpTo(i);
                                          },
                                          borderRadius: BorderRadius.circular(10),
                                          child: Container(
                                            width: 44,
                                            height: 44,
                                            alignment: Alignment.center,
                                            decoration: BoxDecoration(
                                              color: bg,
                                              borderRadius: BorderRadius.circular(12),
                                              border: side != null ? Border.fromBorderSide(side) : null,
                                            ),
                                            child: Text(
                                              '${i + 1}',
                                              style: TextStyle(fontWeight: FontWeight.w800, color: fg),
                                            ),
                                          ),
                                        );
                                      }).toList(),
                                    ),
                                ],
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_exam != null ? (_exam!['title'] ?? 'Làm bài') : 'Làm bài'),
        actions: [
          if (!_loading && _questions.isNotEmpty)
            IconButton(
              tooltip: 'Danh sách câu hỏi',
              onPressed: _openNavigator,
              icon: const Icon(Icons.grid_view_rounded),
            ),
          if (!_loading && _questions.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(right: 10),
              child: Center(
                child: Text(
                  '${_currentIndex + 1}/${_questions.length} · ${_formatTime(_remainingSeconds)}',
                  style: const TextStyle(fontWeight: FontWeight.w700),
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
                        const Icon(Icons.error_outline, size: 48, color: Colors.redAccent),
                        const SizedBox(height: 12),
                        Text(_error!, textAlign: TextAlign.center),
                        const SizedBox(height: 16),
                        ElevatedButton(onPressed: _load, child: const Text('Thử lại')),
                      ],
                    ),
                  ),
                )
              : _questions.isEmpty
                  ? const Center(child: Text('Chưa có câu hỏi'))
                  : _buildQuestion(),
      bottomNavigationBar: _loading || _questions.isEmpty
          ? null
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _currentIndex > 0 ? _onPrev : null,
                        child: const Text('Trước'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _currentIndex < _questions.length - 1 ? _onNext : () => _onSubmit(),
                        child: Text(_currentIndex < _questions.length - 1 ? 'Tiếp' : 'Nộp bài'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildQuestion() {
    final q = _currentQuestion();
    _ensureAudioForQuestion(q);
    final qId = (q['id'] ?? '').toString();
    final qType = (q['questionType'] ?? '').toString();
    final section = (q['section'] as Map?)?.cast<String, dynamic>();
    final sectionType = (section?['type'] ?? '').toString();

    final d = _currentDraft(qId);

    final questionText = _stripHtml((q['contentHtml'] ?? '').toString());

    final choices = (q['choices'] as List?) ?? [];

    final audioUrl = (q['audioUrl'] ?? '').toString().trim();
    final listeningScript = (q['listeningScript'] ?? '').toString().trim();
    final showTts = audioUrl.isEmpty && listeningScript.isNotEmpty;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  sectionType,
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade800, fontWeight: FontWeight.w700),
                ),
              ),
              const SizedBox(width: 10),
              Text(
                qType,
                style: TextStyle(color: Colors.grey.shade700, fontWeight: FontWeight.w600),
              ),
              const Spacer(),
              IconButton(
                tooltip: 'Đánh dấu',
                onPressed: () {
                  setState(() {
                    final cur = _currentDraft(qId);
                    _draft[qId] = {
                      ...cur,
                      'flagged': !(cur['flagged'] == true),
                    };
                  });
                  _saveCurrent(bestEffort: true);
                },
                icon: Icon(d['flagged'] == true ? Icons.flag : Icons.outlined_flag),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            questionText,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          ),
          if (audioUrl.isNotEmpty || showTts) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade300),
                color: Colors.grey.shade50,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      IconButton(
                        onPressed: () async {
                          if (showTts) {
                            if (_ttsSpeaking) {
                              await _stopTts();
                            } else {
                              await _stopAudio();
                              await _speakTts(listeningScript);
                            }
                            return;
                          }

                          try {
                            await _stopTts();
                            if (_audioState == PlayerState.playing) {
                              await _audio.pause();
                            } else {
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
                          showTts
                              ? (_ttsSpeaking ? Icons.stop_circle : Icons.record_voice_over)
                              : (_audioState == PlayerState.playing
                                  ? Icons.pause_circle_filled
                                  : Icons.play_circle_fill),
                          size: 34,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Audio',
                          style: TextStyle(color: Colors.grey.shade800, fontWeight: FontWeight.w700),
                        ),
                      ),
                      IconButton(
                        tooltip: 'Dừng',
                        onPressed: () async {
                          await _stopAudio();
                          await _stopTts();
                        },
                        icon: const Icon(Icons.stop_circle_outlined),
                      ),
                    ],
                  ),
                  if (!showTts) ...[
                    Slider(
                      value: _audioPosition.inMilliseconds
                          .clamp(0, _audioDuration.inMilliseconds == 0 ? 0 : _audioDuration.inMilliseconds)
                          .toDouble(),
                      max: (_audioDuration.inMilliseconds == 0 ? 1 : _audioDuration.inMilliseconds).toDouble(),
                      onChanged: (v) async {
                        try {
                          await _audio.seek(Duration(milliseconds: v.toInt()));
                        } catch (_) {
                          // ignore
                        }
                      },
                    ),
                    Row(
                      children: [
                        Text(
                          _formatTime((_audioPosition.inSeconds).clamp(0, 999999)),
                          style: TextStyle(color: Colors.grey.shade700, fontWeight: FontWeight.w600),
                        ),
                        const Spacer(),
                        Text(
                          _formatTime((_audioDuration.inSeconds).clamp(0, 999999)),
                          style: TextStyle(color: Colors.grey.shade700, fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
          const SizedBox(height: 14),
          if (qType == 'MCQ')
            ...choices.map((c) {
              final m = (c as Map).cast<String, dynamic>();
              final id = (m['id'] ?? '').toString();
              final content = _stripHtml((m['content'] ?? '').toString());
              final selected = d['selectedChoiceId'] == id;
              final primary = Theme.of(context).colorScheme.primary;
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: InkWell(
                  onTap: () {
                    setState(() {
                      _draft[qId] = {
                        ...d,
                        'selectedChoiceId': id,
                        'textAnswer': null,
                      };
                    });
                    _saveCurrent(bestEffort: true);
                  },
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: selected ? primary : Colors.grey.shade300,
                        width: selected ? 2 : 1,
                      ),
                      color: selected ? primary.withValues(alpha: 0.06) : null,
                    ),
                    child: Text(
                      content,
                      style: TextStyle(
                        fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                        color: selected ? primary : null,
                      ),
                    ),
                  ),
                ),
              );
            })
          else
            TextField(
              minLines: qType == 'ESSAY' ? 8 : 2,
              maxLines: qType == 'ESSAY' ? 16 : 4,
              decoration: InputDecoration(
                hintText: qType == 'ESSAY' ? 'Nhập bài viết...' : 'Nhập câu trả lời...',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
              controller: TextEditingController(text: (d['textAnswer'] ?? '').toString())
                ..selection = TextSelection.fromPosition(
                  TextPosition(offset: (d['textAnswer'] ?? '').toString().length),
                ),
              onChanged: (v) {
                setState(() {
                  _draft[qId] = {
                    ...d,
                    'selectedChoiceId': null,
                    'textAnswer': v,
                  };
                });
              },
              onEditingComplete: () {
                FocusScope.of(context).unfocus();
                _saveCurrent(bestEffort: true);
              },
            ),
          const SizedBox(height: 12),
          Row(
            children: [
              OutlinedButton.icon(
                onPressed: () => _saveCurrent(bestEffort: false),
                icon: const Icon(Icons.save_outlined),
                label: const Text('Lưu'),
              ),
              const SizedBox(width: 10),
              OutlinedButton.icon(
                onPressed: () {
                  showDialog(
                    context: context,
                    builder: (_) => AlertDialog(
                      title: const Text('Nộp bài'),
                      content: const Text('Bạn chắc chắn muốn nộp bài?'),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.of(context).pop(),
                          child: const Text('Hủy'),
                        ),
                        ElevatedButton(
                          onPressed: () {
                            Navigator.of(context).pop();
                            _onSubmit();
                          },
                          child: const Text('Nộp'),
                        ),
                      ],
                    ),
                  );
                },
                icon: const Icon(Icons.done_all),
                label: const Text('Nộp'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

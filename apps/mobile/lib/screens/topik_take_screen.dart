import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:audioplayers/audioplayers.dart';

import '../core/api_client.dart';
import '../core/tts_service.dart';

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
  final Set<String> _dirtyQuestionIds = {};
  final Map<String, TextEditingController> _textControllers = {};
  final ScrollController _scroll = ScrollController();
  List<GlobalKey> _questionKeys = [];
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

  bool _ttsSpeaking = false;

  final Map<String, bool> _helperExpanded = {};

  final List<Map<String, String>> _q53Templates = [
    {
      'text': '...에 대해 설문조사를 실시한 결과에 따르면 ',
      'translation': 'Theo kết quả khảo sát về...'
    },
    {
      'text': '...을/를 대상으로 ...에 대한 조사를 실시하였다. ',
      'translation': 'Tiến hành khảo sát đối tượng... về...'
    },
    {
      'text': '...으로 급격히 증가하였다. ',
      'translation': '...tăng nhanh chóng lên...'
    },
    {
      'text': '...에 그치던 것이 ...으로 크게 상승했다. ',
      'translation': 'Chỉ dừng lại ở... nhưng đã tăng mạnh lên...'
    },
    {
      'text': '...에 비해 소폭 감소한 것으로 나타났다. ',
      'translation': 'Cho thấy đã giảm nhẹ so với...'
    },
    {
      'text': '...이/가 가장 높은 비율을 차지했다. ',
      'translation': '...chiếm tỷ lệ cao nhất.'
    },
    {
      'text': '그 뒤를 이어 ... (으)로 나타났다. ',
      'translation': 'Theo sau đó là... .'
    },
    {
      'text': '이러한 변화의 원인은 ... 기인한 것이다. ',
      'translation': 'Nguyên nhân của sự biến đổi này bắt nguồn từ...'
    },
    {
      'text': '... 기인한 것으로 분석된다. ',
      'translation': 'Được phân tích là bắt nguồn từ...'
    },
  ];

  final List<Map<String, String>> _q54Templates = [
    {
      'text': '최근 우리 사회에서 ...에 대한 논란이 끊이지 않고 있다. ',
      'translation': 'Gần đây trong xã hội, tranh luận về... vẫn chưa dứt.'
    },
    {
      'text': '...은/는 현대 사회에서 해결해야 할 중요한 과제 중 하나이다. ',
      'translation': '...là một trong những nhiệm vụ quan trọng cần giải quyết.'
    },
    {
      'text': '첫째, ... 은/는 문제를 유발할 수 있다. ',
      'translation': 'Thứ nhất, ... có thể gây ra vấn đề.'
    },
    {
      'text': '이뿐만 아니라 ... 은/는 긍정적인 영향을 미친다. ',
      'translation': 'Không chỉ vậy, ... còn mang lại ảnh hưởng tích cực.'
    },
    {
      'text': '반면, ...에 대한 부작용도 간과해서는 안 된다. ',
      'translation': 'Mặt khác, tác dụng phụ của... cũng không được xem nhẹ.'
    },
    {
      'text': '따라서 우리는 ... 해결하기 위해 노력을 기울여야 한다. ',
      'translation': 'Vì vậy, chúng ta phải nỗ lực để giải quyết...'
    },
  ];

  final List<Map<String, String>> _keywordsTemplates = [
    {'text': '증가하다 ', 'translation': 'Tăng'},
    {'text': '감소하다 ', 'translation': 'Giảm'},
    {'text': '차지하다 ', 'translation': 'Chiếm'},
    {'text': '기인하다 ', 'translation': 'Bắt nguồn từ'},
    {'text': '원인 ', 'translation': 'Nguyên nhân'},
    {'text': '영향 ', 'translation': 'Ảnh hưởng'},
    {'text': '해결책 ', 'translation': 'Giải pháp'},
    {'text': '찬성하다 ', 'translation': 'Đồng ý'},
    {'text': '반대하다 ', 'translation': 'Phản đối'},
    {'text': '중요성 ', 'translation': 'Tầm quan trọng'},
  ];

  void _insertTemplateText(String qId, int questionIndex, String template) {
    final ctrl = _textControllers[qId];
    if (ctrl == null) return;

    final text = ctrl.text;
    final selection = ctrl.selection;
    String newText;
    int newCursorOffset;

    if (selection.isValid && selection.start >= 0) {
      newText = text.replaceRange(selection.start, selection.end, template);
      newCursorOffset = selection.start + template.length;
    } else {
      newText = text + (text.isEmpty ? '' : ' ') + template;
      newCursorOffset = newText.length;
    }

    ctrl.text = newText;
    ctrl.selection = TextSelection.fromPosition(TextPosition(offset: newCursorOffset));

    final d = _currentDraft(qId);
    setState(() {
      _currentIndex = questionIndex;
      _draft[qId] = {
        ...d,
        'selectedChoiceId': null,
        'textAnswer': newText,
      };
      _dirtyQuestionIds.add(qId);
    });

    _saveQuestion(qId, questionIndex, bestEffort: true);
  }

  Widget _buildScaffoldTabContent(
    String qId,
    int index,
    List<Map<String, String>> items, {
    bool isWrap = false,
  }) {
    if (isWrap) {
      return SingleChildScrollView(
        child: Wrap(
          spacing: 8,
          runSpacing: 8,
          children: items.map((item) {
            final text = item['text']!;
            final translation = item['translation']!;
            return ActionChip(
              label: Text(text),
              tooltip: translation,
              onPressed: () => _insertTemplateText(qId, index, text),
            );
          }).toList(),
        ),
      );
    }

    return ListView.separated(
      itemCount: items.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, i) {
        final item = items[i];
        final text = item['text']!;
        final translation = item['translation']!;

        return InkWell(
          onTap: () => _insertTemplateText(qId, index, text),
          borderRadius: BorderRadius.circular(8),
          child: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Theme.of(context).brightness == Brightness.dark
                  ? const Color(0xFF2D2D34)
                  : Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: Theme.of(context).brightness == Brightness.dark
                    ? const Color(0xFF3A3A42)
                    : Colors.grey.shade200,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  text,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  translation,
                  style: TextStyle(
                    color: Colors.grey.shade600,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildWritingScaffoldHelper(String qId, int index) {
    final isExpanded = _helperExpanded[qId] ?? false;

    if (!isExpanded) {
      return Padding(
        padding: const EdgeInsets.only(top: 8, bottom: 8),
        child: OutlinedButton.icon(
          onPressed: () {
            setState(() {
              _helperExpanded[qId] = true;
            });
          },
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          icon: const Icon(Icons.lightbulb_outline, size: 18),
          label: const Text('💡 Trợ lý viết TOPIK (Mở)'),
        ),
      );
    }

    return Card(
      color: Theme.of(context).brightness == Brightness.dark
          ? const Color(0xFF1E1E24)
          : const Color(0xFFF0F7FF),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: Theme.of(context).primaryColor.withValues(alpha: 0.3),
        ),
      ),
      margin: const EdgeInsets.only(top: 10, bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.lightbulb, color: Colors.amber, size: 20),
                const SizedBox(width: 8),
                const Text(
                  'Dàn ý & Cụm từ gợi ý',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close, size: 18),
                  onPressed: () {
                    setState(() {
                      _helperExpanded[qId] = false;
                    });
                  },
                )
              ],
            ),
            const Divider(),
            DefaultTabController(
              length: 3,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TabBar(
                    isScrollable: true,
                    labelColor: Theme.of(context).primaryColor,
                    unselectedLabelColor: Colors.grey,
                    indicatorColor: Theme.of(context).primaryColor,
                    tabs: const [
                      Tab(text: 'Câu 53 (Biểu đồ)'),
                      Tab(text: 'Câu 54 (Nghị luận)'),
                      Tab(text: 'Từ vựng hay'),
                    ],
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    height: 200,
                    child: TabBarView(
                      children: [
                        _buildScaffoldTabContent(qId, index, _q53Templates),
                        _buildScaffoldTabContent(qId, index, _q54Templates),
                        _buildScaffoldTabContent(qId, index, _keywordsTemplates, isWrap: true),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

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
    unawaited(ref.read(ttsProvider).stop());
    _scroll.dispose();
    for (final c in _textControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _stopTts() async {
    try {
      await ref.read(ttsProvider).stop();
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
      if (!mounted) return;
      setState(() => _ttsSpeaking = true);
      await ref.read(ttsProvider).speakAndWait(text);
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
      final examId = (exam['id'] ?? session['examId'] ?? '').toString();

      // IMPORTANT: For resume sessions, session.answers contains only answered questions.
      // We must always build the full question list from exam detail.
      List<Map<String, dynamic>> qs = <Map<String, dynamic>>[];
      if (examId.isNotEmpty) {
        try {
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
        } catch (_) {
          qs = <Map<String, dynamic>>[];
        }
      }

      if (qs.isEmpty) {
        // Fallback: best-effort when exam detail not available.
        qs = answers
            .map((a) => (a as Map<String, dynamic>)['question'])
            .whereType<Map<String, dynamic>>()
            .toList();
      }

      final scopedTypes = (session['sectionTypes'] as List?)?.map((e) => e.toString()).toSet() ?? <String>{};
      if (scopedTypes.isNotEmpty) {
        qs = qs.where((q) {
          final section = (q['section'] as Map?)?.cast<String, dynamic>();
          final type = (section?['type'] ?? '').toString();
          return scopedTypes.contains(type);
        }).toList();
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
        _questionKeys = List.generate(qs.length, (_) => GlobalKey());
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

      // Initialize controllers for text questions.
      for (final q in qs) {
        final qId = (q['id'] ?? '').toString();
        if (qId.isEmpty) continue;
        final qType = (q['questionType'] ?? '').toString();
        if (qType == 'MCQ') continue;
        final d = _currentDraft(qId);
        final text = (d['textAnswer'] ?? '').toString();
        final ctrl = _textControllers[qId];
        if (ctrl == null) {
          _textControllers[qId] = TextEditingController(text: text);
        } else {
          if (ctrl.text != text) ctrl.text = text;
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
      _autosaveDirty();
    });
  }

  String _stripHtml(String html) {
    return html.replaceAll(RegExp(r'<[^>]*>'), '').replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  Map<String, dynamic> _currentDraft(String qId) {
    return (_draft[qId] as Map?)?.cast<String, dynamic>() ?? {
      'selectedChoiceId': null,
      'textAnswer': '',
      'flagged': false,
    };
  }

  Future<void> _saveQuestion(
    String qId,
    int questionIndex, {
    required bool bestEffort,
  }) async {
    if (qId.isEmpty) return;
    if (questionIndex < 0 || questionIndex >= _questions.length) return;
    final d = _currentDraft(qId);
    final api = ref.read(apiClientProvider);
    try {
      await api.saveTopikAnswer(
        widget.sessionId,
        questionId: qId,
        selectedChoiceId: d['selectedChoiceId'] as String?,
        textAnswer: d['textAnswer'] as String?,
        currentQuestionIndex: questionIndex,
        remainingSeconds: _remainingSeconds,
        flagged: d['flagged'] == true,
      );
      _dirtyQuestionIds.remove(qId);
    } catch (_) {
      if (!bestEffort && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Không thể lưu đáp án.')),
        );
      }
    }
  }

  Future<void> _autosaveDirty() async {
    if (_dirtyQuestionIds.isEmpty) return;
    // Copy to avoid concurrent modification.
    final ids = _dirtyQuestionIds.toList(growable: false);
    for (final qId in ids) {
      final idx = _questions.indexWhere((q) => (q as Map)['id']?.toString() == qId);
      if (idx < 0) {
        _dirtyQuestionIds.remove(qId);
        continue;
      }
      await _saveQuestion(qId, idx, bestEffort: true);
    }
  }

  Future<void> _onSubmit({bool auto = false}) async {
    await _autosaveDirty();
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

    final targetContext = _questionKeys[index].currentContext;

    _stopAudio();
    _stopTts();
    if (!mounted) return;
    setState(() => _currentIndex = index);

    if (targetContext != null) {
      Scrollable.ensureVisible(
        targetContext,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
        alignment: 0.1,
      );
    }
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
                  _formatTime(_remainingSeconds),
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
                  : _buildAllQuestions(),
      bottomNavigationBar: _loading || _questions.isEmpty
          ? null
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _dirtyQuestionIds.isNotEmpty
                            ? () async {
                                final messenger = ScaffoldMessenger.of(context);
                                await _autosaveDirty();
                                if (!mounted) return;
                                messenger.showSnackBar(
                                  const SnackBar(content: Text('Đã lưu tiến độ.')),
                                );
                              }
                            : null,
                        icon: const Icon(Icons.save_outlined),
                        label: const Text('Lưu'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () => _onSubmit(),
                        icon: const Icon(Icons.done_all),
                        label: const Text('Nộp bài'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildAllQuestions() {
    return ListView.builder(
      controller: _scroll,
      padding: const EdgeInsets.all(16),
      itemCount: _questions.length,
      itemBuilder: (context, index) {
        final q = (_questions[index] as Map).cast<String, dynamic>();
        return Container(
          key: _questionKeys[index],
          margin: const EdgeInsets.only(bottom: 14),
          child: _buildQuestionItem(q, index),
        );
      },
    );
  }

  Widget _buildQuestionItem(Map<String, dynamic> q, int index) {
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

    return Card(
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
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    sectionType,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade800,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  qType,
                  style: TextStyle(
                    color: Colors.grey.shade700,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                IconButton(
                  tooltip: 'Đánh dấu',
                  onPressed: () async {
                    setState(() {
                      final cur = _currentDraft(qId);
                      _draft[qId] = {
                        ...cur,
                        'flagged': !(cur['flagged'] == true),
                      };
                      _dirtyQuestionIds.add(qId);
                      _currentIndex = index;
                    });
                    await _saveQuestion(qId, index, bestEffort: true);
                  },
                  icon: Icon(
                    d['flagged'] == true ? Icons.flag : Icons.outlined_flag,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
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
                            _currentIndex = index;
                            if (showTts) {
                              if (_ttsSpeaking) {
                                await _stopTts();
                              } else {
                                await _stopAudio();
                                await _speakTts(listeningScript);
                              }
                              return;
                            }

                            await _ensureAudioForQuestion(q);

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
                                ? (_ttsSpeaking
                                    ? Icons.stop_circle
                                    : Icons.record_voice_over)
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
                            style: TextStyle(
                              color: Colors.grey.shade800,
                              fontWeight: FontWeight.w700,
                            ),
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
                            .clamp(
                              0,
                              _audioDuration.inMilliseconds == 0
                                  ? 0
                                  : _audioDuration.inMilliseconds,
                            )
                            .toDouble(),
                        max: (_audioDuration.inMilliseconds == 0
                                ? 1
                                : _audioDuration.inMilliseconds)
                            .toDouble(),
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
                            _formatTime(
                              (_audioPosition.inSeconds).clamp(0, 999999),
                            ),
                            style: TextStyle(
                              color: Colors.grey.shade700,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const Spacer(),
                          Text(
                            _formatTime(
                              (_audioDuration.inSeconds).clamp(0, 999999),
                            ),
                            style: TextStyle(
                              color: Colors.grey.shade700,
                              fontWeight: FontWeight.w600,
                            ),
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
                        _currentIndex = index;
                        _draft[qId] = {
                          ...d,
                          'selectedChoiceId': id,
                          'textAnswer': null,
                        };
                        _dirtyQuestionIds.add(qId);
                      });
                      _saveQuestion(qId, index, bestEffort: true);
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
                          fontWeight:
                              selected ? FontWeight.w700 : FontWeight.w500,
                          color: selected ? primary : null,
                        ),
                      ),
                    ),
                  ),
                );
              })
            else ...[
              if (qType == 'ESSAY')
                _buildWritingScaffoldHelper(qId, index),
              TextField(
                minLines: qType == 'ESSAY' ? 8 : 2,
                maxLines: qType == 'ESSAY' ? 16 : 4,
                decoration: InputDecoration(
                  hintText:
                      qType == 'ESSAY' ? 'Nhập bài viết...' : 'Nhập câu trả lời...',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                controller: _textControllers.putIfAbsent(
                  qId,
                  () => TextEditingController(
                    text: (d['textAnswer'] ?? '').toString(),
                  ),
                ),
                onChanged: (v) {
                  setState(() {
                    _currentIndex = index;
                    _draft[qId] = {
                      ...d,
                      'selectedChoiceId': null,
                      'textAnswer': v,
                    };
                    _dirtyQuestionIds.add(qId);
                  });
                },
                onEditingComplete: () async {
                  FocusScope.of(context).unfocus();
                  await _saveQuestion(qId, index, bestEffort: true);
                },
              ),
            ],
          ],
        ),
      ),
    );
  }
}

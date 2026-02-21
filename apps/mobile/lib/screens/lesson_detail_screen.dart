import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:audioplayers/audioplayers.dart';
import '../core/api_client.dart';
import '../core/tts_service.dart';
import '../providers/app_settings_provider.dart';

class LessonDetailScreen extends ConsumerStatefulWidget {
  final String lessonId;
  const LessonDetailScreen({super.key, required this.lessonId});

  @override
  ConsumerState<LessonDetailScreen> createState() => _LessonDetailScreenState();
}

class _LessonDetailScreenState extends ConsumerState<LessonDetailScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;
  Map<String, dynamic>? _lesson;
  List<dynamic> _vocab = [], _grammar = [], _dialogues = [], _quizzes = [];
  bool _loading = true;
  int _currentVocabIndex = 0;
  bool _showMeaning = false;
  bool _vocabListView = false;
  bool _isDialoguePlaying = false;
  int _dialoguePlaySession = 0;
  int? _playingDialogueIndex;
  List<GlobalKey> _dialogueItemKeys = [];
  late AudioPlayer _audioPlayer;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 4, vsync: this);
    _tabCtrl.addListener(() {
      if (!mounted) return;
      setState(() {});
    });
    _audioPlayer = AudioPlayer();
    _loadData();
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    _audioPlayer.dispose();
    super.dispose();
  }

  Future<void> _playAudio(String url) async {
    try {
      await _audioPlayer.play(UrlSource(url));
    } catch (_) {}
  }

  void _speakKorean(String text) {
    ref.read(ttsProvider).speak(text);
  }

  Future<void> _stopDialoguePlayback() async {
    _dialoguePlaySession++;
    if (mounted) {
      setState(() {
        _isDialoguePlaying = false;
        _playingDialogueIndex = null;
      });
    }
    try {
      await _audioPlayer.stop();
    } catch (_) {}
    try {
      await ref.read(ttsProvider).stop();
    } catch (_) {}
  }

  void _setPlayingDialogueIndex(int? index) {
    if (!mounted) return;

    setState(() {
      _playingDialogueIndex = index;
    });

    if (index == null) return;
    if (index < 0 || index >= _dialogueItemKeys.length) return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final ctx = _dialogueItemKeys[index].currentContext;
      if (ctx == null) return;
      Scrollable.ensureVisible(
        ctx,
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOut,
        alignment: 0.2,
      );
    });
  }

  Future<void> _playAllDialogues() async {
    if (_dialogues.isEmpty) return;

    final session = ++_dialoguePlaySession;
    if (mounted) setState(() => _isDialoguePlaying = true);

    try {
      for (var i = 0; i < _dialogues.length; i++) {
        final item = _dialogues[i];
        if (!mounted) return;
        if (session != _dialoguePlaySession) return;

        _setPlayingDialogueIndex(i);

        final d = item as dynamic;
        final koreanText = (d['koreanText'] ?? '').toString();
        final audioUrl = (d['audioUrl'] ?? '').toString();

        if (audioUrl.isNotEmpty) {
          try {
            await _audioPlayer.stop();
          } catch (_) {}

          try {
            final done = Completer<void>();
            final sub = _audioPlayer.onPlayerComplete.listen((_) {
              if (!done.isCompleted) done.complete();
            });

            await _audioPlayer.play(UrlSource(audioUrl));

            try {
              await done.future.timeout(const Duration(seconds: 30));
            } catch (_) {
              // Don't hang forever if the completion event doesn't fire.
            } finally {
              await sub.cancel();
            }
          } catch (_) {
            if (koreanText.isNotEmpty) {
              await ref.read(ttsProvider).speakAndWait(
                    koreanText,
                    timeout: const Duration(seconds: 12),
                  );
            }
          }
        } else {
          if (koreanText.isNotEmpty) {
            await ref.read(ttsProvider).speakAndWait(
                  koreanText,
                  timeout: const Duration(seconds: 12),
                );
          }
        }

        if (session != _dialoguePlaySession) return;
        await Future.delayed(const Duration(milliseconds: 650));
      }
    } finally {
      if (mounted && session == _dialoguePlaySession) {
        setState(() {
          _isDialoguePlaying = false;
          _playingDialogueIndex = null;
        });
      }
    }
  }

  Future<void> _loadData() async {
    final api = ref.read(apiClientProvider);
    try {
      final lessonRes = await api.getLesson(widget.lessonId);
      _lesson = lessonRes.data;
      _vocab = _lesson?['vocabularies'] ?? [];
      _grammar = _lesson?['grammars'] ?? [];
      _dialogues = _lesson?['dialogues'] ?? [];
      _quizzes = _lesson?['quizzes'] ?? [];
      _dialogueItemKeys = List.generate(_dialogues.length, (_) => GlobalKey());
      if (mounted) setState(() => _loading = false);

      // Track progress: mark lesson as visited and add XP
      _trackProgress();
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _trackProgress() async {
    try {
      final api = ref.read(apiClientProvider);
      // Mark lesson as completed
      await api.updateProgress(widget.lessonId, completed: true);
      // Award XP for studying (10 XP per lesson visit)
      await api.addXP(10);
      // Update streak
      await api.updateStreak();
    } catch (_) {
      // Silently fail - progress tracking should not block UX
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final themeId = ref.watch(appSettingsProvider).themeId;
    final theme = AppSettingsNotifier.themeById(themeId);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          _lesson?['title'] ?? '',
          style: const TextStyle(fontSize: 16),
        ),
        foregroundColor: Colors.white,
        backgroundColor: Colors.transparent,
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: theme.gradient),
          ),
        ),
        actions: [
          if (_tabCtrl.index == 0)
            IconButton(
              tooltip:
                  _vocabListView ? 'Xem dạng card lật' : 'Xem dạng danh sách',
              icon: Icon(_vocabListView ? Icons.style : Icons.view_list),
              onPressed: () {
                setState(() {
                  _vocabListView = !_vocabListView;
                  _showMeaning = false;
                });
              },
            ),
        ],
        bottom: TabBar(
          controller: _tabCtrl,
          isScrollable: true,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white.withValues(alpha: 0.75),
          indicatorColor: Colors.white,
          labelStyle: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
          tabAlignment: TabAlignment.start,
          tabs: [
            Tab(text: 'Từ vựng (${_vocab.length})'),
            Tab(text: 'Ngữ pháp (${_grammar.length})'),
            Tab(text: 'Hội thoại (${_dialogues.length})'),
            Tab(text: 'Bài tập (${_quizzes.length})'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabCtrl,
        children: [
          _buildVocabTab(),
          _buildGrammarTab(),
          _buildDialogueTab(),
          _buildQuizTab(),
        ],
      ),
    );
  }

  // Flashcard-style vocab
  Widget _buildVocabTab() {
    if (_vocab.isEmpty) return const Center(child: Text('Chưa có từ vựng'));
    final themeId = ref.watch(appSettingsProvider).themeId;
    final theme = AppSettingsNotifier.themeById(themeId);

    if (_vocabListView) {
      return ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: _vocab.length,
        separatorBuilder: (_, __) => const SizedBox(height: 8),
        itemBuilder: (_, i) {
          final v = _vocab[i];
          return Card(
            child: ListTile(
              title: Text(
                v['korean'] ?? '',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 4),
                  if ((v['pronunciation'] ?? '').toString().isNotEmpty)
                    Text(
                      v['pronunciation'] ?? '',
                      style: TextStyle(color: Colors.grey.shade600),
                    ),
                  const SizedBox(height: 2),
                  Text(
                    v['vietnamese'] ?? '',
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF10B981),
                    ),
                  ),
                  if ((v['exampleSentence'] ?? '').toString().isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(
                      v['exampleSentence'] ?? '',
                      style: TextStyle(
                        fontStyle: FontStyle.italic,
                        color: Colors.grey.shade700,
                      ),
                    ),
                    if ((v['exampleMeaning'] ?? '').toString().isNotEmpty)
                      Text(
                        v['exampleMeaning'] ?? '',
                        style: TextStyle(color: Colors.grey.shade600),
                      ),
                  ],
                ],
              ),
              trailing: IconButton(
                icon: Icon(Icons.volume_up, color: theme.seedColor),
                onPressed: () => _speakKorean((v['korean'] ?? '').toString()),
              ),
              onTap: () {
                setState(() {
                  _currentVocabIndex = i;
                  _vocabListView = false;
                  _showMeaning = false;
                });
              },
            ),
          );
        },
      );
    }

    final v = _vocab[_currentVocabIndex];
    return Column(
      children: [
        Expanded(
          child: GestureDetector(
            onTap: () => setState(() => _showMeaning = !_showMeaning),
            onHorizontalDragEnd: (details) {
              if (details.primaryVelocity! < 0 &&
                  _currentVocabIndex < _vocab.length - 1) {
                setState(() {
                  _currentVocabIndex++;
                  _showMeaning = false;
                });
              } else if (details.primaryVelocity! > 0 &&
                  _currentVocabIndex > 0) {
                setState(() {
                  _currentVocabIndex--;
                  _showMeaning = false;
                });
              }
            },
            child: Container(
              margin: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    theme.seedColor.withValues(alpha: 0.05),
                    theme.gradient.length > 1
                        ? theme.gradient[1].withValues(alpha: 0.05)
                        : theme.seedColor.withValues(alpha: 0.05),
                  ],
                ),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Center(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  child: _showMeaning
                      ? Column(
                          key: const ValueKey('meaning'),
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              v['korean'] ?? '',
                              style: const TextStyle(
                                fontSize: 48,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              v['pronunciation'] ?? '',
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.grey.shade600,
                              ),
                            ),
                            const SizedBox(height: 12),
                            IconButton(
                              icon: Icon(Icons.volume_up,
                                  size: 32, color: theme.seedColor),
                              onPressed: () => _speakKorean(v['korean'] ?? ''),
                            ),
                            const SizedBox(height: 16),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 20,
                                vertical: 10,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFF10B981)
                                    .withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                v['vietnamese'] ?? '',
                                style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF10B981),
                                ),
                              ),
                            ),
                            if (v['exampleSentence'] != null &&
                                v['exampleSentence'] != '') ...[
                              const SizedBox(height: 20),
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 30,
                                ),
                                child: Column(
                                  children: [
                                    Text(
                                      v['exampleSentence'] ?? '',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: Colors.grey.shade700,
                                      ),
                                    ),
                                    if (v['exampleMeaning'] != null)
                                      Text(
                                        v['exampleMeaning'] ?? '',
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey.shade500,
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ],
                          ],
                        )
                      : Column(
                          key: const ValueKey('question'),
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              v['korean'] ?? '',
                              style: const TextStyle(
                                fontSize: 56,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              v['pronunciation'] ?? '',
                              style: TextStyle(
                                fontSize: 18,
                                color: Colors.grey.shade600,
                              ),
                            ),
                            const SizedBox(height: 12),
                            IconButton(
                              icon: Icon(Icons.volume_up,
                                  size: 32, color: theme.seedColor),
                              onPressed: () => _speakKorean(v['korean'] ?? ''),
                            ),
                            const SizedBox(height: 20),
                            ElevatedButton.icon(
                              onPressed: () async {
                                final api = ref.read(apiClientProvider);
                                final messenger = ScaffoldMessenger.of(context);
                                try {
                                  await api.addToReview(v['id']);
                                  if (!mounted) return;
                                  messenger.showSnackBar(
                                    const SnackBar(
                                      content: Text('Đã thêm vào danh sách ôn tập!'),
                                    ),
                                  );
                                } catch (_) {
                                  if (!mounted) return;
                                  messenger.showSnackBar(
                                    const SnackBar(
                                      content: Text('Có lỗi xảy ra, vui lòng thử lại'),
                                    ),
                                  );
                                }
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor:
                                    theme.seedColor.withValues(alpha: 0.1),
                                foregroundColor: theme.seedColor,
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              icon: const Icon(Icons.bookmark_add_outlined),
                              label: const Text('Thêm vào ôn tập'),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'Tap để xem nghĩa',
                              style: TextStyle(
                                color: Colors.grey.shade400,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                ),
              ),
            ),
          ),
        ),
        if (v['audioUrl'] != null && v['audioUrl'].toString().isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: FloatingActionButton(
              heroTag: 'vocab_audio',
              backgroundColor: theme.seedColor,
              onPressed: () => _playAudio(v['audioUrl']),
              child: const Icon(Icons.volume_up, color: Colors.white),
            ),
          ),
        // Progress
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back_ios_rounded),
                onPressed: _currentVocabIndex > 0
                    ? () => setState(() {
                          _currentVocabIndex--;
                          _showMeaning = false;
                        })
                    : null,
              ),
              Text(
                '${_currentVocabIndex + 1} / ${_vocab.length}',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              IconButton(
                icon: const Icon(Icons.arrow_forward_ios_rounded),
                onPressed: _currentVocabIndex < _vocab.length - 1
                    ? () => setState(() {
                          _currentVocabIndex++;
                          _showMeaning = false;
                        })
                    : null,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildGrammarTab() {
    if (_grammar.isEmpty) return const Center(child: Text('Chưa có ngữ pháp'));
    final themeId = ref.watch(appSettingsProvider).themeId;
    final theme = AppSettingsNotifier.themeById(themeId);
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _grammar.length,
      itemBuilder: (_, i) {
        final g = _grammar[i];
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  g['pattern'] ?? '',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.volume_up, color: theme.seedColor, size: 20),
                  onPressed: () => _speakKorean(g['pattern'] ?? ''),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
                const SizedBox(height: 8),
                Text(
                  g['explanationVN'] ?? '',
                  style: const TextStyle(fontSize: 14),
                ),
                if (g['example'] != null) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            g['example'],
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.grey.shade700,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ),
                        IconButton(
                          icon: Icon(Icons.volume_up,
                              color: theme.seedColor, size: 18),
                          onPressed: () => _speakKorean(g['example'] ?? ''),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildDialogueTab() {
    if (_dialogues.isEmpty) {
      return const Center(child: Text('Chưa có hội thoại'));
    }
    final themeId = ref.watch(appSettingsProvider).themeId;
    final theme = AppSettingsNotifier.themeById(themeId);
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _isDialoguePlaying
                      ? _stopDialoguePlayback
                      : _playAllDialogues,
                  icon:
                      Icon(_isDialoguePlaying ? Icons.stop : Icons.play_arrow),
                  label: Text(_isDialoguePlaying ? 'Dừng phát' : 'Phát tất cả'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: theme.seedColor,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              OutlinedButton(
                onPressed: _stopDialoguePlayback,
                style: OutlinedButton.styleFrom(
                  foregroundColor: theme.seedColor,
                  side:
                      BorderSide(color: theme.seedColor.withValues(alpha: 0.6)),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text('Reset'),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            itemCount: _dialogues.length,
            itemBuilder: (_, i) {
              final d = _dialogues[i];
              final isLeft = i % 2 == 0;
              final isPlaying = _isDialoguePlaying && _playingDialogueIndex == i;
              return Padding(
                key: _dialogueItemKeys.length > i ? _dialogueItemKeys[i] : null,
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  mainAxisAlignment:
                      isLeft ? MainAxisAlignment.start : MainAxisAlignment.end,
                  children: [
                    if (isLeft)
                      CircleAvatar(
                        radius: 16,
                        backgroundColor: theme.seedColor.withValues(alpha: 0.2),
                        child: Text(
                          (d['speaker'] ?? '?')[0],
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: theme.seedColor,
                          ),
                        ),
                      ),
                    if (isLeft) const SizedBox(width: 8),
                    Container(
                      constraints: BoxConstraints(
                        maxWidth: MediaQuery.of(context).size.width * 0.65,
                      ),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: isPlaying
                            ? theme.seedColor.withValues(alpha: 0.14)
                            : (isLeft
                                ? Colors.white
                                : theme.seedColor.withValues(alpha: 0.1)),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isPlaying
                              ? theme.seedColor.withValues(alpha: 0.55)
                              : Colors.grey.shade200,
                          width: isPlaying ? 1.4 : 1.0,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            d['speaker'] ?? '',
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.grey.shade500,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Flexible(
                                child: Text(
                                  d['koreanText'] ?? '',
                                  style: const TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                              if (isPlaying) ...[
                                const SizedBox(width: 6),
                                Icon(
                                  Icons.graphic_eq,
                                  size: 16,
                                  color: theme.seedColor,
                                ),
                              ],
                              GestureDetector(
                                onTap: () =>
                                    _speakKorean(d['koreanText'] ?? ''),
                                child: Padding(
                                  padding: const EdgeInsets.only(left: 4),
                                  child: Icon(Icons.volume_up,
                                      size: 16, color: theme.seedColor),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (d['audioUrl'] != null &&
                                  d['audioUrl'].toString().isNotEmpty) ...[
                                GestureDetector(
                                  onTap: () => _playAudio(d['audioUrl']),
                                  child: Icon(Icons.volume_up,
                                      size: 16, color: theme.seedColor),
                                ),
                                const SizedBox(width: 4),
                              ],
                              Expanded(
                                child: Text(
                                  d['vietnameseText'] ?? '',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey.shade600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    if (!isLeft) const SizedBox(width: 8),
                    if (!isLeft)
                      CircleAvatar(
                        radius: 16,
                        backgroundColor: theme.seedColor.withValues(alpha: 0.2),
                        child: Text(
                          (d['speaker'] ?? '?')[0],
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: theme.seedColor,
                          ),
                        ),
                      ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildQuizTab() {
    if (_quizzes.isEmpty) return const Center(child: Text('Chưa có bài tập'));
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _quizzes.length,
      itemBuilder: (_, i) {
        final q = _quizzes[i];
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: ListTile(
            leading: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: Colors.orange.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Center(
                child: Icon(Icons.quiz, color: Colors.orange),
              ),
            ),
            title: Text(
              q['title'] ?? '',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            subtitle: Text(
              '${q['quizType']} · ${(q['questions'] as List?)?.length ?? 0} câu hỏi',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
            ),
            trailing: const Icon(
              Icons.play_arrow_rounded,
              color: Colors.black,
            ),
            onTap: () => context.push('/quiz/${q['id']}'),
          ),
        );
      },
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../core/api_client.dart';

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

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 4, vsync: this);
    _loadData();
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
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
      if (mounted) setState(() => _loading = false);
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(
          _lesson?['title'] ?? '',
          style: const TextStyle(fontSize: 16),
        ),
        bottom: TabBar(
          controller: _tabCtrl,
          labelColor: const Color(0xFF2563EB),
          unselectedLabelColor: Colors.grey,
          indicatorColor: const Color(0xFF2563EB),
          labelStyle: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
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
                    const Color(0xFF2563EB).withValues(alpha: 0.05),
                    const Color(0xFF7C3AED).withValues(alpha: 0.05),
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
                            const SizedBox(height: 16),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 20,
                                vertical: 10,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFF10B981).withValues(alpha: 0.1),
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
                            const SizedBox(height: 20),
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
                    color: Color(0xFF2563EB),
                  ),
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
                    child: Text(
                      g['example'],
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey.shade700,
                        fontStyle: FontStyle.italic,
                      ),
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
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _dialogues.length,
      itemBuilder: (_, i) {
        final d = _dialogues[i];
        final isLeft = i % 2 == 0;
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Row(
            mainAxisAlignment:
                isLeft ? MainAxisAlignment.start : MainAxisAlignment.end,
            children: [
              if (isLeft)
                CircleAvatar(
                  radius: 16,
                  backgroundColor: const Color(0xFF2563EB).withValues(alpha: 0.2),
                  child: Text(
                    (d['speaker'] ?? '?')[0],
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF2563EB),
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
                  color: isLeft
                      ? Colors.white
                      : const Color(0xFF2563EB).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.grey.shade200),
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
                    Text(
                      d['koreanText'] ?? '',
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      d['vietnameseText'] ?? '',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
              if (!isLeft) const SizedBox(width: 8),
              if (!isLeft)
                CircleAvatar(
                  radius: 16,
                  backgroundColor: Colors.purple.withValues(alpha: 0.2),
                  child: Text(
                    (d['speaker'] ?? '?')[0],
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Colors.purple,
                    ),
                  ),
                ),
            ],
          ),
        );
      },
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
              color: Color(0xFF2563EB),
            ),
            onTap: () => context.push('/quiz/${q['id']}'),
          ),
        );
      },
    );
  }
}

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api_client.dart';
import '../../core/prompt_generator.dart';
import '../../providers/app_settings_provider.dart';
import '../../providers/auth_provider.dart';

class AdminLessonDetailScreen extends ConsumerStatefulWidget {
  final String lessonId;
  const AdminLessonDetailScreen({super.key, required this.lessonId});

  @override
  ConsumerState<AdminLessonDetailScreen> createState() =>
      _AdminLessonDetailScreenState();
}

class _AdminLessonDetailScreenState
    extends ConsumerState<AdminLessonDetailScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tab;

  bool _loading = true;
  String? _error;
  bool _aiLoading = false;

  final Set<String> _selectedVocabIds = <String>{};
  final Set<String> _selectedGrammarIds = <String>{};
  final Set<String> _selectedDialogueIds = <String>{};
  final Set<String> _selectedQuizIds = <String>{};

  List<Map<String, String>> _models = [];
  bool _modelsLoading = false;
  String? _modelsError;
  Map<String, dynamic>? _quota;

  Map<String, dynamic>? _lesson;
  List<dynamic> _vocab = [];
  List<dynamic> _grammar = [];
  List<dynamic> _dialogues = [];
  List<dynamic> _quizzes = [];

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 4, vsync: this);
    _tab.addListener(() {
      if (!_tab.indexIsChanging) return;
      setState(() {
        _selectedVocabIds.clear();
        _selectedGrammarIds.clear();
        _selectedDialogueIds.clear();
        _selectedQuizIds.clear();
      });
    });
    _load();
    _loadModels();
  }

  Future<void> _loadModels() async {
    setState(() {
      _modelsLoading = true;
      _modelsError = null;
      _quota = null;
    });

    try {
      final api = ref.read(apiClientProvider);
      final provider = ref.read(appSettingsProvider).adminAiProvider;
      final res = await api.adminListAiModels(provider: provider);
      final data = res.data;
      if (!mounted) return;
      final modelsRaw = (data is Map) ? data['models'] : null;
      final list = <Map<String, String>>[];
      if (modelsRaw is List) {
        for (final m in modelsRaw) {
          if (m is Map) {
            final id = (m['id'] ?? '').toString();
            final label = (m['label'] ?? id).toString();
            if (id.isNotEmpty) list.add({'id': id, 'label': label});
          }
        }
      }
      setState(() {
        _models = list;
        _quota = (data is Map && data['quota'] is Map)
            ? (data['quota'] as Map).cast<String, dynamic>()
            : null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _modelsError = e.toString());
    } finally {
      if (mounted) setState(() => _modelsLoading = false);
    }
  }

  Future<int?> _askCount({
    required String title,
    required int defaultValue,
  }) async {
    final ctrl = TextEditingController(text: defaultValue.toString());
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: ctrl,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: 'Số lượng',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Hủy'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Tạo'),
          ),
        ],
      ),
    );

    if (ok != true) return null;
    final v = int.tryParse(ctrl.text.trim());
    if (v == null || v <= 0) return null;
    return v;
  }

  Future<void> _aiGenerate(String kind) async {
    if (_aiLoading) return;

    int defaultCount;
    String label;
    if (kind == 'vocab') {
      defaultCount = 10;
      label = 'từ vựng';
    } else if (kind == 'grammar') {
      defaultCount = 5;
      label = 'ngữ pháp';
    } else if (kind == 'dialogues') {
      defaultCount = 10;
      label = 'hội thoại';
    } else {
      defaultCount = 1;
      label = 'quiz';
    }

    final count = await _askCount(
      title: 'AI tạo $label',
      defaultValue: defaultCount,
    );
    if (count == null) return;

    setState(() => _aiLoading = true);
    if (mounted) {
      showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (_) => const AlertDialog(
          content: SizedBox(
            height: 64,
            child: Row(
              children: [
                SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                SizedBox(width: 16),
                Expanded(child: Text('AI đang tạo nội dung...')),
              ],
            ),
          ),
        ),
      );
    }
    try {
      final api = ref.read(apiClientProvider);
      final settings = ref.read(appSettingsProvider);
      final provider = settings.adminAiProvider;
      final model = settings.adminAiModel;
      dynamic res;
      if (kind == 'vocab') {
        res = await api.adminGenerateVocabulary(
          widget.lessonId,
          count: count,
          provider: provider,
          model: model,
        );
      } else if (kind == 'grammar') {
        res = await api.adminGenerateGrammar(
          widget.lessonId,
          count: count,
          provider: provider,
          model: model,
        );
      } else if (kind == 'dialogues') {
        res = await api.adminGenerateDialogues(
          widget.lessonId,
          count: count,
          provider: provider,
          model: model,
        );
      } else {
        res = await api.adminGenerateQuizzes(
          widget.lessonId,
          count: count,
          provider: provider,
          model: model,
        );
      }
      if (!mounted) return;
      await _load();
      if (!mounted) return;

      String msg = 'Đã tạo $count $label (AI)';
      try {
        final data = res?.data;
        final inserted = (data is Map) ? data['inserted'] : null;
        final skipped = (data is Map) ? data['skippedExisting'] : null;
        if (inserted != null) {
          msg = 'AI gen xong: inserted=$inserted';
          if (skipped != null) msg += ', skipped=$skipped';
        }
      } catch (_) {}
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg)),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('AI gen lỗi: $e')),
      );
    } finally {
      if (mounted && Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      }
      if (mounted) setState(() => _aiLoading = false);
    }
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  String _getContextCourse() =>
      (_lesson?['section']?['course']?['title'] ?? '').toString();
  String _getContextSection() =>
      (_lesson?['section']?['title'] ?? '').toString();
  String _getContextLesson() => (_lesson?['title'] ?? '').toString();

  void _copyPrompt(String kind) {
    String prompt;
    final course = _getContextCourse();
    final section = _getContextSection();
    final lesson = _getContextLesson();

    if (kind == 'vocab') {
      final existing = _vocab
          .map((v) => ((v as Map)['korean'] ?? '').toString().trim())
          .where((k) => k.isNotEmpty)
          .toList();
      prompt = PromptGenerator.vocabulary(
        courseTitle: course,
        sectionTitle: section,
        lessonTitle: lesson,
        existingKorean: existing,
      );
    } else if (kind == 'grammar') {
      prompt = PromptGenerator.grammar(
        courseTitle: course,
        sectionTitle: section,
        lessonTitle: lesson,
      );
    } else if (kind == 'dialogues') {
      prompt = PromptGenerator.dialogues(
        courseTitle: course,
        sectionTitle: section,
        lessonTitle: lesson,
      );
    } else {
      prompt = PromptGenerator.quiz(
        courseTitle: course,
        sectionTitle: section,
        lessonTitle: lesson,
      );
    }

    _showPromptDialog(prompt, kind);
  }

  void _showPromptDialog(String prompt, String kind) {
    final labels = {
      'vocab': 'Vocabulary',
      'grammar': 'Grammar',
      'dialogues': 'Dialogues',
      'quizzes': 'Quizzes',
    };
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('📋 Prompt: ${labels[kind] ?? kind}'),
        content: SizedBox(
          width: double.maxFinite,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Copy prompt → chạy trên ChatGPT/Gemini/Claude → copy kết quả JSON → bấm Import.',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
              const SizedBox(height: 10),
              Flexible(
                child: SingleChildScrollView(
                  child: SelectableText(
                    prompt,
                    style:
                        const TextStyle(fontSize: 12, fontFamily: 'monospace'),
                  ),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Đóng'),
          ),
          FilledButton.icon(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: prompt));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Đã copy prompt!')),
              );
              Navigator.of(ctx).pop();
            },
            icon: const Icon(Icons.copy),
            label: const Text('Copy'),
          ),
        ],
      ),
    );
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final api = ref.read(apiClientProvider);

      final lessonRes = await api.getLesson(widget.lessonId);
      final vocabRes = await api.getVocabulary(widget.lessonId);
      final grammarRes = await api.getGrammar(widget.lessonId);
      final dialoguesRes = await api.getDialogues(widget.lessonId);
      final quizzesRes = await api.getQuizzes(widget.lessonId);

      if (!mounted) return;
      setState(() {
        _lesson = (lessonRes.data as Map).cast<String, dynamic>();

        final vocabData = vocabRes.data;
        _vocab = (vocabData is Map && vocabData['data'] is List)
            ? (vocabData['data'] as List)
            : (vocabData as List? ?? []);

        _grammar = (grammarRes.data as List?) ?? [];
        _dialogues = (dialoguesRes.data as List?) ?? [];
        _quizzes = (quizzesRes.data as List?) ?? [];

        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _confirmDelete({
    required String title,
    required Future<void> Function() onDelete,
  }) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: const Text('Hành động này không thể hoàn tác.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Hủy'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Xóa'),
          ),
        ],
      ),
    );

    if (ok != true) return;

    try {
      await onDelete();
      if (!mounted) return;
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Lỗi: $e')),
      );
    }
  }

  // Vocabulary
  Future<void> _upsertVocab([Map<String, dynamic>? item]) async {
    final koreanCtrl = TextEditingController(text: item?['korean']?.toString());
    final viCtrl = TextEditingController(text: item?['vietnamese']?.toString());
    final proCtrl =
        TextEditingController(text: item?['pronunciation']?.toString());
    final exSenCtrl =
        TextEditingController(text: item?['exampleSentence']?.toString());
    final exMeanCtrl =
        TextEditingController(text: item?['exampleMeaning']?.toString());
    final audioCtrl =
        TextEditingController(text: item?['audioUrl']?.toString());

    String difficulty = (item?['difficulty']?.toString() ?? 'EASY');

    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(item == null ? 'Thêm từ vựng' : 'Sửa từ vựng'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: koreanCtrl,
                decoration: const InputDecoration(
                  labelText: 'Korean',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: viCtrl,
                decoration: const InputDecoration(
                  labelText: 'Vietnamese',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 10),
              DropdownButtonFormField<String>(
                initialValue: difficulty,
                decoration: const InputDecoration(
                  labelText: 'Difficulty',
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem(value: 'EASY', child: Text('EASY')),
                  DropdownMenuItem(value: 'MEDIUM', child: Text('MEDIUM')),
                  DropdownMenuItem(value: 'HARD', child: Text('HARD')),
                ],
                onChanged: (v) {
                  if (v == null) return;
                  difficulty = v;
                },
              ),
              const SizedBox(height: 10),
              TextField(
                controller: proCtrl,
                decoration: const InputDecoration(
                  labelText: 'Pronunciation',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: audioCtrl,
                decoration: const InputDecoration(
                  labelText: 'Audio URL',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: exSenCtrl,
                minLines: 2,
                maxLines: 4,
                decoration: const InputDecoration(
                  labelText: 'Example sentence',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: exMeanCtrl,
                minLines: 2,
                maxLines: 4,
                decoration: const InputDecoration(
                  labelText: 'Example meaning',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Hủy'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Lưu'),
          ),
        ],
      ),
    );

    if (ok != true) return;

    final payload = <String, dynamic>{
      'lessonId': widget.lessonId,
      'korean': koreanCtrl.text.trim(),
      'vietnamese': viCtrl.text.trim(),
      'difficulty': difficulty,
      'pronunciation': proCtrl.text.trim().isEmpty ? null : proCtrl.text.trim(),
      'audioUrl': audioCtrl.text.trim().isEmpty ? null : audioCtrl.text.trim(),
      'exampleSentence':
          exSenCtrl.text.trim().isEmpty ? null : exSenCtrl.text.trim(),
      'exampleMeaning':
          exMeanCtrl.text.trim().isEmpty ? null : exMeanCtrl.text.trim(),
    };

    if (payload['korean'] == null || (payload['korean'] as String).isEmpty) {
      return;
    }
    if (payload['vietnamese'] == null ||
        (payload['vietnamese'] as String).isEmpty) {
      return;
    }

    final api = ref.read(apiClientProvider);
    if (item == null) {
      await api.createVocabulary(payload);
    } else {
      final id = item['id']?.toString();
      if (id == null || id.isEmpty) return;
      payload.remove('lessonId');
      await api.updateVocabulary(id, payload);
    }

    if (!mounted) return;
    await _load();
  }

  Future<void> _bulkImportVocab() async {
    final ctrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Bulk import vocabulary JSON'),
        content: SizedBox(
          width: double.maxFinite,
          child: TextField(
            controller: ctrl,
            minLines: 10,
            maxLines: 18,
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              hintText: '[{ "korean": "...", "vietnamese": "..." }, ...]',
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Hủy'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Import'),
          ),
        ],
      ),
    );

    if (ok != true) return;

    try {
      final raw = ctrl.text.trim();
      if (raw.isEmpty) return;
      final decoded = jsonDecode(raw);
      if (decoded is! List) return;

      final items = decoded.map<Map<String, dynamic>>((e) {
        final m = (e as Map).cast<String, dynamic>();
        return {
          'lessonId': widget.lessonId,
          'korean': m['korean'],
          'vietnamese': m['vietnamese'],
          'pronunciation': m['pronunciation'],
          'exampleSentence': m['exampleSentence'],
          'exampleMeaning': m['exampleMeaning'],
          'audioUrl': m['audioUrl'],
          'difficulty': m['difficulty'] ?? 'EASY',
        };
      }).toList();

      final api = ref.read(apiClientProvider);
      await api.createVocabularyBulk(items);
      if (!mounted) return;
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Lỗi import: $e')),
      );
    }
  }

  Future<void> _bulkImportGrammar() async {
    final result = await _showImportDialog(
      'Import Grammar JSON',
      '[{ "pattern": "...", "explanationVN": "...", "example": "..." }, ...]',
    );
    if (result == null) return;

    try {
      final decoded = jsonDecode(result);
      if (decoded is! List) return;

      final api = ref.read(apiClientProvider);
      int count = 0;
      for (final e in decoded) {
        final m = (e as Map).cast<String, dynamic>();
        await api.createGrammar({
          'lessonId': widget.lessonId,
          'pattern': m['pattern'] ?? '',
          'explanationVN': m['explanationVN'] ?? '',
          'example': m['example'] ?? '',
        });
        count++;
      }
      if (!mounted) return;
      await _load();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Imported $count grammar items')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Lỗi import: $e')),
      );
    }
  }

  Future<void> _bulkImportDialogues() async {
    final result = await _showImportDialog(
      'Import Dialogues JSON',
      '[{ "speaker": "A", "koreanText": "...", "vietnameseText": "...", "orderIndex": 0 }, ...]',
    );
    if (result == null) return;

    try {
      final decoded = jsonDecode(result);
      if (decoded is! List) return;

      final api = ref.read(apiClientProvider);
      int count = 0;
      for (final e in decoded) {
        final m = (e as Map).cast<String, dynamic>();
        await api.createDialogue({
          'lessonId': widget.lessonId,
          'speaker': m['speaker'] ?? '',
          'koreanText': m['koreanText'] ?? '',
          'vietnameseText': m['vietnameseText'] ?? '',
          'audioUrl': m['audioUrl'],
          'orderIndex': m['orderIndex'] ?? count,
        });
        count++;
      }
      if (!mounted) return;
      await _load();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Imported $count dialogue lines')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Lỗi import: $e')),
      );
    }
  }

  Future<void> _bulkImportQuizzes() async {
    final result = await _showImportDialog(
      'Import Quizzes JSON',
      '[{ "title": "...", "quizType": "MULTIPLE_CHOICE", "questions": [...] }]',
    );
    if (result == null) return;

    try {
      final decoded = jsonDecode(result);
      if (decoded is! List) return;

      final api = ref.read(apiClientProvider);
      int count = 0;
      for (final e in decoded) {
        final m = (e as Map).cast<String, dynamic>();
        // Create quiz first
        final quizRes = await api.createQuiz({
          'lessonId': widget.lessonId,
          'title': m['title'] ?? 'Quiz',
          'quizType': m['quizType'] ?? 'MULTIPLE_CHOICE',
        });

        // Then create questions
        final quizId = (quizRes.data is Map)
            ? (quizRes.data as Map)['id']?.toString()
            : null;
        if (quizId != null && m['questions'] is List) {
          for (final q in (m['questions'] as List)) {
            final qm = (q as Map).cast<String, dynamic>();
            final options = <Map<String, dynamic>>[];
            if (qm['options'] is List) {
              for (final op in (qm['options'] as List)) {
                final om = (op as Map).cast<String, dynamic>();
                options.add({
                  'text': om['text'] ?? '',
                  'isCorrect': om['isCorrect'] == true,
                });
              }
            }
            await api.createQuizQuestion({
              'quizId': quizId,
              'questionType': qm['questionType'] ?? 'MULTIPLE_CHOICE',
              'questionText': qm['questionText'] ?? '',
              'correctAnswer': qm['correctAnswer'] ?? '',
              'audioUrl': qm['audioUrl'],
              'options': options.isEmpty ? null : options,
            });
          }
        }
        count++;
      }
      if (!mounted) return;
      await _load();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Imported $count quizzes')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Lỗi import: $e')),
      );
    }
  }

  Future<String?> _showImportDialog(String title, String hint) async {
    final ctrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: SizedBox(
          width: double.maxFinite,
          child: TextField(
            controller: ctrl,
            minLines: 10,
            maxLines: 18,
            decoration: InputDecoration(
              border: const OutlineInputBorder(),
              hintText: hint,
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Hủy'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Import'),
          ),
        ],
      ),
    );

    if (ok != true) return null;
    final raw = ctrl.text.trim();
    return raw.isEmpty ? null : raw;
  }

  // Grammar
  Future<void> _upsertGrammar([Map<String, dynamic>? item]) async {
    final patternCtrl =
        TextEditingController(text: item?['pattern']?.toString());
    final expCtrl =
        TextEditingController(text: item?['explanationVN']?.toString());
    final exCtrl = TextEditingController(text: item?['example']?.toString());

    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(item == null ? 'Thêm ngữ pháp' : 'Sửa ngữ pháp'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: patternCtrl,
                decoration: const InputDecoration(
                  labelText: 'Pattern',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: expCtrl,
                minLines: 2,
                maxLines: 5,
                decoration: const InputDecoration(
                  labelText: 'Explanation (VN)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: exCtrl,
                minLines: 2,
                maxLines: 5,
                decoration: const InputDecoration(
                  labelText: 'Example',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Hủy'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Lưu'),
          ),
        ],
      ),
    );

    if (ok != true) return;

    final payload = <String, dynamic>{
      'lessonId': widget.lessonId,
      'pattern': patternCtrl.text.trim(),
      'explanationVN': expCtrl.text.trim(),
      'example': exCtrl.text.trim(),
    };

    final api = ref.read(apiClientProvider);
    if (item == null) {
      await api.createGrammar(payload);
    } else {
      final id = item['id']?.toString();
      if (id == null || id.isEmpty) return;
      payload.remove('lessonId');
      await api.updateGrammar(id, payload);
    }

    if (!mounted) return;
    await _load();
  }

  // Dialogues
  Future<void> _upsertDialogue([Map<String, dynamic>? item]) async {
    final speakerCtrl =
        TextEditingController(text: item?['speaker']?.toString());
    final koCtrl = TextEditingController(text: item?['koreanText']?.toString());
    final viCtrl =
        TextEditingController(text: item?['vietnameseText']?.toString());
    final audioCtrl =
        TextEditingController(text: item?['audioUrl']?.toString());
    final orderCtrl =
        TextEditingController(text: (item?['orderIndex'] ?? 0).toString());

    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(item == null ? 'Thêm hội thoại' : 'Sửa hội thoại'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: speakerCtrl,
                decoration: const InputDecoration(
                  labelText: 'Speaker',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: koCtrl,
                minLines: 2,
                maxLines: 5,
                decoration: const InputDecoration(
                  labelText: 'Korean text',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: viCtrl,
                minLines: 2,
                maxLines: 5,
                decoration: const InputDecoration(
                  labelText: 'Vietnamese text',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: audioCtrl,
                decoration: const InputDecoration(
                  labelText: 'Audio URL',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: orderCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Order',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Hủy'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Lưu'),
          ),
        ],
      ),
    );

    if (ok != true) return;

    final payload = <String, dynamic>{
      'lessonId': widget.lessonId,
      'speaker': speakerCtrl.text.trim(),
      'koreanText': koCtrl.text.trim(),
      'vietnameseText': viCtrl.text.trim(),
      'audioUrl': audioCtrl.text.trim().isEmpty ? null : audioCtrl.text.trim(),
      'orderIndex': int.tryParse(orderCtrl.text.trim()) ?? 0,
    };

    final api = ref.read(apiClientProvider);
    if (item == null) {
      await api.createDialogue(payload);
    } else {
      final id = item['id']?.toString();
      if (id == null || id.isEmpty) return;
      payload.remove('lessonId');
      await api.updateDialogue(id, payload);
    }

    if (!mounted) return;
    await _load();
  }

  // Quizzes
  Future<void> _upsertQuiz([Map<String, dynamic>? item]) async {
    final titleCtrl = TextEditingController(text: item?['title']?.toString());
    String quizType = item?['quizType']?.toString() ?? 'MULTIPLE_CHOICE';

    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(item == null ? 'Thêm quiz' : 'Sửa quiz'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: titleCtrl,
              decoration: const InputDecoration(
                labelText: 'Title',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 10),
            DropdownButtonFormField<String>(
              initialValue: quizType,
              decoration: const InputDecoration(
                labelText: 'Quiz type',
                border: OutlineInputBorder(),
              ),
              items: const [
                DropdownMenuItem(
                    value: 'MULTIPLE_CHOICE', child: Text('MULTIPLE_CHOICE')),
                DropdownMenuItem(
                    value: 'TRUE_FALSE', child: Text('TRUE_FALSE')),
                DropdownMenuItem(
                    value: 'FILL_BLANK', child: Text('FILL_BLANK')),
              ],
              onChanged: (v) {
                if (v == null) return;
                quizType = v;
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Hủy'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Lưu'),
          ),
        ],
      ),
    );

    if (ok != true) return;

    final payload = <String, dynamic>{
      'lessonId': widget.lessonId,
      'title': titleCtrl.text.trim(),
      'quizType': quizType,
    };

    final api = ref.read(apiClientProvider);
    if (item == null) {
      await api.createQuiz(payload);
    } else {
      final id = item['id']?.toString();
      if (id == null || id.isEmpty) return;
      payload.remove('lessonId');
      await api.updateQuiz(id, payload);
    }

    if (!mounted) return;
    await _load();
  }

  Future<void> _addQuestion(String quizId) async {
    final qTextCtrl = TextEditingController();
    final correctCtrl = TextEditingController();
    final audioCtrl = TextEditingController();
    String qType = 'MULTIPLE_CHOICE';

    final optionsCtrl = TextEditingController(
      text: 'A|false\nB|false\nC|true',
    );

    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Thêm câu hỏi'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                initialValue: qType,
                decoration: const InputDecoration(
                  labelText: 'Question type',
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem(
                      value: 'MULTIPLE_CHOICE', child: Text('MULTIPLE_CHOICE')),
                  DropdownMenuItem(
                      value: 'TRUE_FALSE', child: Text('TRUE_FALSE')),
                  DropdownMenuItem(
                      value: 'FILL_BLANK', child: Text('FILL_BLANK')),
                ],
                onChanged: (v) {
                  if (v == null) return;
                  qType = v;
                },
              ),
              const SizedBox(height: 10),
              TextField(
                controller: qTextCtrl,
                minLines: 2,
                maxLines: 5,
                decoration: const InputDecoration(
                  labelText: 'Question text',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: correctCtrl,
                decoration: const InputDecoration(
                  labelText: 'Correct answer',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: audioCtrl,
                decoration: const InputDecoration(
                  labelText: 'Audio URL (optional)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: optionsCtrl,
                minLines: 4,
                maxLines: 8,
                decoration: const InputDecoration(
                  labelText: 'Options (one per line: text|true/false)',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Hủy'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Tạo'),
          ),
        ],
      ),
    );

    if (ok != true) return;

    final options = <Map<String, dynamic>>[];
    for (final line in optionsCtrl.text.split('\n')) {
      final trimmed = line.trim();
      if (trimmed.isEmpty) continue;
      final parts = trimmed.split('|');
      final text = parts.first.trim();
      final isCorrect =
          parts.length > 1 ? (parts[1].trim().toLowerCase() == 'true') : false;
      if (text.isEmpty) continue;
      options.add({'text': text, 'isCorrect': isCorrect});
    }

    final payload = <String, dynamic>{
      'quizId': quizId,
      'questionType': qType,
      'questionText': qTextCtrl.text.trim(),
      'correctAnswer': correctCtrl.text.trim(),
      'audioUrl': audioCtrl.text.trim().isEmpty ? null : audioCtrl.text.trim(),
      'options': options.isEmpty ? null : options,
    };

    final api = ref.read(apiClientProvider);
    await api.createQuizQuestion(payload);

    if (!mounted) return;
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final role = ref.watch(authProvider).user?['role'];
    if (role != 'ADMIN') {
      return Scaffold(
        appBar: AppBar(title: const Text('Admin Lesson Detail')),
        body: const Center(child: Text('Bạn không có quyền truy cập')),
      );
    }

    final title = _lesson?['title']?.toString() ?? 'Lesson';

    return Scaffold(
      appBar: AppBar(
        title: Text('Admin: $title'),
        bottom: TabBar(
          controller: _tab,
          tabs: const [
            Tab(text: 'Vocab'),
            Tab(text: 'Grammar'),
            Tab(text: 'Dialogues'),
            Tab(text: 'Quizzes'),
          ],
        ),
        actions: [
          PopupMenuButton<String>(
            tooltip: 'AI provider',
            enabled: !_aiLoading,
            icon: const Icon(Icons.hub_outlined),
            onSelected: (v) async {
              await ref
                  .read(appSettingsProvider.notifier)
                  .setAdminAiProvider(v);
              await ref.read(appSettingsProvider.notifier).setAdminAiModel(
                    v == 'google' ? 'models/gemma-4-31b-it' : '',
                  );
              await _loadModels();
              if (!context.mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Đã đổi AI provider')),
              );
            },
            itemBuilder: (_) {
              final current = ref.read(appSettingsProvider).adminAiProvider;
              const providers = [
                {'id': 'openrouter', 'label': 'OpenRouter'},
                {'id': 'google', 'label': 'Google (Gemma)'},
              ];
              return providers
                  .map(
                    (p) => PopupMenuItem<String>(
                      value: p['id']!,
                      child: Row(
                        children: [
                          if (p['id'] == current)
                            const Padding(
                              padding: EdgeInsets.only(right: 8),
                              child: Icon(Icons.check, size: 18),
                            )
                          else
                            const SizedBox(width: 26),
                          Expanded(child: Text(p['label']!)),
                        ],
                      ),
                    ),
                  )
                  .toList();
            },
          ),
          PopupMenuButton<String>(
            tooltip: 'AI model',
            enabled: !_aiLoading && !_modelsLoading,
            icon: const Icon(Icons.tune),
            onSelected: (v) {
              ref.read(appSettingsProvider.notifier).setAdminAiModel(v);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Đã đổi AI model')),
              );
            },
            itemBuilder: (_) {
              final currentProvider =
                  ref.read(appSettingsProvider).adminAiProvider;
              final current = ref.read(appSettingsProvider).adminAiModel;
              final list = _models;
              final withDefault = <Map<String, String>>[
                {
                  'id': '',
                  'label': currentProvider == 'google'
                      ? 'models/gemma-4-31b-it (default)'
                      : '(default)'
                },
                ...list,
              ];
              return withDefault
                  .map(
                    (m) => PopupMenuItem<String>(
                      value: m['id']!,
                      child: Row(
                        children: [
                          if (m['id'] == current)
                            const Padding(
                              padding: EdgeInsets.only(right: 8),
                              child: Icon(Icons.check, size: 18),
                            )
                          else
                            const SizedBox(width: 26),
                          Expanded(child: Text(m['label']!)),
                        ],
                      ),
                    ),
                  )
                  .toList();
            },
          ),
          IconButton(
            onPressed: _loading ? null : _load,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!))
              : Column(
                  children: [
                    if (_quota != null)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
                        child: Text(
                          'Quota (server limiter): '
                          '${_quota!['perMinuteRemaining']}/${_quota!['perMinuteLimit']} req/phút (reset ${_quota!['minuteResetAt']}) • '
                          '${_quota!['dailyRemaining']}/${_quota!['dailyLimit']} req/ngày (reset ${_quota!['dayResetAt']})',
                          style: const TextStyle(
                              fontSize: 12, color: Colors.black54),
                        ),
                      ),
                    if (_modelsError != null)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
                        child: Text(
                          'Lỗi load models: $_modelsError',
                          style: const TextStyle(color: Colors.redAccent),
                        ),
                      ),
                    Expanded(
                      child: TabBarView(
                        controller: _tab,
                        children: [
                          _buildVocabTab(),
                          _buildGrammarTab(),
                          _buildDialoguesTab(),
                          _buildQuizzesTab(),
                        ],
                      ),
                    ),
                  ],
                ),
    );
  }

  Widget _buildVocabTab() {
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FilledButton.icon(
                onPressed: () => _upsertVocab(),
                icon: const Icon(Icons.add),
                label: const Text('Add'),
              ),
              OutlinedButton.icon(
                onPressed: _bulkImportVocab,
                icon: const Icon(Icons.file_upload),
                label: const Text('Import'),
              ),
              OutlinedButton.icon(
                onPressed: () => _copyPrompt('vocab'),
                icon: const Icon(Icons.copy),
                label: const Text('Copy Prompt'),
              ),
              OutlinedButton.icon(
                onPressed: _aiLoading ? null : () => _aiGenerate('vocab'),
                icon: _aiLoading
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.auto_awesome),
                label: Text(_aiLoading ? 'AI gen...' : 'AI gen'),
              ),
            ],
          ),
          if (_selectedVocabIds.isNotEmpty) ...[
            const SizedBox(height: 10),
            FilledButton.icon(
              onPressed: _aiLoading
                  ? null
                  : () => _confirmDelete(
                        title:
                            'Xóa ${_selectedVocabIds.length} từ vựng đã chọn?',
                        onDelete: () => ref
                            .read(apiClientProvider)
                            .deleteVocabularyBulk(_selectedVocabIds.toList()),
                      ),
              icon: const Icon(Icons.delete_outline),
              label: Text('Delete selected (${_selectedVocabIds.length})'),
            ),
          ],
          const SizedBox(height: 12),
          ..._vocab.map<Widget>((v) {
            final item = (v as Map).cast<String, dynamic>();
            final korean = item['korean']?.toString() ?? '';
            final vi = item['vietnamese']?.toString() ?? '';
            final diff = item['difficulty']?.toString() ?? '';
            final id = item['id']?.toString() ?? '';
            final idx = _vocab.indexOf(v);

            return Card(
              child: ListTile(
                leading: Checkbox(
                  value: id.isNotEmpty && _selectedVocabIds.contains(id),
                  onChanged: id.isEmpty
                      ? null
                      : (checked) {
                          setState(() {
                            if (checked == true) {
                              _selectedVocabIds.add(id);
                            } else {
                              _selectedVocabIds.remove(id);
                            }
                          });
                        },
                ),
                title: Text('${idx + 1}. $korean - $vi'),
                subtitle: diff.isEmpty ? null : Text(diff),
                onTap: () => _upsertVocab(item),
                trailing: IconButton(
                  onPressed: id.isEmpty
                      ? null
                      : () => _confirmDelete(
                            title: 'Xóa từ vựng?',
                            onDelete: () => ref
                                .read(apiClientProvider)
                                .deleteVocabulary(id),
                          ),
                  icon: const Icon(Icons.delete_outline),
                ),
              ),
            );
          }),
          const SizedBox(height: 80),
        ],
      ),
    );
  }

  Widget _buildGrammarTab() {
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FilledButton.icon(
                onPressed: () => _upsertGrammar(),
                icon: const Icon(Icons.add),
                label: const Text('Add'),
              ),
              OutlinedButton.icon(
                onPressed: _bulkImportGrammar,
                icon: const Icon(Icons.file_upload),
                label: const Text('Import'),
              ),
              OutlinedButton.icon(
                onPressed: () => _copyPrompt('grammar'),
                icon: const Icon(Icons.copy),
                label: const Text('Copy Prompt'),
              ),
              OutlinedButton.icon(
                onPressed: _aiLoading ? null : () => _aiGenerate('grammar'),
                icon: _aiLoading
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.auto_awesome),
                label: Text(_aiLoading ? 'AI gen...' : 'AI gen'),
              ),
            ],
          ),
          if (_selectedGrammarIds.isNotEmpty) ...[
            const SizedBox(height: 10),
            FilledButton.icon(
              onPressed: _aiLoading
                  ? null
                  : () => _confirmDelete(
                        title:
                            'Xóa ${_selectedGrammarIds.length} ngữ pháp đã chọn?',
                        onDelete: () => ref
                            .read(apiClientProvider)
                            .deleteGrammarBulk(_selectedGrammarIds.toList()),
                      ),
              icon: const Icon(Icons.delete_outline),
              label: Text('Delete selected (${_selectedGrammarIds.length})'),
            ),
          ],
          const SizedBox(height: 12),
          ..._grammar.map<Widget>((g) {
            final item = (g as Map).cast<String, dynamic>();
            final pattern = item['pattern']?.toString() ?? '';
            final id = item['id']?.toString() ?? '';
            final idx = _grammar.indexOf(g);
            return Card(
              child: ListTile(
                leading: Checkbox(
                  value: id.isNotEmpty && _selectedGrammarIds.contains(id),
                  onChanged: id.isEmpty
                      ? null
                      : (checked) {
                          setState(() {
                            if (checked == true) {
                              _selectedGrammarIds.add(id);
                            } else {
                              _selectedGrammarIds.remove(id);
                            }
                          });
                        },
                ),
                title: Text('${idx + 1}. $pattern'),
                onTap: () => _upsertGrammar(item),
                trailing: IconButton(
                  onPressed: id.isEmpty
                      ? null
                      : () => _confirmDelete(
                            title: 'Xóa ngữ pháp?',
                            onDelete: () =>
                                ref.read(apiClientProvider).deleteGrammar(id),
                          ),
                  icon: const Icon(Icons.delete_outline),
                ),
              ),
            );
          }),
          const SizedBox(height: 80),
        ],
      ),
    );
  }

  Widget _buildDialoguesTab() {
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FilledButton.icon(
                onPressed: () => _upsertDialogue(),
                icon: const Icon(Icons.add),
                label: const Text('Add'),
              ),
              OutlinedButton.icon(
                onPressed: _bulkImportDialogues,
                icon: const Icon(Icons.file_upload),
                label: const Text('Import'),
              ),
              OutlinedButton.icon(
                onPressed: () => _copyPrompt('dialogues'),
                icon: const Icon(Icons.copy),
                label: const Text('Copy Prompt'),
              ),
              OutlinedButton.icon(
                onPressed: _aiLoading ? null : () => _aiGenerate('dialogues'),
                icon: _aiLoading
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.auto_awesome),
                label: Text(_aiLoading ? 'AI gen...' : 'AI gen'),
              ),
            ],
          ),
          if (_selectedDialogueIds.isNotEmpty) ...[
            const SizedBox(height: 10),
            FilledButton.icon(
              onPressed: _aiLoading
                  ? null
                  : () => _confirmDelete(
                        title:
                            'Xóa ${_selectedDialogueIds.length} hội thoại đã chọn?',
                        onDelete: () => ref
                            .read(apiClientProvider)
                            .deleteDialoguesBulk(_selectedDialogueIds.toList()),
                      ),
              icon: const Icon(Icons.delete_outline),
              label: Text('Delete selected (${_selectedDialogueIds.length})'),
            ),
          ],
          const SizedBox(height: 12),
          ..._dialogues.map<Widget>((d) {
            final item = (d as Map).cast<String, dynamic>();
            final speaker = item['speaker']?.toString() ?? '';
            final ko = item['koreanText']?.toString() ?? '';
            final vi = item['vietnameseText']?.toString() ?? '';
            final id = item['id']?.toString() ?? '';
            return Card(
              child: ListTile(
                leading: Checkbox(
                  value: id.isNotEmpty && _selectedDialogueIds.contains(id),
                  onChanged: id.isEmpty
                      ? null
                      : (checked) {
                          setState(() {
                            if (checked == true) {
                              _selectedDialogueIds.add(id);
                            } else {
                              _selectedDialogueIds.remove(id);
                            }
                          });
                        },
                ),
                title: Text(speaker.isEmpty ? ko : '$speaker: $ko'),
                subtitle: vi.isEmpty ? null : Text(vi),
                onTap: () => _upsertDialogue(item),
                trailing: IconButton(
                  onPressed: id.isEmpty
                      ? null
                      : () => _confirmDelete(
                            title: 'Xóa hội thoại?',
                            onDelete: () =>
                                ref.read(apiClientProvider).deleteDialogue(id),
                          ),
                  icon: const Icon(Icons.delete_outline),
                ),
              ),
            );
          }),
          const SizedBox(height: 80),
        ],
      ),
    );
  }

  Widget _buildQuizzesTab() {
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FilledButton.icon(
                onPressed: () => _upsertQuiz(),
                icon: const Icon(Icons.add),
                label: const Text('Add quiz'),
              ),
              OutlinedButton.icon(
                onPressed: _bulkImportQuizzes,
                icon: const Icon(Icons.file_upload),
                label: const Text('Import'),
              ),
              OutlinedButton.icon(
                onPressed: () => _copyPrompt('quizzes'),
                icon: const Icon(Icons.copy),
                label: const Text('Copy Prompt'),
              ),
              OutlinedButton.icon(
                onPressed: _aiLoading ? null : () => _aiGenerate('quizzes'),
                icon: _aiLoading
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.auto_awesome),
                label: Text(_aiLoading ? 'AI gen...' : 'AI gen'),
              ),
            ],
          ),
          if (_selectedQuizIds.isNotEmpty) ...[
            const SizedBox(height: 10),
            FilledButton.icon(
              onPressed: _aiLoading
                  ? null
                  : () => _confirmDelete(
                        title: 'Xóa ${_selectedQuizIds.length} quiz đã chọn?',
                        onDelete: () => ref
                            .read(apiClientProvider)
                            .deleteQuizzesBulk(_selectedQuizIds.toList()),
                      ),
              icon: const Icon(Icons.delete_outline),
              label: Text('Delete selected (${_selectedQuizIds.length})'),
            ),
          ],
          const SizedBox(height: 12),
          ..._quizzes.map<Widget>((q) {
            final quiz = (q as Map).cast<String, dynamic>();
            final quizId = quiz['id']?.toString() ?? '';
            final title = quiz['title']?.toString() ?? '';
            final type = quiz['quizType']?.toString() ?? '';
            final questions = (quiz['questions'] as List?) ?? const <dynamic>[];

            return Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Checkbox(
                          value: quizId.isNotEmpty &&
                              _selectedQuizIds.contains(quizId),
                          onChanged: quizId.isEmpty
                              ? null
                              : (checked) {
                                  setState(() {
                                    if (checked == true) {
                                      _selectedQuizIds.add(quizId);
                                    } else {
                                      _selectedQuizIds.remove(quizId);
                                    }
                                  });
                                },
                        ),
                        Expanded(
                          child: Text(
                            title,
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 16,
                            ),
                          ),
                        ),
                        if (type.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: Text(
                              type,
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade600,
                              ),
                            ),
                          ),
                        IconButton(
                          onPressed: quizId.isEmpty
                              ? null
                              : () => _addQuestion(quizId),
                          icon: const Icon(Icons.add),
                          tooltip: 'Add question',
                        ),
                        IconButton(
                          onPressed: () => _upsertQuiz(quiz),
                          icon: const Icon(Icons.edit),
                          tooltip: 'Edit quiz',
                        ),
                        IconButton(
                          onPressed: quizId.isEmpty
                              ? null
                              : () => _confirmDelete(
                                    title: 'Xóa quiz?',
                                    onDelete: () => ref
                                        .read(apiClientProvider)
                                        .deleteQuiz(quizId),
                                  ),
                          icon: const Icon(Icons.delete_outline),
                          tooltip: 'Delete quiz',
                        ),
                      ],
                    ),
                    const Divider(height: 16),
                    if (questions.isEmpty)
                      const Text('No questions')
                    else
                      ...questions.map<Widget>((qu) {
                        final question = (qu as Map).cast<String, dynamic>();
                        final qId = question['id']?.toString() ?? '';
                        final qText =
                            question['questionText']?.toString() ?? '';
                        final correct =
                            question['correctAnswer']?.toString() ?? '';
                        return ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(qText),
                          subtitle: correct.isEmpty
                              ? null
                              : Text('Correct: $correct'),
                          trailing: IconButton(
                            onPressed: qId.isEmpty
                                ? null
                                : () => _confirmDelete(
                                      title: 'Xóa câu hỏi?',
                                      onDelete: () => ref
                                          .read(apiClientProvider)
                                          .deleteQuizQuestion(qId),
                                    ),
                            icon: const Icon(Icons.delete_outline),
                          ),
                        );
                      }),
                  ],
                ),
              ),
            );
          }),
          const SizedBox(height: 80),
        ],
      ),
    );
  }
}

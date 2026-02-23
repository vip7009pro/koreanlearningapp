import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api_client.dart';
import '../../providers/auth_provider.dart';

class AdminTopikExamEditorScreen extends ConsumerStatefulWidget {
  final String examId;
  const AdminTopikExamEditorScreen({super.key, required this.examId});

  @override
  ConsumerState<AdminTopikExamEditorScreen> createState() =>
      _AdminTopikExamEditorScreenState();
}

class _AdminTopikExamEditorScreenState
    extends ConsumerState<AdminTopikExamEditorScreen> {
  bool _loading = true;
  String? _error;

  Map<String, dynamic>? _exam;
  List<dynamic> _sections = [];

  final _titleCtrl = TextEditingController();
  final _yearCtrl = TextEditingController();
  final _durationCtrl = TextEditingController();
  final _totalQuestionsCtrl = TextEditingController();

  bool _savingExam = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _yearCtrl.dispose();
    _durationCtrl.dispose();
    _totalQuestionsCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final api = ref.read(apiClientProvider);
      final res = await api.adminGetTopikExam(widget.examId);
      final data = (res.data as Map).cast<String, dynamic>();

      final sections = (data['sections'] as List?) ?? [];

      if (!mounted) return;
      setState(() {
        _exam = data;
        _sections = sections;
        _loading = false;

        _titleCtrl.text = data['title']?.toString() ?? '';
        _yearCtrl.text = (data['year']?.toString() ?? '').toString();
        _durationCtrl.text = (data['durationMinutes']?.toString() ?? '').toString();
        _totalQuestionsCtrl.text = (data['totalQuestions']?.toString() ?? '').toString();
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _saveExam() async {
    if (_savingExam) return;
    setState(() => _savingExam = true);

    try {
      final api = ref.read(apiClientProvider);
      await api.adminUpdateTopikExam(widget.examId, {
        'title': _titleCtrl.text.trim(),
        if (_yearCtrl.text.trim().isNotEmpty)
          'year': int.tryParse(_yearCtrl.text.trim()),
        if (_durationCtrl.text.trim().isNotEmpty)
          'durationMinutes': int.tryParse(_durationCtrl.text.trim()),
        if (_totalQuestionsCtrl.text.trim().isNotEmpty)
          'totalQuestions': int.tryParse(_totalQuestionsCtrl.text.trim()),
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Đã lưu exam')),
      );
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Lỗi lưu exam: $e')),
      );
    } finally {
      if (mounted) setState(() => _savingExam = false);
    }
  }

  Future<void> _togglePublish() async {
    final status = _exam?['status']?.toString() ?? 'DRAFT';
    final published = status == 'PUBLISHED';

    try {
      final api = ref.read(apiClientProvider);
      if (published) {
        await api.adminUnpublishTopikExam(widget.examId);
      } else {
        await api.adminPublishTopikExam(widget.examId);
      }
      if (!mounted) return;
      await _load();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(published ? 'Đã chuyển về Draft' : 'Đã Publish')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Lỗi cập nhật status: $e')),
      );
    }
  }

  Future<void> _deleteExam() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Xóa exam?'),
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
      final api = ref.read(apiClientProvider);
      await api.adminDeleteTopikExam(widget.examId);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Đã xóa exam')),
      );
      if (!mounted) return;
      context.pop();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Lỗi xóa exam: $e')),
      );
    }
  }

  Future<void> _createSection() async {
    String type = 'LISTENING';
    final orderCtrl = TextEditingController(text: '1');
    final durationCtrl = TextEditingController();
    final maxScoreCtrl = TextEditingController();

    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setLocal) => AlertDialog(
          title: const Text('Tạo Section'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  key: ValueKey('createSectionType:$type'),
                  initialValue: type,
                  decoration: const InputDecoration(
                    labelText: 'Type',
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(
                        value: 'LISTENING', child: Text('LISTENING')),
                    DropdownMenuItem(value: 'READING', child: Text('READING')),
                    DropdownMenuItem(value: 'WRITING', child: Text('WRITING')),
                  ],
                  onChanged: (v) => setLocal(() => type = v ?? 'LISTENING'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: orderCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Order',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: durationCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Duration minutes (optional)',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: maxScoreCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Max score (optional)',
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
      ),
    );

    if (ok != true) return;

    try {
      final api = ref.read(apiClientProvider);
      await api.adminCreateTopikSection({
        'examId': widget.examId,
        'type': type,
        'orderIndex': int.tryParse(orderCtrl.text.trim()) ?? 1,
        if (durationCtrl.text.trim().isNotEmpty)
          'durationMinutes': int.tryParse(durationCtrl.text.trim()),
        if (maxScoreCtrl.text.trim().isNotEmpty)
          'maxScore': int.tryParse(maxScoreCtrl.text.trim()),
      });
      if (!mounted) return;
      await _load();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Đã tạo section')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Lỗi tạo section: $e')),
      );
    }
  }

  Future<void> _editSection(Map<String, dynamic> section) async {
    final id = section['id']?.toString() ?? '';
    if (id.isEmpty) return;

    String type = section['type']?.toString() ?? 'LISTENING';
    final orderCtrl =
        TextEditingController(text: section['orderIndex']?.toString() ?? '1');
    final durationCtrl =
        TextEditingController(text: section['durationMinutes']?.toString() ?? '');
    final maxScoreCtrl =
        TextEditingController(text: section['maxScore']?.toString() ?? '');

    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setLocal) => AlertDialog(
          title: const Text('Sửa Section'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  key: ValueKey('editSectionType:$type'),
                  initialValue: type,
                  decoration: const InputDecoration(
                    labelText: 'Type',
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(
                        value: 'LISTENING', child: Text('LISTENING')),
                    DropdownMenuItem(value: 'READING', child: Text('READING')),
                    DropdownMenuItem(value: 'WRITING', child: Text('WRITING')),
                  ],
                  onChanged: (v) => setLocal(() => type = v ?? type),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: orderCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Order',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: durationCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Duration minutes',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: maxScoreCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Max score',
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
      ),
    );

    if (ok != true) return;

    try {
      final api = ref.read(apiClientProvider);
      await api.adminUpdateTopikSection(id, {
        'type': type,
        'orderIndex': int.tryParse(orderCtrl.text.trim()) ?? 1,
        'durationMinutes': durationCtrl.text.trim().isEmpty
            ? null
            : int.tryParse(durationCtrl.text.trim()),
        'maxScore': maxScoreCtrl.text.trim().isEmpty
            ? null
            : int.tryParse(maxScoreCtrl.text.trim()),
      });
      if (!mounted) return;
      await _load();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Đã lưu section')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Lỗi lưu section: $e')),
      );
    }
  }

  Future<void> _createQuestion(String sectionId) async {
    String questionType = 'MCQ';
    final orderCtrl = TextEditingController(text: '1');
    final contentCtrl = TextEditingController();

    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setLocal) => AlertDialog(
          title: const Text('Tạo Question'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  key: ValueKey('createQuestionType:$questionType'),
                  initialValue: questionType,
                  decoration: const InputDecoration(
                    labelText: 'Question type',
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'MCQ', child: Text('MCQ')),
                    DropdownMenuItem(
                        value: 'SHORT_ANSWER', child: Text('SHORT_ANSWER')),
                    DropdownMenuItem(value: 'ESSAY', child: Text('ESSAY')),
                  ],
                  onChanged: (v) =>
                      setLocal(() => questionType = v ?? 'MCQ'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: orderCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Order',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: contentCtrl,
                  minLines: 3,
                  maxLines: 8,
                  decoration: const InputDecoration(
                    labelText: 'Content (HTML)',
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
      ),
    );

    if (ok != true) return;

    try {
      final api = ref.read(apiClientProvider);
      await api.adminCreateTopikQuestion({
        'sectionId': sectionId,
        'questionType': questionType,
        'orderIndex': int.tryParse(orderCtrl.text.trim()) ?? 1,
        'contentHtml': contentCtrl.text,
      });
      if (!mounted) return;
      await _load();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Đã tạo question')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Lỗi tạo question: $e')),
      );
    }
  }

  Future<void> _editQuestion(Map<String, dynamic> q) async {
    final id = q['id']?.toString() ?? '';
    if (id.isEmpty) return;

    String questionType = q['questionType']?.toString() ?? 'MCQ';
    final orderCtrl = TextEditingController(text: q['orderIndex']?.toString() ?? '1');
    final contentCtrl = TextEditingController(text: q['contentHtml']?.toString() ?? '');
    final audioUrlCtrl = TextEditingController(text: q['audioUrl']?.toString() ?? '');
    final listeningScriptCtrl = TextEditingController(text: q['listeningScript']?.toString() ?? '');
    final correctTextCtrl = TextEditingController(text: q['correctTextAnswer']?.toString() ?? '');
    final scoreWeightCtrl = TextEditingController(text: q['scoreWeight']?.toString() ?? '');
    final explanationCtrl = TextEditingController(text: q['explanation']?.toString() ?? '');

    final choices = (q['choices'] as List?)?.map((c) => (c as Map).cast<String, dynamic>()).toList() ?? <Map<String, dynamic>>[];

    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setLocal) => AlertDialog(
          title: const Text('Sửa Question'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  key: ValueKey('editQuestionType:$questionType'),
                  initialValue: questionType,
                  decoration: const InputDecoration(
                    labelText: 'Question type',
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'MCQ', child: Text('MCQ')),
                    DropdownMenuItem(value: 'SHORT_ANSWER', child: Text('SHORT_ANSWER')),
                    DropdownMenuItem(value: 'ESSAY', child: Text('ESSAY')),
                  ],
                  onChanged: (v) => setLocal(() => questionType = v ?? questionType),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: orderCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Order',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: contentCtrl,
                  minLines: 3,
                  maxLines: 8,
                  decoration: const InputDecoration(
                    labelText: 'Content (HTML)',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: audioUrlCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Audio URL (optional)',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: listeningScriptCtrl,
                  minLines: 2,
                  maxLines: 6,
                  decoration: const InputDecoration(
                    labelText: 'Listening script (optional)',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: correctTextCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Correct text answer (optional)',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: scoreWeightCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Score weight (optional)',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: explanationCtrl,
                  minLines: 2,
                  maxLines: 6,
                  decoration: const InputDecoration(
                    labelText: 'Explanation (optional)',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                if (questionType == 'MCQ')
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Choices', style: TextStyle(fontWeight: FontWeight.w600)),
                      const SizedBox(height: 8),
                      ...choices.asMap().entries.map((entry) {
                        final idx = entry.key;
                        final c = entry.value;
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Row(
                            children: [
                              Expanded(
                                child: TextFormField(
                                  initialValue: c['content']?.toString() ?? '',
                                  decoration: InputDecoration(
                                    labelText: 'Choice ${idx + 1}',
                                    border: const OutlineInputBorder(),
                                  ),
                                  onChanged: (v) => setLocal(() => c['content'] = v),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Column(
                                children: [
                                  const Text('Correct', style: TextStyle(fontSize: 12)),
                                  Switch(
                                    value: c['isCorrect'] == true,
                                    onChanged: (v) => setLocal(() => c['isCorrect'] = v),
                                  ),
                                ],
                              ),
                              IconButton(
                                onPressed: () => setLocal(() => choices.removeAt(idx)),
                                icon: const Icon(Icons.delete_outline),
                              ),
                            ],
                          ),
                        );
                      }),
                      OutlinedButton.icon(
                        onPressed: () => setLocal(() {
                          choices.add({
                            'orderIndex': choices.length + 1,
                            'content': '',
                            'isCorrect': false,
                          });
                        }),
                        icon: const Icon(Icons.add),
                        label: const Text('Add choice'),
                      ),
                    ],
                  )
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
      ),
    );

    if (ok != true) return;

    try {
      final api = ref.read(apiClientProvider);

      final patch = <String, dynamic>{
        'questionType': questionType,
        'orderIndex': int.tryParse(orderCtrl.text.trim()) ?? 1,
        'contentHtml': contentCtrl.text,
        'audioUrl': audioUrlCtrl.text.trim().isEmpty ? null : audioUrlCtrl.text.trim(),
        'listeningScript': listeningScriptCtrl.text.trim().isEmpty ? null : listeningScriptCtrl.text,
        'correctTextAnswer': correctTextCtrl.text.trim().isEmpty ? null : correctTextCtrl.text.trim(),
        'scoreWeight': scoreWeightCtrl.text.trim().isEmpty ? null : int.tryParse(scoreWeightCtrl.text.trim()),
        'explanation': explanationCtrl.text.trim().isEmpty ? null : explanationCtrl.text,
      };

      if (questionType == 'MCQ') {
        patch['choices'] = choices.asMap().entries.map((entry) {
          final idx = entry.key;
          final c = entry.value;
          return {
            'orderIndex': (c['orderIndex'] is int)
                ? c['orderIndex']
                : (idx + 1),
            'content': c['content']?.toString() ?? '',
            'isCorrect': c['isCorrect'] == true,
          };
        }).toList();
      }

      await api.adminUpdateTopikQuestion(id, patch);
      if (!mounted) return;
      await _load();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Đã lưu question')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Lỗi lưu question: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final role = ref.watch(authProvider).user?['role'];
    if (role != 'ADMIN') {
      return const Scaffold(
        body: Center(child: Text('Bạn không có quyền truy cập')),
      );
    }

    final title = _exam?['title']?.toString() ?? '';
    final status = _exam?['status']?.toString() ?? 'DRAFT';

    return Scaffold(
      appBar: AppBar(
        title: Text(title.isEmpty ? 'TOPIK Exam Editor' : title),
        actions: [
          IconButton(
            onPressed: _loading ? null : _load,
            icon: const Icon(Icons.refresh),
          ),
          IconButton(
            onPressed: _togglePublish,
            icon: Icon(status == 'PUBLISHED' ? Icons.visibility_off : Icons.visibility),
            tooltip: status == 'PUBLISHED' ? 'Unpublish' : 'Publish',
          ),
          IconButton(
            onPressed: _deleteExam,
            icon: const Icon(Icons.delete_outline),
            tooltip: 'Delete',
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _createSection,
        icon: const Icon(Icons.add),
        label: const Text('Add section'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!))
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      'Exam',
                                      style: Theme.of(context).textTheme.titleMedium,
                                    ),
                                  ),
                                  FilledButton.icon(
                                    onPressed: _savingExam ? null : _saveExam,
                                    icon: const Icon(Icons.save),
                                    label: const Text('Save'),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              TextField(
                                controller: _titleCtrl,
                                decoration: const InputDecoration(
                                  labelText: 'Title',
                                  border: OutlineInputBorder(),
                                ),
                              ),
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  Expanded(
                                    child: TextField(
                                      controller: _yearCtrl,
                                      keyboardType: TextInputType.number,
                                      decoration: const InputDecoration(
                                        labelText: 'Year',
                                        border: OutlineInputBorder(),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: TextField(
                                      controller: _durationCtrl,
                                      keyboardType: TextInputType.number,
                                      decoration: const InputDecoration(
                                        labelText: 'Duration minutes',
                                        border: OutlineInputBorder(),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              TextField(
                                controller: _totalQuestionsCtrl,
                                keyboardType: TextInputType.number,
                                decoration: const InputDecoration(
                                  labelText: 'Total questions',
                                  border: OutlineInputBorder(),
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text('Status: $status'),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      ..._sections.map((s) {
                        final section = (s as Map).cast<String, dynamic>();
                        final sectionId = section['id']?.toString() ?? '';
                        final type = section['type']?.toString() ?? '';
                        final orderIndex = section['orderIndex']?.toString() ?? '';
                        final questions = (section['questions'] as List?) ?? const <dynamic>[];

                        return Card(
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        'Section $orderIndex • $type',
                                        style: const TextStyle(fontWeight: FontWeight.w600),
                                      ),
                                    ),
                                    IconButton(
                                      onPressed: () => _editSection(section),
                                      icon: const Icon(Icons.edit),
                                      tooltip: 'Edit section',
                                    ),
                                    IconButton(
                                      onPressed: sectionId.isEmpty
                                          ? null
                                          : () => _createQuestion(sectionId),
                                      icon: const Icon(Icons.add),
                                      tooltip: 'Add question',
                                    ),
                                  ],
                                ),
                                const Divider(height: 12),
                                if (questions.isEmpty)
                                  const Padding(
                                    padding: EdgeInsets.symmetric(vertical: 8),
                                    child: Text('No questions'),
                                  )
                                else
                                  ...questions.map((qq) {
                                    final q = (qq as Map).cast<String, dynamic>();
                                    final qId = q['id']?.toString() ?? '';
                                    final qType = q['questionType']?.toString() ?? '';
                                    final qOrder = q['orderIndex']?.toString() ?? '';

                                    return ListTile(
                                      contentPadding: EdgeInsets.zero,
                                      title: Text('Q$qOrder • $qType'),
                                      subtitle: Text(
                                        (q['contentHtml']?.toString() ?? '').replaceAll(RegExp(r'<[^>]*>'), ' ').trim(),
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      trailing: IconButton(
                                        onPressed: qId.isEmpty ? null : () => _editQuestion(q),
                                        icon: const Icon(Icons.edit),
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
                ),
    );
  }
}

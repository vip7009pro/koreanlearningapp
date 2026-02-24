import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../core/api_client.dart';
import '../../providers/app_settings_provider.dart';
import '../../providers/auth_provider.dart';

class AdminTopikScreen extends ConsumerStatefulWidget {
  const AdminTopikScreen({super.key});

  @override
  ConsumerState<AdminTopikScreen> createState() => _AdminTopikScreenState();
}

class _AdminTopikScreenState extends ConsumerState<AdminTopikScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tab;

  static const List<Map<String, String>> _aiModels = [
    {'id': 'google/gemini-2.0-flash-001', 'label': 'gemini-2.0-flash-001'},
    {'id': 'openai/gpt-4o-mini', 'label': 'gpt-4o-mini'},
    {'id': 'anthropic/claude-3.5-haiku', 'label': 'claude-3.5-haiku'},
    {'id': 'meta-llama/llama-3.1-70b-instruct', 'label': 'llama-3.1-70b'},
    {
      'id': 'meta-llama/llama-3.3-70b-instruct:free',
      'label': 'llama-3.3-70b-instruct:free'
    },
  ];

  bool _loading = true;
  String? _error;
  List<dynamic> _exams = [];

  final _importCtrl = TextEditingController();

  String _genTopikLevel = 'TOPIK_II';
  int _genYear = DateTime.now().year;
  final _genTitleCtrl = TextEditingController();
  int _genBatchSize = 10;
  String _genStatus = 'DRAFT';

  Map<String, dynamic>? _generated;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 3, vsync: this);
    _load();
  }

  @override
  void dispose() {
    _tab.dispose();
    _importCtrl.dispose();
    _genTitleCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final api = ref.read(apiClientProvider);
      final res = await api.adminListTopikExams();
      if (!mounted) return;
      setState(() {
        _exams = (res.data as List?) ?? [];
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

  Map<String, dynamic>? _tryParseJson(String raw) {
    try {
      final decoded = (raw.isNotEmpty) ? jsonDecode(raw) : null;
      if (decoded is Map<String, dynamic>) return decoded;
      if (decoded is Map) return decoded.cast<String, dynamic>();
      return null;
    } catch (_) {
      return null;
    }
  }

  Future<void> _importNow(Map<String, dynamic> payload) async {
    try {
      final api = ref.read(apiClientProvider);
      await api.adminImportTopikExam(payload);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Import TOPIK thành công')),
      );
      setState(() {
        _importCtrl.text = '';
      });
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Lỗi import: $e')),
      );
    }
  }

  Future<void> _createExam() async {
    final titleCtrl = TextEditingController();
    final yearCtrl = TextEditingController(text: DateTime.now().year.toString());

    String topikLevel = 'TOPIK_II';
    String status = 'DRAFT';

    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setLocal) => AlertDialog(
          title: const Text('Tạo TOPIK exam'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: titleCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Title',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: yearCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Year',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  key: ValueKey('topikLevel:$topikLevel'),
                  initialValue: topikLevel,
                  decoration: const InputDecoration(
                    labelText: 'Topik Level',
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'TOPIK_I', child: Text('TOPIK_I')),
                    DropdownMenuItem(value: 'TOPIK_II', child: Text('TOPIK_II')),
                  ],
                  onChanged: (v) => setLocal(() => topikLevel = v ?? 'TOPIK_II'),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  key: ValueKey('status:$status'),
                  initialValue: status,
                  decoration: const InputDecoration(
                    labelText: 'Status',
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'DRAFT', child: Text('DRAFT')),
                    DropdownMenuItem(
                        value: 'PUBLISHED', child: Text('PUBLISHED')),
                  ],
                  onChanged: (v) => setLocal(() => status = v ?? 'DRAFT'),
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
      await api.adminCreateTopikExam({
        'title': titleCtrl.text.trim(),
        'year': int.tryParse(yearCtrl.text.trim()) ?? DateTime.now().year,
        'topikLevel': topikLevel,
        'status': status,
      });
      if (!mounted) return;
      await _load();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Đã tạo exam')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Lỗi tạo exam: $e')),
      );
    }
  }

  Future<void> _generate() async {
    try {
      final api = ref.read(apiClientProvider);
      final model = ref.read(appSettingsProvider).adminAiModel;
      final input = <String, dynamic>{
        'topikLevel': _genTopikLevel,
        'year': _genYear,
        if (_genTitleCtrl.text.trim().isNotEmpty) 'title': _genTitleCtrl.text.trim(),
        'batchSize': _genBatchSize,
        'status': _genStatus,
      };

      final res = await api.adminGenerateTopikExam(
        input,
        model: model,
      );

      if (!mounted) return;
      setState(() {
        _generated = (res.data as Map?)?.cast<String, dynamic>();
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Đã generate payload')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Lỗi generate: $e')),
      );
    }
  }

  Future<void> _copyGeneratedToClipboard() async {
    final payload = _generated?['payload'];
    if (payload == null) return;

    final text = const JsonEncoder.withIndent('  ').convert(payload);
    await Clipboard.setData(ClipboardData(text: text));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Đã copy payload JSON')),
    );
  }

  Future<void> _importGenerated() async {
    final payload = _generated?['payload'];
    if (payload is Map) {
      await _importNow(payload.cast<String, dynamic>());
      return;
    }

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Không có payload để import')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final role = ref.watch(authProvider).user?['role'];
    if (role != 'ADMIN') {
      return const Scaffold(
        body: Center(child: Text('Bạn không có quyền truy cập')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('TOPIK (Admin)'),
        bottom: TabBar(
          controller: _tab,
          tabs: const [
            Tab(text: 'Exams'),
            Tab(text: 'Import JSON'),
            Tab(text: 'AI Generate'),
          ],
        ),
        actions: [
          IconButton(
            onPressed: _loading ? null : _load,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      floatingActionButton: _tab.index == 0
          ? FloatingActionButton(
              onPressed: _createExam,
              child: const Icon(Icons.add),
            )
          : null,
      body: TabBarView(
        controller: _tab,
        children: [
          _buildExamsTab(context),
          _buildImportTab(context),
          _buildGenerateTab(context),
        ],
      ),
    );
  }

  Widget _buildExamsTab(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(child: Text(_error!));
    }

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.separated(
        padding: const EdgeInsets.all(12),
        itemCount: _exams.length,
        separatorBuilder: (_, __) => const SizedBox(height: 8),
        itemBuilder: (context, index) {
          final exam = (_exams[index] as Map).cast<String, dynamic>();
          final id = exam['id']?.toString() ?? '';
          final title = exam['title']?.toString() ?? '';
          final year = exam['year']?.toString() ?? '';
          final level = exam['topikLevel']?.toString() ?? '';
          final status = exam['status']?.toString() ?? '';

          return Card(
            child: ListTile(
              onTap: id.isEmpty
                  ? null
                  : () => context.push('/admin/topik/exams/$id'),
              title: Text(
                title.isEmpty ? '(No title)' : title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              subtitle: Text('$level • $year • $status'),
              trailing: const Icon(Icons.chevron_right),
            ),
          );
        },
      ),
    );
  }

  Widget _buildImportTab(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        TextField(
          controller: _importCtrl,
          minLines: 10,
          maxLines: 18,
          decoration: const InputDecoration(
            labelText: 'Paste payload JSON',
            hintText: '{ "exam": {...}, "sections": [...] }',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 12),
        FilledButton.icon(
          onPressed: () {
            final raw = _importCtrl.text.trim();
            if (raw.isEmpty) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Dán JSON trước')),
              );
              return;
            }
            final parsed = _tryParseJson(raw);
            if (parsed == null) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('JSON không hợp lệ')),
              );
              return;
            }
            _importNow(parsed);
          },
          icon: const Icon(Icons.file_upload),
          label: const Text('Import'),
        ),
      ],
    );
  }

  Widget _buildGenerateTab(BuildContext context) {
    final payload = _generated?['payload'];
    final currentModel = ref.watch(appSettingsProvider).adminAiModel;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: ListTile(
            title: const Text('AI model'),
            subtitle: Text(currentModel),
            trailing: PopupMenuButton<String>(
              tooltip: 'Chọn model',
              onSelected: (v) {
                ref.read(appSettingsProvider.notifier).setAdminAiModel(v);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Đã đổi AI model')),
                );
              },
              itemBuilder: (_) {
                return _aiModels
                    .map(
                      (m) => PopupMenuItem<String>(
                        value: m['id']!,
                        child: Row(
                          children: [
                            if (m['id'] == currentModel)
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
          ),
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(
          key: ValueKey('genTopikLevel:$_genTopikLevel'),
          initialValue: _genTopikLevel,
          decoration: const InputDecoration(
            labelText: 'Topik Level',
            border: OutlineInputBorder(),
          ),
          items: const [
            DropdownMenuItem(value: 'TOPIK_I', child: Text('TOPIK_I')),
            DropdownMenuItem(value: 'TOPIK_II', child: Text('TOPIK_II')),
          ],
          onChanged: (v) => setState(() => _genTopikLevel = v ?? 'TOPIK_II'),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _genTitleCtrl,
          decoration: const InputDecoration(
            labelText: 'Title (optional)',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: TextFormField(
                initialValue: _genYear.toString(),
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Year',
                  border: OutlineInputBorder(),
                ),
                onChanged: (v) => setState(() {
                  _genYear = int.tryParse(v.trim()) ?? _genYear;
                }),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextFormField(
                initialValue: _genBatchSize.toString(),
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Batch size',
                  border: OutlineInputBorder(),
                ),
                onChanged: (v) => setState(() {
                  _genBatchSize = int.tryParse(v.trim()) ?? _genBatchSize;
                }),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(
          key: ValueKey('genStatus:$_genStatus'),
          initialValue: _genStatus,
          decoration: const InputDecoration(
            labelText: 'Status',
            border: OutlineInputBorder(),
          ),
          items: const [
            DropdownMenuItem(value: 'DRAFT', child: Text('DRAFT')),
            DropdownMenuItem(value: 'PUBLISHED', child: Text('PUBLISHED')),
          ],
          onChanged: (v) => setState(() => _genStatus = v ?? 'DRAFT'),
        ),
        const SizedBox(height: 12),
        FilledButton.icon(
          onPressed: _generate,
          icon: const Icon(Icons.auto_awesome),
          label: const Text('Generate payload'),
        ),
        const SizedBox(height: 12),
        if (_generated != null) ...[
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Generated',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    payload == null
                        ? 'No payload'
                        : 'Payload ready (${payload is Map ? 'object' : payload.runtimeType})',
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: payload == null ? null : _copyGeneratedToClipboard,
                          icon: const Icon(Icons.copy),
                          label: const Text('Copy JSON'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: payload == null ? null : _importGenerated,
                          icon: const Icon(Icons.file_upload),
                          label: const Text('Import'),
                        ),
                      ),
                    ],
                  )
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }
}

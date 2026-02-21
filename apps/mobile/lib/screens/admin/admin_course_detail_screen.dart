import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/api_client.dart';
import '../../providers/auth_provider.dart';

class AdminCourseDetailScreen extends ConsumerStatefulWidget {
  final String courseId;
  const AdminCourseDetailScreen({super.key, required this.courseId});

  @override
  ConsumerState<AdminCourseDetailScreen> createState() =>
      _AdminCourseDetailScreenState();
}

class _AdminCourseDetailScreenState
    extends ConsumerState<AdminCourseDetailScreen> {
  bool _loading = true;
  String? _error;

  Map<String, dynamic>? _course;
  List<dynamic> _sections = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final api = ref.read(apiClientProvider);
      final courseRes = await api.getCourse(widget.courseId);
      final sectionsRes = await api.getSections(widget.courseId);

      if (!mounted) return;
      setState(() {
        _course = (courseRes.data as Map).cast<String, dynamic>();
        _sections = (sectionsRes.data as List?) ?? [];
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

  Future<void> _createSection() async {
    final titleCtrl = TextEditingController();
    final orderCtrl = TextEditingController(text: '0');

    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Tạo Section'),
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
            const SizedBox(height: 12),
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

    try {
      final api = ref.read(apiClientProvider);
      final title = titleCtrl.text.trim();
      final order = int.tryParse(orderCtrl.text.trim()) ?? 0;
      if (title.isEmpty) return;
      await api.createSection({
        'courseId': widget.courseId,
        'title': title,
        'orderIndex': order,
      });
      if (!mounted) return;
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Lỗi tạo section: $e')),
      );
    }
  }

  Future<void> _deleteSection(String sectionId) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Xóa section?'),
        content: const Text('Sẽ xóa toàn bộ lessons trong section này.'),
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
      await api.deleteSection(sectionId);
      if (!mounted) return;
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Lỗi xóa section: $e')),
      );
    }
  }

  Future<void> _createLesson(String sectionId) async {
    final titleCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    final orderCtrl = TextEditingController(text: '0');
    final minutesCtrl = TextEditingController(text: '10');

    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Tạo Lesson'),
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
                controller: descCtrl,
                minLines: 2,
                maxLines: 4,
                decoration: const InputDecoration(
                  labelText: 'Description',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: orderCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Order',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: minutesCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Minutes',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                ],
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

    try {
      final api = ref.read(apiClientProvider);
      final title = titleCtrl.text.trim();
      if (title.isEmpty) return;

      await api.createLesson({
        'sectionId': sectionId,
        'title': title,
        'description': descCtrl.text.trim(),
        'orderIndex': int.tryParse(orderCtrl.text.trim()) ?? 0,
        'estimatedMinutes': int.tryParse(minutesCtrl.text.trim()) ?? 10,
      });

      if (!mounted) return;
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Lỗi tạo lesson: $e')),
      );
    }
  }

  Future<void> _deleteLesson(String lessonId) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Xóa lesson?'),
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
      await api.deleteLesson(lessonId);
      if (!mounted) return;
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Lỗi xóa lesson: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final role = ref.watch(authProvider).user?['role'];
    if (role != 'ADMIN') {
      return Scaffold(
        appBar: AppBar(title: const Text('Course Detail')),
        body: const Center(child: Text('Bạn không có quyền truy cập')),
      );
    }

    final title = _course?['title']?.toString() ?? '';
    final subtitle =
        '${_course?['level'] ?? ''} • ${(_course?['isPremium'] == true) ? 'Premium' : 'Free'} • ${(_course?['published'] == true) ? 'Published' : 'Draft'}';

    return Scaffold(
      appBar: AppBar(
        title: Text(title.isEmpty ? 'Course Detail' : title),
        actions: [
          IconButton(
            onPressed: _loading ? null : _load,
            icon: const Icon(Icons.refresh),
          ),
          IconButton(
            onPressed: () => context.push('/admin/courses/${widget.courseId}/edit'),
            icon: const Icon(Icons.edit),
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
                        child: ListTile(
                          title: Text(title),
                          subtitle: Text(subtitle),
                        ),
                      ),
                      const SizedBox(height: 12),
                      ..._sections.map<Widget>((s) {
                        final section = (s as Map).cast<String, dynamic>();
                        final sectionId = section['id']?.toString() ?? '';
                        final sectionTitle = section['title']?.toString() ?? '';
                        final lessons =
                            (section['lessons'] as List?) ?? const <dynamic>[];

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
                                        sectionTitle,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w600,
                                          fontSize: 16,
                                        ),
                                      ),
                                    ),
                                    IconButton(
                                      onPressed: sectionId.isEmpty
                                          ? null
                                          : () => _createLesson(sectionId),
                                      icon: const Icon(Icons.add),
                                      tooltip: 'Add lesson',
                                    ),
                                    IconButton(
                                      onPressed: sectionId.isEmpty
                                          ? null
                                          : () => _deleteSection(sectionId),
                                      icon: const Icon(Icons.delete_outline),
                                      tooltip: 'Delete section',
                                    ),
                                  ],
                                ),
                                const Divider(height: 12),
                                if (lessons.isEmpty)
                                  const Padding(
                                    padding: EdgeInsets.symmetric(vertical: 8),
                                    child: Text('No lessons'),
                                  )
                                else
                                  ...lessons.map<Widget>((l) {
                                    final lesson =
                                        (l as Map).cast<String, dynamic>();
                                    final lessonId =
                                        lesson['id']?.toString() ?? '';
                                    final lessonTitle =
                                        lesson['title']?.toString() ?? '';
                                    final minutes =
                                        lesson['estimatedMinutes']?.toString() ??
                                            '';
                                    return ListTile(
                                      contentPadding: EdgeInsets.zero,
                                      title: Text(lessonTitle),
                                      subtitle: minutes.isEmpty
                                          ? null
                                          : Text('$minutes phút'),
                                      onTap: lessonId.isEmpty
                                          ? null
                                          : () =>
                                              context.push('/admin/lessons/$lessonId'),
                                      trailing: IconButton(
                                        onPressed: lessonId.isEmpty
                                            ? null
                                            : () => _deleteLesson(lessonId),
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
                ),
    );
  }
}

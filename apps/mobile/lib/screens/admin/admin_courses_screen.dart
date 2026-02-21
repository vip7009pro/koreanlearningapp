import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'dart:convert';
import '../../core/api_client.dart';
import '../../providers/auth_provider.dart';

class AdminCoursesScreen extends ConsumerStatefulWidget {
  const AdminCoursesScreen({super.key});

  @override
  ConsumerState<AdminCoursesScreen> createState() =>
      _AdminCoursesScreenState();
}

class _AdminCoursesScreenState extends ConsumerState<AdminCoursesScreen> {
  bool _loading = true;
  String? _error;
  List<dynamic> _courses = [];

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
      final res = await api.getCourses();
      final data = res.data;

      if (!mounted) return;
      setState(() {
        _courses = (data is Map && data['data'] is List) ? data['data'] : (data as List? ?? []);
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

  Future<void> _confirmDelete(String courseId) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Xóa course?'),
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
      await api.deleteCourse(courseId);
      if (!mounted) return;
      await _load();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Đã xóa course')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Lỗi xóa course: $e')),
      );
    }
  }

  Future<void> _togglePublish(Map<String, dynamic> course) async {
    final id = course['id'] as String?;
    if (id == null) return;
    final published = course['published'] == true;

    try {
      final api = ref.read(apiClientProvider);
      if (published) {
        await api.unpublishCourse(id);
      } else {
        await api.publishCourse(id);
      }
      if (!mounted) return;
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Lỗi cập nhật publish: $e')),
      );
    }
  }

  Future<void> _showImportDialog() async {
    final controller = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Import course JSON'),
        content: SizedBox(
          width: double.maxFinite,
          child: TextField(
            controller: controller,
            minLines: 8,
            maxLines: 16,
            decoration: const InputDecoration(
              hintText: '{ "title": "...", "sections": [...] }',
              border: OutlineInputBorder(),
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
      final raw = controller.text.trim();
      if (raw.isEmpty) return;
      final data = _tryParseJson(raw);
      if (data == null) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('JSON không hợp lệ')),
        );
        return;
      }
      final api = ref.read(apiClientProvider);
      await api.importCourse(data);
      if (!mounted) return;
      await _load();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Import thành công')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Lỗi import: $e')),
      );
    }
  }

  Map<String, dynamic>? _tryParseJson(String raw) {
    try {
      // ignore: avoid_dynamic_calls
      final decoded = (raw.isNotEmpty) ? jsonDecode(raw) : null;
      if (decoded is Map<String, dynamic>) return decoded;
      if (decoded is Map) return decoded.cast<String, dynamic>();
      return null;
    } catch (_) {
      return null;
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

    return Scaffold(
      appBar: AppBar(
        title: const Text('Quản lý Courses'),
        actions: [
          IconButton(
            onPressed: _showImportDialog,
            icon: const Icon(Icons.file_upload),
            tooltip: 'Import JSON',
          ),
          IconButton(
            onPressed: _loading ? null : _load,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.push('/admin/courses/new'),
        child: const Icon(Icons.add),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!))
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView.separated(
                    padding: const EdgeInsets.all(12),
                    itemCount: _courses.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final course = (_courses[index] as Map).cast<String, dynamic>();
                      final id = course['id']?.toString() ?? '';
                      final title = course['title']?.toString() ?? '';
                      final level = course['level']?.toString() ?? '';
                      final isPremium = course['isPremium'] == true;
                      final published = course['published'] == true;

                      return Card(
                        child: ListTile(
                          onTap: id.isEmpty
                              ? null
                              : () => context.push('/admin/courses/$id'),
                          title: Text(
                            title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          subtitle: Text(
                            '$level • ${isPremium ? 'Premium' : 'Free'} • ${published ? 'Published' : 'Draft'}',
                          ),
                          trailing: PopupMenuButton<String>(
                            onSelected: (value) {
                              if (value == 'edit' && id.isNotEmpty) {
                                context.push('/admin/courses/$id/edit');
                              }
                              if (value == 'delete' && id.isNotEmpty) {
                                _confirmDelete(id);
                              }
                              if (value == 'togglePublish') {
                                _togglePublish(course);
                              }
                            },
                            itemBuilder: (_) => [
                              PopupMenuItem(
                                value: 'togglePublish',
                                child: Text(published ? 'Unpublish' : 'Publish'),
                              ),
                              const PopupMenuItem(
                                value: 'edit',
                                child: Text('Edit'),
                              ),
                              const PopupMenuItem(
                                value: 'delete',
                                child: Text('Delete'),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
    );
  }
}

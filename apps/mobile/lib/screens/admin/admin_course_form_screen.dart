import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/api_client.dart';
import '../../providers/auth_provider.dart';

class AdminCourseFormScreen extends ConsumerStatefulWidget {
  final String? courseId;
  const AdminCourseFormScreen({super.key, this.courseId});

  @override
  ConsumerState<AdminCourseFormScreen> createState() =>
      _AdminCourseFormScreenState();
}

class _AdminCourseFormScreenState extends ConsumerState<AdminCourseFormScreen> {
  final _formKey = GlobalKey<FormState>();

  bool _loading = true;
  String? _error;

  final _titleCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _thumbCtrl = TextEditingController();

  String _level = 'BEGINNER';
  bool _isPremium = false;

  bool get _isEdit => widget.courseId != null;

  @override
  void initState() {
    super.initState();
    _init();
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    _thumbCtrl.dispose();
    super.dispose();
  }

  Future<void> _init() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    if (!_isEdit) {
      setState(() => _loading = false);
      return;
    }

    try {
      final api = ref.read(apiClientProvider);
      final res = await api.getCourse(widget.courseId!);
      final course = (res.data as Map).cast<String, dynamic>();

      _titleCtrl.text = course['title']?.toString() ?? '';
      _descCtrl.text = course['description']?.toString() ?? '';
      _thumbCtrl.text = course['thumbnailUrl']?.toString() ?? '';
      _level = course['level']?.toString() ?? 'BEGINNER';
      _isPremium = course['isPremium'] == true;

      if (!mounted) return;
      setState(() => _loading = false);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final payload = <String, dynamic>{
      'title': _titleCtrl.text.trim(),
      'description': _descCtrl.text.trim(),
      'level': _level,
      'isPremium': _isPremium,
      'thumbnailUrl': _thumbCtrl.text.trim().isEmpty ? null : _thumbCtrl.text.trim(),
    };

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final api = ref.read(apiClientProvider);
      if (_isEdit) {
        await api.updateCourse(widget.courseId!, payload);
      } else {
        await api.createCourse(payload);
      }
      if (!mounted) return;
      context.pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final role = ref.watch(authProvider).user?['role'];
    if (role != 'ADMIN') {
      return Scaffold(
        appBar: AppBar(title: const Text('Course Form')),
        body: const Center(child: Text('Bạn không có quyền truy cập')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEdit ? 'Edit Course' : 'New Course'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!))
              : Form(
                  key: _formKey,
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      TextFormField(
                        controller: _titleCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Title',
                          border: OutlineInputBorder(),
                        ),
                        validator: (v) =>
                            (v == null || v.trim().isEmpty) ? 'Required' : null,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _descCtrl,
                        minLines: 3,
                        maxLines: 5,
                        decoration: const InputDecoration(
                          labelText: 'Description',
                          border: OutlineInputBorder(),
                        ),
                        validator: (v) =>
                            (v == null || v.trim().isEmpty) ? 'Required' : null,
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        value: _level,
                        decoration: const InputDecoration(
                          labelText: 'Level',
                          border: OutlineInputBorder(),
                        ),
                        items: const [
                          DropdownMenuItem(
                            value: 'BEGINNER',
                            child: Text('BEGINNER'),
                          ),
                          DropdownMenuItem(
                            value: 'INTERMEDIATE',
                            child: Text('INTERMEDIATE'),
                          ),
                          DropdownMenuItem(
                            value: 'ADVANCED',
                            child: Text('ADVANCED'),
                          ),
                        ],
                        onChanged: (v) {
                          if (v == null) return;
                          setState(() => _level = v);
                        },
                      ),
                      const SizedBox(height: 12),
                      SwitchListTile(
                        value: _isPremium,
                        onChanged: (v) => setState(() => _isPremium = v),
                        title: const Text('Premium'),
                        contentPadding: EdgeInsets.zero,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _thumbCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Thumbnail URL (optional)',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton(
                          onPressed: _submit,
                          child: Text(_isEdit ? 'Save' : 'Create'),
                        ),
                      ),
                    ],
                  ),
                ),
    );
  }
}

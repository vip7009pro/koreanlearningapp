import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/api_client.dart';
import '../../providers/auth_provider.dart';

class AdminUsersScreen extends ConsumerStatefulWidget {
  const AdminUsersScreen({super.key});

  @override
  ConsumerState<AdminUsersScreen> createState() => _AdminUsersScreenState();
}

class _AdminUsersScreenState extends ConsumerState<AdminUsersScreen> {
  bool _loading = true;
  String? _error;
  int _page = 1;
  final int _limit = 20;
  int _totalPages = 1;
  List<dynamic> _users = [];

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
      final res = await api.getUsers(page: _page, limit: _limit);
      final data = (res.data as Map).cast<String, dynamic>();
      if (!mounted) return;
      setState(() {
        _users = (data['data'] as List?) ?? [];
        _totalPages = (data['totalPages'] as int?) ?? 1;
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

  Future<void> _confirmDelete(Map<String, dynamic> user) async {
    final id = user['id']?.toString() ?? '';
    if (id.isEmpty) return;

    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Xóa user?'),
        content: Text('Xóa ${user['email'] ?? ''}?'),
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
      await api.deleteUser(id);
      if (!mounted) return;
      await _load();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Đã xóa user')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Lỗi xóa user: $e')),
      );
    }
  }

  Future<void> _changeRole(Map<String, dynamic> user) async {
    final id = user['id']?.toString() ?? '';
    if (id.isEmpty) return;
    final currentRole = user['role']?.toString() ?? 'USER';

    String selected = currentRole;
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cập nhật role'),
        content: StatefulBuilder(
          builder: (context, setLocal) => DropdownButtonFormField<String>(
            initialValue: selected,
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              labelText: 'Role',
            ),
            items: const [
              DropdownMenuItem(value: 'USER', child: Text('USER')),
              DropdownMenuItem(value: 'ADMIN', child: Text('ADMIN')),
            ],
            onChanged: (v) {
              if (v == null) return;
              setLocal(() => selected = v);
            },
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
    if (selected == currentRole) return;

    try {
      final api = ref.read(apiClientProvider);
      await api.updateUser(id, {'role': selected});
      if (!mounted) return;
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Lỗi cập nhật role: $e')),
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

    return Scaffold(
      appBar: AppBar(
        title: const Text('Quản lý Users'),
        actions: [
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
              : RefreshIndicator(
                  onRefresh: _load,
                  child: Column(
                    children: [
                      Expanded(
                        child: ListView.separated(
                          padding: const EdgeInsets.all(12),
                          itemCount: _users.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 8),
                          itemBuilder: (context, index) {
                            final user =
                                (_users[index] as Map).cast<String, dynamic>();
                            final displayName =
                                user['displayName']?.toString() ?? '';
                            final email = user['email']?.toString() ?? '';
                            final uRole = user['role']?.toString() ?? '';
                            final xp = user['totalXP'] ?? 0;
                            final streak = user['streakDays'] ?? 0;

                            final isAdmin = uRole == 'ADMIN';

                            return Card(
                              child: ListTile(
                                title: Text(
                                    displayName.isEmpty ? email : displayName),
                                subtitle: Text(
                                    '$email\nRole: $uRole • XP: $xp • 🔥 $streak'),
                                isThreeLine: true,
                                trailing: PopupMenuButton<String>(
                                  onSelected: (v) {
                                    if (v == 'role') _changeRole(user);
                                    if (v == 'delete') _confirmDelete(user);
                                  },
                                  itemBuilder: (_) => [
                                    const PopupMenuItem(
                                      value: 'role',
                                      child: Text('Change role'),
                                    ),
                                    PopupMenuItem(
                                      value: 'delete',
                                      enabled: !isAdmin,
                                      child: const Text('Delete'),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                        child: Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                onPressed: _page <= 1
                                    ? null
                                    : () {
                                        setState(() => _page--);
                                        _load();
                                      },
                                child: const Text('Prev'),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Text('$_page / $_totalPages'),
                            const SizedBox(width: 12),
                            Expanded(
                              child: OutlinedButton(
                                onPressed: _page >= _totalPages
                                    ? null
                                    : () {
                                        setState(() => _page++);
                                        _load();
                                      },
                                child: const Text('Next'),
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
}

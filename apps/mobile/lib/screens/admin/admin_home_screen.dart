import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../providers/app_settings_provider.dart';

class AdminHomeScreen extends ConsumerWidget {
  const AdminHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeId = ref.watch(appSettingsProvider).themeId;
    final theme = AppSettingsNotifier.themeById(themeId);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Quản trị'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _AdminNavCard(
            icon: Icons.dashboard,
            title: 'Dashboard',
            subtitle: 'Thống kê tổng quan',
            onTap: () => context.push('/admin/dashboard'),
            color: theme.seedColor,
          ),
          const SizedBox(height: 12),
          _AdminNavCard(
            icon: Icons.school,
            title: 'Courses',
            subtitle: 'Quản lý khóa học / section / lesson',
            onTap: () => context.push('/admin/courses'),
            color: theme.seedColor,
          ),
          const SizedBox(height: 12),
          _AdminNavCard(
            icon: Icons.people,
            title: 'Users',
            subtitle: 'Quản lý người dùng',
            onTap: () => context.push('/admin/users'),
            color: theme.seedColor,
          ),
          const SizedBox(height: 12),
          _AdminNavCard(
            icon: Icons.upload_file,
            title: 'Upload',
            subtitle: 'Tải lên audio / image',
            onTap: () => context.push('/admin/upload'),
            color: theme.seedColor,
          ),
          const SizedBox(height: 12),
          _AdminNavCard(
            icon: Icons.fact_check,
            title: 'TOPIK',
            subtitle: 'Quản lý đề thi TOPIK',
            onTap: () => context.push('/admin/topik'),
            color: theme.seedColor,
          ),
        ],
      ),
    );
  }
}

class _AdminNavCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final Color color;

  const _AdminNavCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: color),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}

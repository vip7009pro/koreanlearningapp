import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../providers/app_settings_provider.dart';

class WritingDetailScreen extends ConsumerWidget {
  final Map<String, dynamic> item;
  const WritingDetailScreen({super.key, required this.item});

  Color _scoreColor(int score) {
    if (score >= 80) return Colors.green;
    if (score >= 50) return Colors.orange;
    return Colors.red;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeId = ref.watch(appSettingsProvider).themeId;
    final theme = AppSettingsNotifier.themeById(themeId);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final score = item['score'] ?? 0;
    final prompt = item['prompt'] ?? '';
    final answer = item['userAnswer'] ?? '';
    final feedback = item['aiFeedback'] ?? '';
    final createdAt = item['createdAt'] != null
        ? DateFormat('dd/MM/yyyy HH:mm')
            .format(DateTime.parse(item['createdAt']).toLocal())
        : '';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Chi tiết bài viết'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Date
            Text(
              createdAt,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: isDark ? Colors.grey.shade400 : Colors.grey.shade500,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 16),

            // Score
            Center(
              child: Stack(
                alignment: Alignment.center,
                children: [
                  SizedBox(
                    width: 100,
                    height: 100,
                    child: CircularProgressIndicator(
                      value: score / 100,
                      strokeWidth: 10,
                      backgroundColor:
                          _scoreColor(score).withValues(alpha: 0.2),
                      valueColor: AlwaysStoppedAnimation(_scoreColor(score)),
                    ),
                  ),
                  Column(
                    children: [
                      Text(
                        '$score',
                        style: TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                          color: _scoreColor(score),
                        ),
                      ),
                      Text(
                        'điểm',
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark
                              ? Colors.grey.shade400
                              : Colors.grey.shade500,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Topic
            _buildSection(
              context,
              icon: Icons.edit_note,
              title: 'Chủ đề viết',
              color: theme.seedColor,
              child: Text(prompt, style: const TextStyle(fontSize: 15)),
            ),
            const SizedBox(height: 16),

            // User answer
            _buildSection(
              context,
              icon: Icons.person,
              title: 'Bài viết của bạn',
              color: theme.seedColor,
              child: Text(answer, style: const TextStyle(fontSize: 15)),
            ),
            const SizedBox(height: 16),

            // AI Feedback
            _buildSection(
              context,
              icon: Icons.lightbulb,
              title: 'Nhận xét của AI',
              color: Colors.green,
              child: Text(feedback, style: const TextStyle(fontSize: 15)),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildSection(
    BuildContext context, {
    required IconData icon,
    required String title,
    required Color color,
    required Widget child,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark
            ? color.withValues(alpha: 0.1)
            : color.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark
              ? color.withValues(alpha: 0.2)
              : color.withValues(alpha: 0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(width: 8),
              Text(
                title,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: color,
                  fontSize: 14,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

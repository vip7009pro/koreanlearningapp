import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/app_settings_provider.dart';

class TopikExamsScreen extends ConsumerWidget {
  const TopikExamsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(appSettingsProvider);
    final palette = AppSettingsNotifier.themeById(settings.themeId);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Luyện đề TOPIK'),
        foregroundColor: Colors.white,
        backgroundColor: Colors.transparent,
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: palette.gradient),
          ),
        ),
      ),
      body: const Center(
        child: Text(
          'Module TOPIK sẽ được triển khai ở bước tiếp theo.',
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}

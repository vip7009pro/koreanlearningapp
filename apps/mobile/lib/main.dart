import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/router.dart';
import 'core/theme.dart';
import 'providers/app_settings_provider.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const ProviderScope(child: KoreanLearningApp()));
}

class KoreanLearningApp extends ConsumerWidget {
  const KoreanLearningApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    final settings = ref.watch(appSettingsProvider);
    final theme = AppSettingsNotifier.themeById(settings.themeId);

    return MaterialApp.router(
      title: 'Tiếng Hàn FDI',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightThemeForSeed(theme.seedColor),
      darkTheme: AppTheme.darkThemeForSeed(theme.seedColor),
      themeMode: settings.themeMode,
      routerConfig: router,
    );
  }
}

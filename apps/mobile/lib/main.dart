import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'core/router.dart';
import 'core/ads_manager.dart';
import 'core/backend_config.dart';
import 'core/theme.dart';
import 'providers/app_settings_provider.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  await MobileAds.instance.initialize();
  await BackendConfig.init();
  await Hive.initFlutter();
  await Hive.openBox('offline_box');
  runApp(const ProviderScope(child: KoreanLearningApp()));
}

class KoreanLearningApp extends ConsumerStatefulWidget {
  const KoreanLearningApp({super.key});

  @override
  ConsumerState<KoreanLearningApp> createState() => _KoreanLearningAppState();
}

class _KoreanLearningAppState extends ConsumerState<KoreanLearningApp>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final adsManager = ref.read(adsManagerProvider);
      adsManager.preload();
      unawaited(adsManager.handleAppResumed());
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(ref.read(adsManagerProvider).handleAppResumed());
    }
  }

  @override
  Widget build(BuildContext context) {
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

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/biometric_auth.dart';
import '../core/tts_service.dart';
import '../providers/app_settings_provider.dart';
import '../widgets/app_banner_ad.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(appSettingsProvider);
    final theme = AppSettingsNotifier.themeById(settings.themeId);
    final deviceVoiceStatus = ref.watch(deviceKoreanVoiceAvailableProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Cài đặt'),
        foregroundColor: Colors.white,
        backgroundColor: Colors.transparent,
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: theme.gradient),
          ),
        ),
      ),
      body: ListView(
        children: [
          ListTile(
            leading: const Icon(Icons.palette_outlined),
            title: const Text('Thay đổi theme'),
            subtitle:
                Text(AppSettingsNotifier.themeById(settings.themeId).name),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push('/settings/theme'),
          ),
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 20, 16, 8),
            child: Text(
              'TTS',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
            ),
          ),
          RadioGroup<String>(
            groupValue: settings.ttsMode,
            onChanged: (value) {
              if (value == null) return;
              ref.read(appSettingsProvider.notifier).setTtsMode(value);
            },
            child: Column(
              children: [
                RadioListTile<String>(
                  secondary: const Icon(Icons.phone_android_outlined),
                  title: const Text('Giọng mặc định của máy'),
                  subtitle: const Text('Dùng TTS có sẵn trên thiết bị'),
                  value: AppSettingsNotifier.ttsModeDevice,
                ),
                RadioListTile<String>(
                  secondary: const Icon(Icons.graphic_eq_outlined),
                  title: const Text('Giọng Hàn tự nhiên'),
                  subtitle: const Text('Dùng Google Cloud TTS neural voice'),
                  value: AppSettingsNotifier.ttsModeNatural,
                ),
              ],
            ),
          ),
          deviceVoiceStatus.when(
            loading: () => const Padding(
              padding: EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: LinearProgressIndicator(minHeight: 2),
            ),
            error: (_, __) => const SizedBox.shrink(),
            data: (hasKoreanVoice) {
              if (hasKoreanVoice) return const SizedBox.shrink();

              return Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: Card(
                  child: ListTile(
                    leading: const Icon(Icons.download_outlined),
                    title: const Text('Tải giọng tiếng Hàn cho máy'),
                    subtitle: const Text(
                      'Mở cài đặt TTS của thiết bị để tải hoặc chọn voice tiếng Hàn.',
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () async {
                      final opened =
                          await ref.read(ttsProvider).openDeviceTtsSettings();
                      if (!context.mounted) return;
                      ref.invalidate(deviceKoreanVoiceAvailableProvider);
                      if (!opened) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'Không thể mở cài đặt TTS trên thiết bị này.',
                            ),
                          ),
                        );
                      }
                    },
                  ),
                ),
              );
            },
          ),
          SwitchListTile(
            secondary: const Icon(Icons.fingerprint),
            title: const Text('Đăng nhập sinh trắc học'),
            subtitle:
                const Text('Bật để cho phép đăng nhập bằng vân tay/FaceID'),
            value: settings.biometricLoginEnabled,
            onChanged: (v) async {
              if (v) {
                final supported = await BiometricAuth.canCheckBiometrics();
                if (!context.mounted) return;
                if (!supported) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'Thiết bị chưa hỗ trợ sinh trắc học hoặc chưa cấu hình vân tay/FaceID.',
                      ),
                    ),
                  );
                  return;
                }
                await ref
                    .read(appSettingsProvider.notifier)
                    .setBiometricLoginEnabled(true);
              } else {
                await ref
                    .read(appSettingsProvider.notifier)
                    .setBiometricLoginEnabled(false);
                await BiometricAuth.clearCredentials();
              }
            },
          ),
          const SizedBox(height: 16),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: AppBannerAd(),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/biometric_auth.dart';
import '../providers/app_settings_provider.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(appSettingsProvider);
    final theme = AppSettingsNotifier.themeById(settings.themeId);

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
            subtitle: Text(AppSettingsNotifier.themeById(settings.themeId).name),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push('/settings/theme'),
          ),
          SwitchListTile(
            secondary: const Icon(Icons.fingerprint),
            title: const Text('Đăng nhập sinh trắc học'),
            subtitle: const Text('Bật để cho phép đăng nhập bằng vân tay/FaceID'),
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
        ],
      ),
    );
  }
}

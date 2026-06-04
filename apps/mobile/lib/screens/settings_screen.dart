import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/api_client.dart';
import '../core/backend_config.dart';
import '../core/biometric_auth.dart';
import '../core/tts_service.dart';
import '../providers/app_settings_provider.dart';
import '../providers/auth_provider.dart';
import '../widgets/app_banner_ad.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  @override
  Widget build(BuildContext context) {
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
          ListTile(
            leading: const Icon(Icons.dns_outlined),
            title: const Text('Địa chỉ máy chủ (API)'),
            subtitle: Text(BackendConfig.currentUrl),
            trailing: const Icon(Icons.edit_outlined),
            onTap: () => _showEditServerDialog(context),
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
          const Divider(height: 32),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TextButton.icon(
              onPressed: () => _showDeleteAccountDialog(context, ref),
              icon: const Icon(Icons.delete_forever_outlined, color: Colors.redAccent),
              label: const Text(
                'Xóa tài khoản (Vô hiệu hóa)',
                style: TextStyle(
                  color: Colors.redAccent,
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                ),
              ),
              style: TextButton.styleFrom(
                alignment: Alignment.centerLeft,
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
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

  void _showDeleteAccountDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.redAccent),
            SizedBox(width: 8),
            Text('Xóa tài khoản?'),
          ],
        ),
        content: const Text(
          'Tài khoản của bạn sẽ bị vô hiệu hóa và bạn sẽ bị đăng xuất khỏi ứng dụng. '
          'Toàn bộ tiến trình học tập của bạn sẽ được tạm ẩn. '
          'Nếu muốn khôi phục lại tài khoản trong tương lai, bạn có thể liên hệ bộ phận hỗ trợ qua email support@tienghanfdi.com.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Hủy'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context); // Close dialog
              try {
                // Show loading indicator
                showDialog(
                  context: context,
                  barrierDismissible: false,
                  builder: (context) => const Center(
                    child: CircularProgressIndicator(),
                  ),
                );

                await ref.read(authProvider.notifier).deactivateAccount();

                if (context.mounted) {
                  Navigator.pop(context); // Close loading indicator
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Tài khoản của bạn đã được vô hiệu hóa.'),
                    ),
                  );
                  context.go('/');
                }
              } catch (e) {
                if (context.mounted) {
                  Navigator.pop(context); // Close loading indicator
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Không thể vô hiệu hóa tài khoản: $e'),
                    ),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
            ),
            child: const Text('Xóa tài khoản'),
          ),
        ],
      ),
    );
  }

  void _showEditServerDialog(BuildContext context) {
    final controller = TextEditingController(text: BackendConfig.currentUrl);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cấu hình Địa chỉ máy chủ'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Nhập URL API backend mới:'),
            const SizedBox(height: 8),
            TextField(
              controller: controller,
              decoration: const InputDecoration(
                hintText: 'http://14.160.33.94:3000/api',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              '* Ứng dụng sẽ tự động thêm hậu tố "/api" nếu thiếu.',
              style: TextStyle(color: Colors.grey, fontSize: 12),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Hủy'),
          ),
          ElevatedButton(
            onPressed: () async {
              final newUrl = controller.text.trim();
              if (newUrl.isNotEmpty) {
                await BackendConfig.setManualUrl(newUrl);
                // Update ApiClient instance's baseUrl
                ref.read(apiClientProvider).updateBaseUrl(BackendConfig.currentUrl);

                if (context.mounted) {
                  Navigator.pop(context);
                  setState(() {}); // Refresh screen to show new URL
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Đã cập nhật máy chủ: ${BackendConfig.currentUrl}')),
                  );
                }
              }
            },
            child: const Text('Lưu'),
          ),
        ],
      ),
    );
  }
}

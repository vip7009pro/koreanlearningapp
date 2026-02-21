import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import '../providers/auth_provider.dart';
import '../core/api_client.dart';
import '../providers/app_settings_provider.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  List<dynamic> _badges = [];
  Map<String, dynamic>? _reviewStats;
  bool _uploadingAvatar = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final api = ref.read(apiClientProvider);
    try {
      final badgesRes = await api.getUserBadges();
      final statsRes = await api.getReviewStats();
      if (mounted) {
        setState(() {
          _badges = badgesRes.data ?? [];
          _reviewStats = statsRes.data;
        });
      }
    } catch (_) {}
  }

  Future<void> _pickAndUploadAvatar() async {
    if (_uploadingAvatar) return;

    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
      maxWidth: 1024,
    );
    if (picked == null) return;

    setState(() => _uploadingAvatar = true);
    try {
      final api = ref.read(apiClientProvider);
      final uploadRes = await api.uploadAvatar(picked.path);
      final url = uploadRes.data['url'] as String?;

      if (url == null || url.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Upload avatar thất bại')),
          );
        }
        return;
      }

      await ref.read(authProvider.notifier).updateAvatarUrl(url);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Cập nhật avatar thành công')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi upload avatar: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _uploadingAvatar = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authProvider);
    final user = auth.user;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primary = Theme.of(context).colorScheme.primary;
    final api = ref.read(apiClientProvider);
    final settings = ref.watch(appSettingsProvider);
    final theme = AppSettingsNotifier.themeById(settings.themeId);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Trang cá nhân'),
        foregroundColor: Colors.white,
        backgroundColor: Colors.transparent,
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: theme.gradient),
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Profile Header
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    GestureDetector(
                      onTap: _pickAndUploadAvatar,
                      child: Stack(
                        alignment: Alignment.bottomRight,
                        children: [
                          CircleAvatar(
                            radius: 40,
                            backgroundColor:
                                primary.withValues(alpha: 0.1),
                            backgroundImage: (user?['avatarUrl'] != null &&
                                    (user?['avatarUrl'] as String)
                                        .toString()
                                        .isNotEmpty)
                                ? NetworkImage(
                                    api.absoluteUrl(user?['avatarUrl']),
                                  )
                                : null,
                            child: (user?['avatarUrl'] == null ||
                                    (user?['avatarUrl'] as String?)
                                            ?.isEmpty ==
                                        true)
                                ? Text(
                                    (user?['displayName'] ?? 'U')[0],
                                    style: TextStyle(
                                      fontSize: 32,
                                      fontWeight: FontWeight.bold,
                                      color: primary,
                                    ),
                                  )
                                : null,
                          ),
                          Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: isDark
                                  ? Colors.black.withValues(alpha: 0.6)
                                  : Colors.white,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: isDark
                                    ? Colors.white.withValues(alpha: 0.2)
                                    : Colors.grey.shade200,
                              ),
                            ),
                            child: _uploadingAvatar
                                ? const SizedBox(
                                    width: 14,
                                    height: 14,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : Icon(
                                    Icons.camera_alt,
                                    size: 14,
                                    color: isDark
                                        ? Colors.white
                                        : Colors.grey.shade700,
                                  ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      user?['displayName'] ?? '',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      user?['email'] ?? '',
                      style: TextStyle(color: Colors.grey.shade500),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _ProfileStat(
                          label: 'XP',
                          value: '${user?['totalXP'] ?? 0}',
                          icon: Icons.star,
                          color: Colors.amber,
                        ),
                        _ProfileStat(
                          label: 'Streak',
                          value: '${user?['streakDays'] ?? 0}',
                          icon: Icons.local_fire_department,
                          color: Colors.orange,
                        ),
                        _ProfileStat(
                          label: 'Badges',
                          value: '${_badges.length}',
                          icon: Icons.emoji_events,
                          color: Colors.purple,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Premium Upgrade Banner
            Card(
              color: isDark ? const Color(0xFF3B2F0B) : Colors.amber.shade50,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(
                  color: isDark ? Colors.amber.shade700 : Colors.amber,
                ),
              ),
              child: ListTile(
                leading: Icon(
                  Icons.star,
                  color: isDark ? Colors.amber.shade300 : Colors.amber,
                  size: 32,
                ),
                title: Text(
                  'Nâng cấp Premium',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.amber.shade100 : Colors.black87,
                  ),
                ),
                subtitle: Text(
                  'Mở khóa toàn bộ bài học, luyện AI và không quảng cáo.',
                  style: TextStyle(
                    color: isDark ? Colors.amber.shade100.withValues(alpha: 0.85) : null,
                  ),
                ),
                trailing: Icon(
                  Icons.arrow_forward_ios,
                  size: 16,
                  color: isDark ? Colors.amber.shade100 : null,
                ),
                onTap: () => context.push('/subscription'),
              ),
            ),
            const SizedBox(height: 16),

            // Review Stats
            if (_reviewStats != null)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.auto_stories,
                            size: 20,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                          SizedBox(width: 8),
                          Text(
                            'Ôn tập SRS',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _ReviewStat(
                            label: 'Tổng',
                            value: _reviewStats!['total'] ?? 0,
                            color: Colors.blue,
                          ),
                          _ReviewStat(
                            label: 'Cần ôn',
                            value: _reviewStats!['due'] ?? 0,
                            color: Colors.orange,
                          ),
                          _ReviewStat(
                            label: 'Thành thạo',
                            value: _reviewStats!['mastered'] ?? 0,
                            color: Colors.green,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            const SizedBox(height: 16),

            // Badges
            if (_badges.isNotEmpty)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(
                            Icons.emoji_events,
                            size: 20,
                            color: Colors.amber,
                          ),
                          SizedBox(width: 8),
                          Text(
                            'Huy hiệu',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: _badges.map<Widget>((b) {
                          final badge = b['badge'] ?? b;
                          return Chip(
                            avatar: Text(
                              badge['iconUrl'] ?? '🏆',
                              style: const TextStyle(fontSize: 16),
                            ),
                            label: Text(
                              badge['name'] ?? '',
                              style: const TextStyle(fontSize: 12),
                            ),
                          );
                        }).toList(),
                      ),
                    ],
                  ),
                ),
              ),
            const SizedBox(height: 16),

            // Logout
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => ref.read(authProvider.notifier).logout(),
                icon: const Icon(Icons.logout, color: Colors.red),
                label: const Text(
                  'Đăng xuất',
                  style: TextStyle(color: Colors.red),
                ),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Colors.red),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProfileStat extends StatelessWidget {
  final String label, value;
  final IconData icon;
  final Color color;
  const _ProfileStat({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, color: color, size: 28),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        Text(
          label,
          style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
        ),
      ],
    );
  }
}

class _ReviewStat extends StatelessWidget {
  final String label;
  final int value;
  final Color color;
  const _ReviewStat({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          '$value',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          label,
          style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
        ),
      ],
    );
  }
}

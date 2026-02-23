import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../core/api_client.dart';
import '../providers/app_settings_provider.dart';
import '../providers/auth_provider.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  List<dynamic> _courses = [];
  List<dynamic> _topikExams = [];
  Map<String, dynamic>? _dailyGoal;
  bool _loading = true;
  bool _isPremiumUser = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final api = ref.read(apiClientProvider);
    try {
      final coursesRes = await api.getCourses();
      final topikRes = await api.getTopikExams();
      final goalRes = await api.getDailyGoal();
      final premiumRes = await api.checkPremiumStatus();
      if (mounted) {
        setState(() {
          _courses = coursesRes.data?['data'] ?? [];
          _topikExams = (topikRes.data as List?) ?? [];
          _dailyGoal = goalRes.data;
          _isPremiumUser = premiumRes.data?['isPremium'] ?? false;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _handleOpenCourse(dynamic course) async {
    final isPremiumCourse = course['isPremium'] == true;

    if (!isPremiumCourse || _isPremiumUser) {
      if (mounted) context.push('/course/${course['id']}');
      return;
    }

    final shouldUpgrade = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Khóa học Premium'),
        content: const Text(
          'Khóa học này chỉ dành cho tài khoản Premium. Bạn muốn nâng cấp ngay không?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Để sau'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Nâng cấp'),
          ),
        ],
      ),
    );

    if (shouldUpgrade == true && mounted) {
      final upgraded = await context.push<bool>('/subscription');
      if (!mounted) return;
      if (upgraded == true) {
        setState(() {
          _isPremiumUser = true;
        });

        // Open course immediately after successful upgrade
        if (mounted) {
          context.push('/course/${course['id']}');
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authProvider);
    final user = auth.user;
    final api = ref.read(apiClientProvider);
    final themeId = ref.watch(appSettingsProvider).themeId;
    final theme = AppSettingsNotifier.themeById(themeId);

    return Scaffold(
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadData,
              child: CustomScrollView(
                slivers: [
                  // App Bar
                  SliverAppBar(
                    expandedHeight: 180,
                    floating: false,
                    pinned: true,
                    flexibleSpace: FlexibleSpaceBar(
                      background: Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(colors: theme.gradient),
                        ),
                        child: SafeArea(
                          child: Padding(
                            padding: const EdgeInsets.all(20),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Xin chào 👋',
                                          style: TextStyle(
                                            color: Colors.white.withValues(
                                              alpha: 0.8,
                                            ),
                                            fontSize: 14,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          user?['displayName'] ?? 'User',
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 22,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ],
                                    ),
                                    GestureDetector(
                                      onTap: () => context.push('/profile'),
                                      child: CircleAvatar(
                                        radius: 22,
                                        backgroundColor:
                                            Colors.white.withValues(alpha: 0.2),
                                        backgroundImage: (user?['avatarUrl'] !=
                                                    null &&
                                                (user?['avatarUrl'] as String)
                                                    .toString()
                                                    .isNotEmpty)
                                            ? NetworkImage(
                                                api.absoluteUrl(
                                                    user?['avatarUrl']
                                                        as String?),
                                              )
                                            : null,
                                        child: (user?['avatarUrl'] == null ||
                                                (user?['avatarUrl'] as String?)
                                                        ?.isEmpty ==
                                                    true)
                                            ? const Icon(
                                                Icons.person,
                                                color: Colors.white,
                                              )
                                            : null,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 16),
                                // Stats Row
                                Row(
                                  children: [
                                    _StatChip(
                                      icon: Icons.local_fire_department,
                                      label: '${user?['streakDays'] ?? 0} ngày',
                                      color: Colors.orange,
                                    ),
                                    const SizedBox(width: 12),
                                    _StatChip(
                                      icon: Icons.star,
                                      label: '${user?['totalXP'] ?? 0} XP',
                                      color: Colors.amber,
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),

                  // Daily Goal
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          Card(
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Icon(
                                        Icons.flag,
                                        color: Theme.of(context)
                                            .colorScheme
                                            .primary,
                                        size: 20,
                                      ),
                                      SizedBox(width: 8),
                                      Text(
                                        'Mục tiêu hôm nay',
                                        style: TextStyle(
                                          fontWeight: FontWeight.w600,
                                          fontSize: 16,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(8),
                                    child: LinearProgressIndicator(
                                      value: (_dailyGoal?['currentXP'] ?? 0) /
                                          (_dailyGoal?['targetXP'] ?? 50),
                                      minHeight: 10,
                                      backgroundColor: Colors.grey.shade200,
                                      valueColor: const AlwaysStoppedAnimation(
                                        Color(0xFF10B981),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    '${_dailyGoal?['currentXP'] ?? 0} / ${_dailyGoal?['targetXP'] ?? 50} XP',
                                    style: TextStyle(
                                      color: Colors.grey.shade600,
                                      fontSize: 13,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          InkWell(
                            onTap: () => context.push('/ai-practice'),
                            borderRadius: BorderRadius.circular(12),
                            child: Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                gradient:
                                    LinearGradient(colors: theme.gradient),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Row(
                                children: [
                                  Icon(Icons.edit_note,
                                      color: Colors.white, size: 32),
                                  SizedBox(width: 16),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text('Luyện Viết AI',
                                            style: TextStyle(
                                                color: Colors.white,
                                                fontWeight: FontWeight.bold,
                                                fontSize: 18)),
                                        Text('Chấm điểm & nhận xét tự động',
                                            style: TextStyle(
                                                color: Colors.white70,
                                                fontSize: 13)),
                                      ],
                                    ),
                                  ),
                                  Icon(Icons.arrow_forward_ios,
                                      color: Colors.white, size: 16),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Courses Header
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Khóa học',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          TextButton(
                            onPressed: () => context.push('/courses'),
                            child: const Text('Xem tất cả'),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Course List
                  SliverList(
                    delegate: SliverChildBuilderDelegate((context, index) {
                      final course = _courses[index];
                      return Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 4,
                        ),
                        child: Card(
                          child: InkWell(
                            onTap: () => _handleOpenCourse(course),
                            borderRadius: BorderRadius.circular(16),
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Row(
                                children: [
                                  Container(
                                    width: 56,
                                    height: 56,
                                    decoration: BoxDecoration(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .primary
                                          .withValues(alpha: 0.12),
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                    child: const Center(
                                      child: Text(
                                        '📚',
                                        style: TextStyle(fontSize: 28),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          course['title'] ?? '',
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w600,
                                            fontSize: 15,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          course['description'] ?? '',
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            fontSize: 13,
                                            color: Colors.grey.shade600,
                                          ),
                                        ),
                                        const SizedBox(height: 8),
                                        Row(
                                          children: [
                                            _LevelBadge(
                                              level:
                                                  course['level'] ?? 'BEGINNER',
                                            ),
                                            if (course['isPremium'] ==
                                                true) ...[
                                              const SizedBox(width: 8),
                                              Container(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                  horizontal: 8,
                                                  vertical: 2,
                                                ),
                                                decoration: BoxDecoration(
                                                  color: Colors.amber.shade100,
                                                  borderRadius:
                                                      BorderRadius.circular(6),
                                                ),
                                                child: Text(
                                                  'Premium',
                                                  style: TextStyle(
                                                    fontSize: 11,
                                                    color:
                                                        Colors.amber.shade900,
                                                    fontWeight: FontWeight.w500,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                  Icon(
                                    Icons.chevron_right,
                                    color: Colors.grey.shade400,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    }, childCount: _courses.length > 3 ? 3 : _courses.length),
                  ),

                  const SliverToBoxAdapter(child: SizedBox(height: 12)),

                  // TOPIK section
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Luyện đề TOPIK',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 10),
                          InkWell(
                            onTap: () => context.push('/topik'),
                            borderRadius: BorderRadius.circular(16),
                            child: Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(colors: theme.gradient),
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: const Row(
                                children: [
                                  Icon(
                                    Icons.assignment_turned_in_outlined,
                                    color: Colors.white,
                                    size: 30,
                                  ),
                                  SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Luyện đề TOPIK',
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 16,
                                          ),
                                        ),
                                        SizedBox(height: 2),
                                        Text(
                                          'Làm đề - lưu tiến độ - chấm điểm - review',
                                          style: TextStyle(
                                            color: Colors.white70,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Icon(
                                    Icons.arrow_forward_ios,
                                    color: Colors.white,
                                    size: 16,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // TOPIK trending exams (top 3)
                  SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final exams = _topikExams;
                        final exam = exams[index] as Map;
                        final id = (exam['id'] ?? '').toString();
                        final title = (exam['title'] ?? 'TOPIK').toString();
                        final topikLevel = (exam['topikLevel'] ?? '').toString();
                        final year = exam['year'];
                        return Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                          child: Card(
                            child: InkWell(
                              onTap: id.isEmpty ? null : () => context.push('/topik/exam/$id'),
                              borderRadius: BorderRadius.circular(16),
                              child: Padding(
                                padding: const EdgeInsets.all(16),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 56,
                                      height: 56,
                                      decoration: BoxDecoration(
                                        color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.12),
                                        borderRadius: BorderRadius.circular(14),
                                      ),
                                      child: const Center(
                                        child: Text('📝', style: TextStyle(fontSize: 26)),
                                      ),
                                    ),
                                    const SizedBox(width: 16),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            title,
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
                                          ),
                                          const SizedBox(height: 6),
                                          Row(
                                            children: [
                                              if (topikLevel.isNotEmpty)
                                                Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                                  decoration: BoxDecoration(
                                                    color: Colors.blue.withValues(alpha: 0.1),
                                                    borderRadius: BorderRadius.circular(6),
                                                  ),
                                                  child: Text(
                                                    topikLevel.replaceAll('_', ' '),
                                                    style: TextStyle(fontSize: 11, color: Colors.blue.shade900, fontWeight: FontWeight.w600),
                                                  ),
                                                ),
                                              if (year != null) ...[
                                                const SizedBox(width: 8),
                                                Text(
                                                  'Năm $year',
                                                  style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                                                ),
                                              ],
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                    Icon(Icons.chevron_right, color: Colors.grey.shade400),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                      childCount: _topikExams.length > 3 ? 3 : _topikExams.length,
                    ),
                  ),

                  const SliverToBoxAdapter(child: SizedBox(height: 20)),
                ],
              ),
            ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: 0,
        selectedItemColor: Theme.of(context).colorScheme.primary,
        unselectedItemColor: Colors.grey,
        type: BottomNavigationBarType.fixed,
        items: [
          const BottomNavigationBarItem(
              icon: Icon(Icons.home), label: 'Trang chủ'),
          const BottomNavigationBarItem(
            icon: Icon(Icons.auto_stories),
            label: 'Ôn tập',
          ),
          const BottomNavigationBarItem(
            icon: Icon(Icons.leaderboard),
            label: 'Bảng xếp hạng',
          ),
          const BottomNavigationBarItem(
              icon: Icon(Icons.person), label: 'Cá nhân'),
          const BottomNavigationBarItem(
            icon: Icon(Icons.settings),
            label: 'Cài đặt',
          ),
          if ((user?['role'] ?? '') == 'ADMIN')
            const BottomNavigationBarItem(
              icon: Icon(Icons.admin_panel_settings),
              label: 'Admin',
            ),
        ],
        onTap: (index) {
          final isAdmin = (user?['role'] ?? '') == 'ADMIN';
          if (index == 1) {
            context.push('/review');
          } else if (index == 2) {
            context.push('/leaderboard');
          } else if (index == 3) {
            context.push('/profile');
          } else if (index == 4) {
            context.push('/settings');
          } else if (index == 5 && isAdmin) {
            context.push('/admin');
          }
        },
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  const _StatChip({
    required this.icon,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w500,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }
}

class _LevelBadge extends StatelessWidget {
  final String level;
  const _LevelBadge({required this.level});

  @override
  Widget build(BuildContext context) {
    final colors = {
      'BEGINNER': Colors.green,
      'ELEMENTARY': Colors.teal,
      'INTERMEDIATE': Colors.blue,
      'ADVANCED': Colors.purple,
    };
    final c = colors[level] ?? Colors.grey;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        level,
        style: TextStyle(fontSize: 11, color: c, fontWeight: FontWeight.w500),
      ),
    );
  }
}

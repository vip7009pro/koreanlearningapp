import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/ads_manager.dart';
import '../core/api_client.dart';
import '../providers/app_settings_provider.dart';
import '../providers/auth_provider.dart';
import '../widgets/app_banner_ad.dart';

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
      try {
        await ref.read(authProvider.notifier).refreshProfile();
      } catch (_) {}
      if (mounted) {
        setState(() {
          _courses = coursesRes.data?['data'] ?? [];
          _topikExams = (topikRes.data as List?) ?? [];
          _dailyGoal = goalRes.data;
          _loading = false;
        });
        _checkAndShowTrialNotice();
      }
    } catch (_) {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _handleOpenCourse(dynamic course) async {
    await ref.read(adsManagerProvider).maybeShowInterstitialAd();
    if (!mounted) return;
    context.push('/course/${course['id']}');
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
                    expandedHeight: 235,
                    floating: false,
                    pinned: true,
                    automaticallyImplyLeading: false,
                    backgroundColor: theme.seedColor,
                    elevation: 0,
                    actions: [
                      Padding(
                        padding: const EdgeInsets.only(right: 16.0),
                        child: Center(
                          child: GestureDetector(
                            onTap: () => context.push('/profile'),
                            child: Container(
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: Colors.white.withValues(alpha: 0.3),
                                  width: 1.5,
                                ),
                              ),
                              child: CircleAvatar(
                                radius: 18,
                                backgroundColor: Colors.white.withValues(alpha: 0.2),
                                backgroundImage: (user?['avatarUrl'] != null &&
                                        (user?['avatarUrl'] as String?)?.isNotEmpty == true)
                                    ? NetworkImage(api.absoluteUrl(user?['avatarUrl'] as String?))
                                    : null,
                                child: (user?['avatarUrl'] == null ||
                                        (user?['avatarUrl'] as String?)?.isEmpty == true)
                                    ? const Icon(Icons.person, color: Colors.white, size: 18)
                                    : null,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                    flexibleSpace: FlexibleSpaceBar(
                      background: LayoutBuilder(
                        builder: (context, constraints) {
                          final topPadding = MediaQuery.of(context).padding.top;
                          const double expandedHeight = 235;
                          final double currentHeight = constraints.biggest.height;

                          // Calculate progress ratio (1.0 = expanded, 0.0 = collapsed)
                          final double rawProgress = (currentHeight - (kToolbarHeight + topPadding)) /
                              (expandedHeight - (kToolbarHeight + topPadding));
                          final double progress = rawProgress.clamp(0.0, 1.0);

                          return Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: theme.gradient,
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                            ),
                            child: Stack(
                              clipBehavior: Clip.antiAlias,
                              children: [
                                // Glowing background decorations
                                Positioned(
                                  top: -25,
                                  right: 40,
                                  child: Container(
                                    width: 120,
                                    height: 120,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: Colors.white.withValues(alpha: 0.12),
                                    ),
                                  ),
                                ),
                                Positioned(
                                  bottom: -20,
                                  left: 70,
                                  child: Container(
                                    width: 90,
                                    height: 90,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: Colors.white.withValues(alpha: 0.06),
                                    ),
                                  ),
                                ),

                                // Collapsed Header (Visible when progress is near 0)
                                if (progress < 0.95)
                                  Opacity(
                                    opacity: (1.0 - progress).clamp(0.0, 1.0),
                                    child: Container(
                                      padding: EdgeInsets.only(top: topPadding),
                                      height: kToolbarHeight + topPadding,
                                      alignment: Alignment.centerLeft,
                                      margin: const EdgeInsets.only(left: 16.0),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          const Icon(Icons.auto_awesome, color: Colors.amber, size: 18),
                                          const SizedBox(width: 8),
                                          const Text(
                                            'TIẾNG HÀN',
                                            style: TextStyle(
                                              color: Colors.white,
                                              fontSize: 16,
                                              fontWeight: FontWeight.w900,
                                              letterSpacing: 0.5,
                                            ),
                                          ),
                                          const SizedBox(width: 6),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                                            decoration: BoxDecoration(
                                              gradient: const LinearGradient(
                                                colors: [Colors.amber, Colors.orange],
                                              ),
                                              borderRadius: BorderRadius.circular(4),
                                            ),
                                            child: const Text(
                                              'FDI',
                                              style: TextStyle(
                                                color: Colors.black,
                                                fontWeight: FontWeight.w900,
                                                fontSize: 11,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),

                                // Expanded Header (Visible when progress is near 1)
                                if (progress > 0.05)
                                  Positioned(
                                    top: topPadding + 10,
                                    left: 16,
                                    right: 16,
                                    child: Opacity(
                                      opacity: progress.clamp(0.0, 1.0),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          // Greeting
                                          Text(
                                            'Xin chào 👋',
                                            style: TextStyle(
                                              color: Colors.white.withValues(alpha: 0.8),
                                              fontSize: 14,
                                            ),
                                          ),
                                          const SizedBox(height: 2),
                                          SizedBox(
                                            width: MediaQuery.of(context).size.width - 100,
                                            child: Text(
                                              user?['displayName'] ?? 'User',
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: const TextStyle(
                                                color: Colors.white,
                                                fontSize: 22,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                          const SizedBox(height: 20),
                                          // Branding
                                          Row(
                                            children: [
                                              Container(
                                                padding: const EdgeInsets.all(8),
                                                decoration: BoxDecoration(
                                                  color: Colors.white.withValues(alpha: 0.2),
                                                  borderRadius: BorderRadius.circular(12),
                                                  border: Border.all(
                                                    color: Colors.white.withValues(alpha: 0.15),
                                                  ),
                                                ),
                                                child: const Icon(
                                                  Icons.auto_awesome,
                                                  color: Colors.amber,
                                                  size: 24,
                                                ),
                                              ),
                                              const SizedBox(width: 12),
                                              Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  Row(
                                                    children: [
                                                      const Text(
                                                        'TIẾNG HÀN',
                                                        style: TextStyle(
                                                          color: Colors.white,
                                                          fontSize: 20,
                                                          fontWeight: FontWeight.w900,
                                                          letterSpacing: 1.0,
                                                        ),
                                                      ),
                                                      const SizedBox(width: 8),
                                                      Container(
                                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                                        decoration: BoxDecoration(
                                                          gradient: const LinearGradient(
                                                            colors: [Colors.amber, Colors.orange],
                                                          ),
                                                          borderRadius: BorderRadius.circular(6),
                                                        ),
                                                        child: const Text(
                                                          'FDI',
                                                          style: TextStyle(
                                                            color: Colors.black,
                                                            fontWeight: FontWeight.w900,
                                                            fontSize: 14,
                                                          ),
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                  const SizedBox(height: 2),
                                                  Text(
                                                    'Học tiếng Hàn, chạm ngàn cơ hội FDI',
                                                    style: TextStyle(
                                                      color: Colors.white.withValues(alpha: 0.85),
                                                      fontSize: 12,
                                                      fontWeight: FontWeight.w500,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 20),
                                          // Chips
                                          SingleChildScrollView(
                                            scrollDirection: Axis.horizontal,
                                            child: Row(
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
                                                const SizedBox(width: 12),
                                                _StatChip(
                                                  icon: Icons.auto_awesome,
                                                  label: (user?['role'] == 'ADMIN' ||
                                                          (user?['subscription'] != null &&
                                                              user?['subscription']?['planType'] != 'FREE'))
                                                      ? 'Vô hạn AI'
                                                      : '${user?['aiTicketsBalance'] ?? 0} vé AI',
                                                  color: Colors.cyanAccent,
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          );
                        },
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
                          Row(
                            children: [
                              Expanded(
                                child: InkWell(
                                  onTap: () => context.push('/ai-practice'),
                                  borderRadius: BorderRadius.circular(12),
                                  child: Container(
                                    padding: const EdgeInsets.all(16),
                                    height: 110,
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(colors: theme.gradient),
                                      borderRadius: BorderRadius.circular(12),
                                      boxShadow: [
                                        BoxShadow(
                                          color: theme.seedColor.withValues(alpha: 0.3),
                                          blurRadius: 8,
                                          offset: const Offset(0, 4),
                                        ),
                                      ],
                                    ),
                                    child: const Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Icon(Icons.edit_note, color: Colors.white, size: 28),
                                        SizedBox(height: 8),
                                        Text(
                                          'Luyện Viết AI ✍️',
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 15,
                                          ),
                                        ),
                                        SizedBox(height: 2),
                                        Text(
                                          'Chấm tự động',
                                          style: TextStyle(
                                            color: Colors.white70,
                                            fontSize: 11,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: InkWell(
                                  onTap: () => context.push('/specialized-vocab'),
                                  borderRadius: BorderRadius.circular(12),
                                  child: Container(
                                    padding: const EdgeInsets.all(16),
                                    height: 110,
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        colors: theme.gradient.reversed.toList(),
                                      ),
                                      borderRadius: BorderRadius.circular(12),
                                      boxShadow: [
                                        BoxShadow(
                                          color: theme.seedColor.withValues(alpha: 0.3),
                                          blurRadius: 8,
                                          offset: const Offset(0, 4),
                                        ),
                                      ],
                                    ),
                                    child: const Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Icon(Icons.business_center, color: Colors.white, size: 28),
                                        SizedBox(height: 8),
                                        Text(
                                          'Chuyên ngành 💼',
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 15,
                                          ),
                                        ),
                                        SizedBox(height: 2),
                                        Text(
                                          'IT, Văn phòng, EPS...',
                                          style: TextStyle(
                                            color: Colors.white70,
                                            fontSize: 11,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          InkWell(
                            onTap: () => context.push('/diagnostics'),
                            borderRadius: BorderRadius.circular(12),
                            child: Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    const Color(0xFF7C3AED),
                                    theme.seedColor,
                                  ],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                borderRadius: BorderRadius.circular(12),
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(0xFF7C3AED).withValues(alpha: 0.3),
                                    blurRadius: 8,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(10),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withValues(alpha: 0.2),
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(
                                      Icons.psychology,
                                      color: Colors.amber,
                                      size: 30,
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  const Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Text(
                                          'Bác sĩ Chẩn đoán Năng lực AI 🧠',
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 16,
                                          ),
                                        ),
                                        SizedBox(height: 4),
                                        Text(
                                          'Phân tích lỗi sai và đề xuất bài học ôn tập',
                                          style: TextStyle(
                                            color: Colors.white70,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const Icon(
                                    Icons.chevron_right,
                                    color: Colors.white,
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          InkWell(
                            onTap: () => context.push('/dialogues'),
                            borderRadius: BorderRadius.circular(12),
                            child: Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [
                                    Color(0xFF2563EB),
                                    Color(0xFF4F46E5),
                                  ],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                borderRadius: BorderRadius.circular(12),
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(0xFF4F46E5).withValues(alpha: 0.3),
                                    blurRadius: 8,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(10),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withValues(alpha: 0.2),
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(
                                      Icons.record_voice_over,
                                      color: Colors.white,
                                      size: 30,
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  const Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Text(
                                          'Hội Thoại AI Tương Tác 🎙️',
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 16,
                                          ),
                                        ),
                                        SizedBox(height: 4),
                                        Text(
                                          'Luyện giao tiếp phản xạ & Đánh giá phát âm',
                                          style: TextStyle(
                                            color: Colors.white70,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const Icon(
                                    Icons.chevron_right,
                                    color: Colors.white,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      child: AppBannerAd(adSize: AdSize.largeBanner),
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
                          vertical: 6,
                        ),
                        child: Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(colors: theme.gradient),
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: theme.seedColor.withValues(alpha: 0.3),
                                blurRadius: 8,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(16),
                            child: InkWell(
                              onTap: () => _handleOpenCourse(course),
                              child: Padding(
                                padding: const EdgeInsets.all(16),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 56,
                                      height: 56,
                                      decoration: BoxDecoration(
                                        color: Colors.white.withValues(alpha: 0.2),
                                        borderRadius: BorderRadius.circular(14),
                                        border: Border.all(
                                          color: Colors.white.withValues(alpha: 0.25),
                                          width: 1,
                                        ),
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
                                              fontWeight: FontWeight.bold,
                                              fontSize: 15,
                                              color: Colors.white,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            course['description'] ?? '',
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(
                                              fontSize: 13,
                                              color: Colors.white70,
                                            ),
                                          ),
                                          const SizedBox(height: 8),
                                          Row(
                                            children: [
                                              Container(
                                                padding: const EdgeInsets.symmetric(
                                                  horizontal: 8,
                                                  vertical: 2,
                                                ),
                                                decoration: BoxDecoration(
                                                  color: Colors.white.withValues(alpha: 0.2),
                                                  borderRadius: BorderRadius.circular(6),
                                                ),
                                                child: Text(
                                                  course['level'] ?? 'BEGINNER',
                                                  style: const TextStyle(
                                                    fontSize: 11,
                                                    color: Colors.white,
                                                    fontWeight: FontWeight.w600,
                                                  ),
                                                ),
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
                                                    color: Colors.amber,
                                                    borderRadius:
                                                        BorderRadius.circular(6),
                                                  ),
                                                  child: const Text(
                                                    'Ad-free',
                                                    style: TextStyle(
                                                      fontSize: 11,
                                                      color: Colors.black87,
                                                      fontWeight: FontWeight.bold,
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                    const Icon(
                                      Icons.chevron_right,
                                      color: Colors.white,
                                    ),
                                  ],
                                ),
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
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Luyện đề TOPIK',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          TextButton(
                            onPressed: () => context.push('/topik'),
                            child: const Text('Xem tất cả'),
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
                        final topikLevel =
                            (exam['topikLevel'] ?? '').toString();
                        final year = exam['year'];
                        return Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 6),
                          child: Container(
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [
                                  Color(0xFF2563EB),
                                  Color(0xFF4F46E5),
                                ],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFF4F46E5).withValues(alpha: 0.3),
                                  blurRadius: 8,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(16),
                              child: InkWell(
                                onTap: id.isEmpty
                                    ? null
                                    : () async {
                                        await ref
                                            .read(adsManagerProvider)
                                            .maybeShowInterstitialAd();
                                        if (!context.mounted) return;
                                        context.push('/topik/exam/$id');
                                      },
                                child: Padding(
                                  padding: const EdgeInsets.all(16),
                                  child: Row(
                                    children: [
                                      Container(
                                        width: 56,
                                        height: 56,
                                        decoration: BoxDecoration(
                                          color: Colors.white.withValues(alpha: 0.2),
                                          borderRadius: BorderRadius.circular(14),
                                          border: Border.all(
                                            color: Colors.white.withValues(alpha: 0.25),
                                            width: 1,
                                          ),
                                        ),
                                        child: const Center(
                                          child: Text('📝',
                                              style: TextStyle(fontSize: 26)),
                                        ),
                                      ),
                                      const SizedBox(width: 16),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              title,
                                              maxLines: 2,
                                              overflow: TextOverflow.ellipsis,
                                              style: const TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 15,
                                                  color: Colors.white),
                                            ),
                                            const SizedBox(height: 6),
                                            Row(
                                              children: [
                                                if (topikLevel.isNotEmpty)
                                                  Container(
                                                    padding: const EdgeInsets
                                                        .symmetric(
                                                        horizontal: 8,
                                                        vertical: 2),
                                                    decoration: BoxDecoration(
                                                      color: Colors.white.withValues(alpha: 0.2),
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                              6),
                                                    ),
                                                    child: Text(
                                                      topikLevel.replaceAll(
                                                          '_', ' '),
                                                      style: const TextStyle(
                                                          fontSize: 11,
                                                          color: Colors.white,
                                                          fontWeight:
                                                              FontWeight.w600),
                                                    ),
                                                  ),
                                                if (year != null) ...[
                                                  const SizedBox(width: 8),
                                                  Text(
                                                    'Năm $year',
                                                    style: const TextStyle(
                                                        fontSize: 12,
                                                        color: Colors.white70),
                                                  ),
                                                ],
                                              ],
                                            ),
                                          ],
                                        ),
                                      ),
                                      const Icon(Icons.chevron_right,
                                          color: Colors.white),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                      childCount:
                          _topikExams.length > 3 ? 3 : _topikExams.length,
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

  Future<void> _checkAndShowTrialNotice() async {
    final auth = ref.read(authProvider);
    final user = auth.user;
    if (user == null) return;

    final subscription = user['subscription'];
    final isPremium = subscription != null && subscription['planType'] != 'FREE';
    if (isPremium) return;

    final createdAtStr = user['createdAt'] as String?;
    if (createdAtStr == null) return;

    final createdAt = DateTime.tryParse(createdAtStr);
    if (createdAt == null) return;

    final difference = DateTime.now().difference(createdAt).inSeconds.abs();
    if (difference >= 24 * 3600) return; // More than 24 hours

    final prefs = await SharedPreferences.getInstance();
    final key = 'trial_notice_shown_${user['id']}';
    final alreadyShown = prefs.getBool(key) ?? false;
    if (alreadyShown) return;

    if (!mounted) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _showTrialDialog(context, key, prefs);
    });
  }

  void _showTrialDialog(BuildContext context, String key, SharedPreferences prefs) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        final themeId = ref.watch(appSettingsProvider).themeId;
        final theme = AppSettingsNotifier.themeById(themeId);
        
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          elevation: 10,
          backgroundColor: Colors.transparent,
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.1),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: theme.gradient,
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(20),
                      topRight: Radius.circular(20),
                    ),
                  ),
                  child: const Column(
                    children: [
                      Icon(
                        Icons.auto_awesome,
                        color: Colors.amber,
                        size: 48,
                      ),
                      SizedBox(height: 12),
                      Text(
                        'QUÀ TẶNG TRẢI NGHIỆM! 🎁',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      const Text(
                        'Chào mừng bạn đến với Tiếng Hàn FDI!',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 12),
                      RichText(
                        textAlign: TextAlign.center,
                        text: TextSpan(
                          style: const TextStyle(
                            fontSize: 14,
                            color: Colors.black54,
                            height: 1.4,
                          ),
                          children: [
                            const TextSpan(text: 'Bạn được tặng '),
                            TextSpan(
                              text: '1 ngày trải nghiệm HOÀN TOÀN KHÔNG QUẢNG CÁO',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: theme.seedColor,
                              ),
                            ),
                            const TextSpan(text: ' để thoả sức học tập và ôn tập hiệu quả nhất.'),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: ElevatedButton(
                          onPressed: () async {
                            await prefs.setBool(key, true);
                            if (context.mounted) {
                              Navigator.of(context).pop();
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: theme.seedColor,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            elevation: 2,
                          ),
                          child: const Text(
                            'Bắt đầu học ngay',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
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

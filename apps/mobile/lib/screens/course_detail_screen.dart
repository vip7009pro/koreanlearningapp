import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../core/api_client.dart';
import '../providers/app_settings_provider.dart';

class CourseDetailScreen extends ConsumerStatefulWidget {
  final String courseId;
  const CourseDetailScreen({super.key, required this.courseId});

  @override
  ConsumerState<CourseDetailScreen> createState() => _CourseDetailScreenState();
}

class _CourseDetailScreenState extends ConsumerState<CourseDetailScreen> {
  Map<String, dynamic>? _course;
  List<dynamic> _sections = [];
  Map<String, dynamic>? _progress;
  Map<String, bool> _lessonCompleted = {};
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
      final courseRes = await api.getCourse(widget.courseId);
      final sectionsRes = await api.getSections(widget.courseId);
      final progressRes = await api.getCourseProgress(widget.courseId);
      final userProgressRes = await api.getUserProgress();
      final premiumRes = await api.checkPremiumStatus();

      final Map<String, bool> completedMap = {};
      final progressItems = (userProgressRes.data as List?) ?? [];
      for (final p in progressItems) {
        final m = p is Map ? p : null;
        final lessonId = m?['lessonId']?.toString();
        final completed = m?['completed'] == true;
        if (lessonId != null && lessonId.isNotEmpty) {
          completedMap[lessonId] = completed;
        }
      }

      if (mounted) {
        setState(() {
          _course = courseRes.data;
          _sections = sectionsRes.data ?? [];
          _progress = progressRes.data;
          _lessonCompleted = completedMap;
          _isPremiumUser = premiumRes.data?['isPremium'] ?? false;
          _loading = false;
        });
      }

      final isPremiumCourse = courseRes.data?['isPremium'] == true;
      if (mounted && isPremiumCourse && !_isPremiumUser) {
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

        if (!mounted) return;
        if (shouldUpgrade == true) {
          context.push('/subscription');
        }
        context.pop();
        return;
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _reloadProgress() async {
    final api = ref.read(apiClientProvider);
    try {
      final progressRes = await api.getCourseProgress(widget.courseId);
      final userProgressRes = await api.getUserProgress();

      final Map<String, bool> completedMap = {};
      final progressItems = (userProgressRes.data as List?) ?? [];
      for (final p in progressItems) {
        final m = p is Map ? p : null;
        final lessonId = m?['lessonId']?.toString();
        final completed = m?['completed'] == true;
        if (lessonId != null && lessonId.isNotEmpty) {
          completedMap[lessonId] = completed;
        }
      }

      if (!mounted) return;
      setState(() {
        _progress = progressRes.data;
        _lessonCompleted = completedMap;
      });
    } catch (_) {
      // ignore
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final themeId = ref.watch(appSettingsProvider).themeId;
    final theme = AppSettingsNotifier.themeById(themeId);

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 200,
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
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Text(
                          _course?['title'] ?? '',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _course?['description'] ?? '',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.8),
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 12),
                        if (_progress != null) ...[
                          ClipRRect(
                            borderRadius: BorderRadius.circular(6),
                            child: LinearProgressIndicator(
                              value: (_progress!['percentage'] ?? 0) / 100,
                              minHeight: 6,
                              backgroundColor:
                                  Colors.white.withValues(alpha: 0.3),
                              valueColor: const AlwaysStoppedAnimation(
                                Color(0xFF10B981),
                              ),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${_progress!['completedLessons']}/${_progress!['totalLessons']} bài · ${_progress!['percentage']}%',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.8),
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          SliverList(
            delegate: SliverChildBuilderDelegate((context, index) {
              final section = _sections[index];
              final lessons = section['lessons'] as List? ?? [];

              int sectionTotal = 0;
              int sectionCompleted = 0;
              for (final l in lessons) {
                final id = (l as dynamic)['id']?.toString() ?? '';
                if (id.isEmpty) continue;
                sectionTotal++;
                if (_lessonCompleted[id] == true) sectionCompleted++;
              }

              final sectionPct = sectionTotal == 0
                  ? 0.0
                  : (sectionCompleted / sectionTotal).clamp(0.0, 1.0);

              return Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          section['title'] ?? '',
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 8),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: LinearProgressIndicator(
                            value: sectionPct,
                            minHeight: 6,
                            backgroundColor: Theme.of(context)
                                .colorScheme
                                .primary
                                .withValues(alpha: 0.12),
                            valueColor: AlwaysStoppedAnimation(
                              Theme.of(context).colorScheme.primary,
                            ),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '$sectionCompleted/$sectionTotal bài trong section',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                          ),
                        ),
                        const SizedBox(height: 12),
                        ...lessons.map<Widget>(
                          (lesson) => InkWell(
                            onTap: () async {
                              await context.push('/lesson/${lesson['id']}');
                              await _reloadProgress();
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                vertical: 12,
                                horizontal: 8,
                              ),
                              decoration: BoxDecoration(
                                border: Border(
                                  bottom: BorderSide(
                                    color: Colors.grey.shade100,
                                  ),
                                ),
                              ),
                              child: Row(
                                children: [
                                  if (_lessonCompleted[(lesson['id'] ?? '').toString()] == true)
                                    Container(
                                      width: 22,
                                      height: 22,
                                      decoration: BoxDecoration(
                                        color: Theme.of(context)
                                            .colorScheme
                                            .primary
                                            .withValues(alpha: 0.12),
                                        shape: BoxShape.circle,
                                      ),
                                      child: Icon(
                                        Icons.check,
                                        size: 14,
                                        color: Theme.of(context).colorScheme.primary,
                                      ),
                                    )
                                  else
                                    const SizedBox(width: 22, height: 22),
                                  const SizedBox(width: 10),
                                  Container(
                                    width: 36,
                                    height: 36,
                                    decoration: BoxDecoration(
                                      color: theme.seedColor.withValues(alpha: 0.12),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Center(
                                      child: Text(
                                        '${(lesson['orderIndex'] ?? 0) + 1}',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: theme.seedColor,
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          lesson['title'] ?? '',
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w500,
                                            fontSize: 14,
                                          ),
                                        ),
                                        Text(
                                          '${lesson['estimatedMinutes'] ?? 10} phút',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.grey.shade500,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Icon(
                                    Icons.chevron_right,
                                    color: Colors.grey.shade400,
                                    size: 20,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }, childCount: _sections.length),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 20)),
        ],
      ),
    );
  }
}

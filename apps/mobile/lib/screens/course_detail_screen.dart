import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hive/hive.dart';
import '../core/api_client.dart';
import '../providers/app_settings_provider.dart';
import '../providers/auth_provider.dart';
import '../widgets/app_banner_ad.dart';

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
  bool _isDownloaded = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final api = ref.read(apiClientProvider);
    final box = Hive.box('offline_box');

    // Check download status first
    final downloadedList = (box.get('downloaded_courses') as List?)?.map((e) => e.toString()).toList() ?? [];
    final downloaded = downloadedList.contains(widget.courseId);

    try {
      final courseRes = await api.getCourse(widget.courseId);
      final sectionsRes = await api.getSections(widget.courseId);

      // If course details are updated online and it's marked downloaded, update the cache
      if (downloaded) {
        await box.put('course_${widget.courseId}', courseRes.data);
        await box.put('sections_${widget.courseId}', sectionsRes.data);
      }

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

      if (mounted) {
        setState(() {
          _course = courseRes.data;
          _sections = sectionsRes.data ?? [];
          _progress = progressRes.data;
          _lessonCompleted = completedMap;
          _isDownloaded = downloaded;
          _loading = false;
        });
      }
    } catch (_) {
      // Offline fallback
      final cachedCourse = box.get('course_${widget.courseId}');
      final cachedSections = box.get('sections_${widget.courseId}');
      if (cachedCourse != null && cachedSections != null) {
        if (mounted) {
          setState(() {
            _course = Map<String, dynamic>.from(cachedCourse);
            _sections = List<dynamic>.from(cachedSections);
            _progress = {
              'completedLessons': 0,
              'totalLessons': 0,
              'percentage': 0,
            };
            _lessonCompleted = {};
            _isDownloaded = true;
            _loading = false;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Đang hiển thị nội dung offline của khóa học 🌐'),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      } else {
        if (mounted) setState(() => _loading = false);
      }
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

  Future<void> _downloadCourseOffline() async {
    final user = ref.read(authProvider).user;
    final isPremium = user?['role'] == 'ADMIN' ||
        (user?['subscription'] != null &&
            user?['subscription']?['planType'] != 'FREE');

    if (!isPremium) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Tính năng Premium 👑'),
          content: const Text(
            'Tải bài học offline là tính năng dành riêng cho tài khoản Premium. Vui lòng nâng cấp để sử dụng.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Để sau'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(ctx);
                context.push('/subscription');
              },
              child: const Text('Đến Cửa Hàng'),
            ),
          ],
        ),
      );
      return;
    }

    // Show progress dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const AlertDialog(
        content: Row(
          children: [
            CircularProgressIndicator(),
            SizedBox(width: 20),
            Text('Đang tải bài học offline...'),
          ],
        ),
      ),
    );

    try {
      final api = ref.read(apiClientProvider);
      final box = Hive.box('offline_box');

      // Fetch and cache course details
      final courseRes = await api.getCourse(widget.courseId);
      await box.put('course_${widget.courseId}', courseRes.data);

      // Fetch and cache sections & lessons list
      final sectionsRes = await api.getSections(widget.courseId);
      await box.put('sections_${widget.courseId}', sectionsRes.data);

      // Fetch and cache each lesson
      final sectionsList = sectionsRes.data as List? ?? [];
      for (final section in sectionsList) {
        final lessons = section['lessons'] as List? ?? [];
        for (final lesson in lessons) {
          final lessonId = lesson['id']?.toString() ?? '';
          if (lessonId.isNotEmpty) {
            final lessonRes = await api.getLesson(lessonId);
            await box.put('lesson_$lessonId', lessonRes.data);
          }
        }
      }

      // Mark as downloaded
      final downloadedList = List<String>.from(box.get('downloaded_courses') as List? ?? []);
      if (!downloadedList.contains(widget.courseId)) {
        downloadedList.add(widget.courseId);
        await box.put('downloaded_courses', downloadedList);
      }

      if (mounted) {
        Navigator.pop(context); // Close progress dialog
        setState(() {
          _isDownloaded = true;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('🎉 Đã tải khóa học offline thành công!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context); // Close progress dialog
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Lỗi tải offline: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
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
            actions: [
              IconButton(
                tooltip: _isDownloaded ? 'Đã tải khóa học offline' : 'Tải khóa học offline',
                icon: Icon(
                  _isDownloaded ? Icons.cloud_done : Icons.cloud_download_outlined,
                  color: Colors.white,
                ),
                onPressed: _isDownloaded ? null : () => _downloadCourseOffline(),
              ),
            ],
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
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: AppBannerAd(),
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
                  child: ExpansionTile(
                    tilePadding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    childrenPadding:
                        const EdgeInsets.only(left: 8, right: 8, bottom: 8),
                    title: Row(
                      children: [
                        Icon(
                          Icons.menu_book_rounded,
                          size: 18,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            section['title'] ?? '',
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 16,
                            ),
                          ),
                        ),
                      ],
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
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
                      ],
                    ),
                    children: lessons.map<Widget>((lesson) {
                      return InkWell(
                        onTap: () async {
                          final router = GoRouter.of(context);
                          await router.push('/lesson/${lesson['id']}');
                          if (!mounted) return;
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
                              if (_lessonCompleted[
                                      (lesson['id'] ?? '').toString()] ==
                                  true)
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
                                    color:
                                        Theme.of(context).colorScheme.primary,
                                  ),
                                )
                              else
                                const SizedBox(width: 22, height: 22),
                              const SizedBox(width: 10),
                              Container(
                                width: 36,
                                height: 36,
                                decoration: BoxDecoration(
                                  color:
                                      theme.seedColor.withValues(alpha: 0.12),
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
                                  crossAxisAlignment: CrossAxisAlignment.start,
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
                      );
                    }).toList(),
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

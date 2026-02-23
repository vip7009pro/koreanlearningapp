import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/api_client.dart';
import '../providers/app_settings_provider.dart';

class TopikExamsScreen extends ConsumerStatefulWidget {
  const TopikExamsScreen({super.key});

  @override
  ConsumerState<TopikExamsScreen> createState() => _TopikExamsScreenState();
}

class _TopikExamsScreenState extends ConsumerState<TopikExamsScreen> {
  List<dynamic> _exams = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    final api = ref.read(apiClientProvider);
    try {
      final res = await api.getTopikExams();
      if (!mounted) return;
      setState(() {
        _exams = (res.data as List?) ?? [];
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Không tải được danh sách đề. Vui lòng thử lại.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(appSettingsProvider);
    final palette = AppSettingsNotifier.themeById(settings.themeId);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Luyện đề TOPIK'),
        foregroundColor: Colors.white,
        backgroundColor: Colors.transparent,
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: palette.gradient),
          ),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.error_outline,
                            size: 48, color: Colors.redAccent),
                        const SizedBox(height: 12),
                        Text(
                          _error!,
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: _load,
                          child: const Text('Thử lại'),
                        ),
                      ],
                    ),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _exams.length,
                    itemBuilder: (_, index) {
                      final exam = _exams[index] as Map<String, dynamic>;
                      final title = (exam['title'] ?? '').toString();
                      final topikLevel = (exam['topikLevel'] ?? '').toString();
                      final year = exam['year'];
                      final duration = exam['durationMinutes'];
                      final myStatus = (exam['myStatus'] ?? '').toString();
                      final myBest = exam['myBestScore'];

                      final tag = topikLevel == 'TOPIK_II'
                          ? 'TOPIK II'
                          : (topikLevel == 'TOPIK_I' ? 'TOPIK I' : 'TOPIK');

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Card(
                          child: InkWell(
                            onTap: () => context.push('/topik/exam/${exam['id']}'),
                            borderRadius: BorderRadius.circular(16),
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Row(
                                children: [
                                  Container(
                                    width: 56,
                                    height: 56,
                                    decoration: BoxDecoration(
                                      color: palette.seedColor
                                          .withValues(alpha: 0.12),
                                      borderRadius: BorderRadius.circular(14),
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
                                          title.isNotEmpty ? title : 'Đề TOPIK',
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w700,
                                            fontSize: 15,
                                          ),
                                        ),
                                        const SizedBox(height: 6),
                                        Wrap(
                                          spacing: 8,
                                          runSpacing: 6,
                                          children: [
                                            _pill(tag),
                                            if (year != null) _pill('Năm $year'),
                                            if (duration != null)
                                              _pill('${duration}m'),
                                            if (myStatus.isNotEmpty)
                                              _pill(
                                                myStatus == 'IN_PROGRESS'
                                                    ? 'Đang làm'
                                                    : (myStatus == 'COMPLETED'
                                                        ? 'Đã làm'
                                                        : 'Chưa làm'),
                                              ),
                                            if (myBest != null) _pill('Best $myBest'),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                  Icon(Icons.chevron_right,
                                      color: Colors.grey.shade400),
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
    );
  }

  Widget _pill(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 11,
          color: Colors.grey.shade800,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/api_client.dart';
import '../providers/app_settings_provider.dart';

class TopikExamDetailScreen extends ConsumerStatefulWidget {
  final String examId;
  const TopikExamDetailScreen({super.key, required this.examId});

  @override
  ConsumerState<TopikExamDetailScreen> createState() => _TopikExamDetailScreenState();
}

class _TopikExamDetailScreenState extends ConsumerState<TopikExamDetailScreen> {
  Map<String, dynamic>? _exam;
  Map<String, dynamic>? _mySession;
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
      final res = await api.getTopikExamDetail(widget.examId);
      final data = res.data as Map<String, dynamic>;
      if (!mounted) return;
      setState(() {
        _exam = data['exam'] as Map<String, dynamic>?;
        _mySession = data['mySession'] as Map<String, dynamic>?;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Không tải được đề thi. Vui lòng thử lại.';
      });
    }
  }

  String _topikLabel(String? level) {
    if (level == 'TOPIK_I') return 'TOPIK I';
    if (level == 'TOPIK_II') return 'TOPIK II';
    return 'TOPIK';
  }

  List<Map<String, dynamic>> _sections() {
    final exam = _exam;
    if (exam == null) return [];
    final sections = (exam['sections'] as List?) ?? [];
    return sections.cast<Map>().map((e) => e.cast<String, dynamic>()).toList();
  }

  List<Map<String, dynamic>> _sectionsByTypes(Set<String> types) {
    return _sections().where((s) => types.contains((s['type'] ?? '').toString())).toList();
  }

  int _sumDuration(List<Map<String, dynamic>> sections) {
    var sum = 0;
    for (final s in sections) {
      final d = s['durationMinutes'];
      if (d is num) sum += d.toInt();
    }
    return sum;
  }

  int _sumMaxScore(List<Map<String, dynamic>> sections) {
    var sum = 0;
    for (final s in sections) {
      final m = s['maxScore'];
      if (m is num) sum += m.toInt();
    }
    return sum;
  }

  Future<void> _start() async {
    final api = ref.read(apiClientProvider);
    try {
      final session = await api.startTopikSession(widget.examId);
      if (!mounted) return;
      final id = (session.data['id'] ?? '').toString();
      if (id.isNotEmpty) {
        context.push('/topik/session/$id/take', extra: {
          'exam': _exam,
        });
      }
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Không thể bắt đầu bài thi.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(appSettingsProvider);
    final palette = AppSettingsNotifier.themeById(settings.themeId);

    final exam = _exam;
    final topikLevel = (exam?['topikLevel'] ?? '').toString();

    return Scaffold(
      appBar: AppBar(
        title: Text(exam != null ? (exam['title'] ?? 'Chi tiết đề thi') : 'Chi tiết đề thi'),
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
                        const Icon(Icons.error_outline, size: 48, color: Colors.redAccent),
                        const SizedBox(height: 12),
                        Text(_error!, textAlign: TextAlign.center),
                        const SizedBox(height: 16),
                        ElevatedButton(onPressed: _load, child: const Text('Thử lại')),
                      ],
                    ),
                  ),
                )
              : exam == null
                  ? const Center(child: Text('Không tìm thấy đề thi'))
                  : RefreshIndicator(
                      onRefresh: _load,
                      child: ListView(
                        padding: const EdgeInsets.all(16),
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                decoration: BoxDecoration(
                                  color: palette.seedColor.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text(
                                  _topikLabel(topikLevel),
                                  style: TextStyle(
                                    fontWeight: FontWeight.w700,
                                    color: palette.seedColor,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              if (exam['year'] != null)
                                Text(
                                  'Năm ${exam['year']}',
                                  style: TextStyle(color: Colors.grey.shade700),
                                ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          if (_mySession != null)
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.orange.withValues(alpha: 0.08),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: Colors.orange.withValues(alpha: 0.2),
                                ),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.play_circle_outline, color: Colors.orange),
                                  const SizedBox(width: 10),
                                  const Expanded(
                                    child: Text(
                                      'Bạn có bài thi đang làm dở. Nhấn “Bắt đầu” để tiếp tục.',
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          const SizedBox(height: 16),
                          if (topikLevel == 'TOPIK_II') ...[
                            _buildSessionCard(
                              title: 'Ca 1: Nghe + Viết',
                              subtitle: '60 phút Nghe, 50 phút Viết',
                              sections: _sectionsByTypes({'LISTENING', 'WRITING'}),
                            ),
                            const SizedBox(height: 12),
                            _buildSessionCard(
                              title: 'Ca 2: Đọc',
                              subtitle: '70 phút Đọc',
                              sections: _sectionsByTypes({'READING'}),
                            ),
                          ] else ...[
                            _buildSessionCard(
                              title: 'Đề thi',
                              subtitle: 'Theo cấu trúc đề',
                              sections: _sections(),
                            ),
                          ],
                          const SizedBox(height: 18),
                          SizedBox(
                            height: 48,
                            child: ElevatedButton.icon(
                              onPressed: _start,
                              icon: const Icon(Icons.play_arrow),
                              label: const Text('Bắt đầu'),
                            ),
                          ),
                        ],
                      ),
                    ),
    );
  }

  Widget _buildSessionCard({
    required String title,
    required String subtitle,
    required List<Map<String, dynamic>> sections,
  }) {
    final duration = _sumDuration(sections);
    final maxScore = _sumMaxScore(sections);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                  ),
                ),
                if (duration > 0)
                  Text(
                    '$duration m',
                    style: TextStyle(color: Colors.grey.shade700, fontWeight: FontWeight.w600),
                  ),
              ],
            ),
            const SizedBox(height: 6),
            Text(subtitle, style: TextStyle(color: Colors.grey.shade700)),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (maxScore > 0)
                  _pill('$maxScore điểm'),
                ...sections.map((s) {
                  final type = (s['type'] ?? '').toString();
                  final d = s['durationMinutes'];
                  final m = s['maxScore'];
                  final parts = <String>[];
                  if (d is num) parts.add('${d.toInt()}m');
                  if (m is num) parts.add('${m.toInt()}đ');
                  final suffix = parts.isEmpty ? '' : ' · ${parts.join(' · ')}';
                  return _pill('$type$suffix');
                }),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _pill(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: TextStyle(fontSize: 12, color: Colors.grey.shade800, fontWeight: FontWeight.w600),
      ),
    );
  }
}

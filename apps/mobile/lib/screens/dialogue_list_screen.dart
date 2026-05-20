import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import '../core/api_client.dart';
import '../widgets/app_banner_ad.dart';

class DialogueListScreen extends ConsumerStatefulWidget {
  const DialogueListScreen({super.key});

  @override
  ConsumerState<DialogueListScreen> createState() => _DialogueListScreenState();
}

class _DialogueListScreenState extends ConsumerState<DialogueListScreen> {
  bool _isLoading = true;
  String? _error;
  List<dynamic> _scenarios = [];
  bool _isCreatingSession = false;

  @override
  void initState() {
    super.initState();
    _loadScenarios();
  }

  Future<void> _loadScenarios() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final api = ref.read(apiClientProvider);
      final res = await api.getDialogueScenarios();
      if (!mounted) return;
      setState(() {
        _scenarios = res.data as List<dynamic>;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Không thể tải danh sách kịch bản. Vui lòng kiểm tra kết nối mạng.';
        _isLoading = false;
      });
    }
  }

  Future<void> _startSession(String scenarioId) async {
    setState(() => _isCreatingSession = true);
    try {
      final api = ref.read(apiClientProvider);
      final res = await api.createDialogueSession(scenarioId);
      final session = res.data;
      final sessionId = session['id'] as String;

      if (!mounted) return;
      context.push('/dialogues/practice/$sessionId');
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Không thể tạo phòng trò chuyện: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => _isCreatingSession = false);
      }
    }
  }

  Color _getDifficultyColor(String diff) {
    switch (diff.toUpperCase()) {
      case 'EASY':
        return const Color(0xFF10B981); // Emerald Green
      case 'MEDIUM':
        return const Color(0xFFF59E0B); // Amber/Orange
      case 'HARD':
        return const Color(0xFFEF4444); // Rose Red
      default:
        return Colors.blueAccent;
    }
  }

  String _getDifficultyText(String diff) {
    switch (diff.toUpperCase()) {
      case 'EASY':
        return 'Cơ bản';
      case 'MEDIUM':
        return 'Trung cấp';
      case 'HARD':
        return 'Nâng cao';
      default:
        return diff;
    }
  }

  IconData _getScenarioIcon(String title) {
    if (title.contains('phỏng vấn') || title.contains('việc')) {
      return Icons.business_center;
    } else if (title.contains('món') || title.contains('quán') || title.contains('nhà hàng')) {
      return Icons.restaurant;
    } else if (title.contains('đường') || title.contains('ga') || title.contains('tàu')) {
      return Icons.map;
    }
    return Icons.chat_bubble;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F0F1A),
      body: Stack(
        children: [
          // Background decorations
          Positioned(
            top: -80,
            left: -80,
            child: Container(
              width: 250,
              height: 250,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF6366F1).withValues(alpha: 0.15),
                    blurRadius: 80,
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            bottom: -50,
            right: -50,
            child: Container(
              width: 200,
              height: 200,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF8B5CF6).withValues(alpha: 0.1),
                    blurRadius: 70,
                  ),
                ],
              ),
            ),
          ),
          SafeArea(
            child: CustomScrollView(
              slivers: [
                SliverAppBar(
                  backgroundColor: Colors.transparent,
                  elevation: 0,
                  leading: IconButton(
                    icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
                    onPressed: () => Navigator.pop(context),
                  ),
                  title: Text(
                    'Luyện Hội Thoại AI',
                    style: GoogleFonts.outfit(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  centerTitle: true,
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 10.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Chọn Chủ Đề Vai Diễn',
                          style: GoogleFonts.outfit(
                            color: Colors.white,
                            fontSize: 28,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Nhập vai đàm thoại cùng AI để nâng cao phát âm phản xạ, nhận chỉnh sửa cách dùng từ tự nhiên tức thì.',
                          style: GoogleFonts.outfit(
                            color: const Color(0xFF94A3B8),
                            fontSize: 14,
                            height: 1.5,
                          ),
                        ),
                        const SizedBox(height: 20),
                      ],
                    ),
                  ),
                ),
                if (_isLoading)
                  const SliverFillRemaining(
                    child: Center(
                      child: CircularProgressIndicator(color: Color(0xFF6366F1)),
                    ),
                  )
                else if (_error != null)
                  SliverFillRemaining(
                    child: Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24.0),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.error_outline, size: 48, color: Colors.redAccent),
                            const SizedBox(height: 16),
                            Text(
                              _error!,
                              textAlign: TextAlign.center,
                              style: GoogleFonts.outfit(color: Colors.white70, fontSize: 15),
                            ),
                            const SizedBox(height: 20),
                            ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF6366F1),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                              onPressed: _loadScenarios,
                              child: const Text('Thử lại'),
                            ),
                          ],
                        ),
                      ),
                    ),
                  )
                else
                  SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        if (index == _scenarios.length) {
                          return const Padding(
                            padding: EdgeInsets.symmetric(vertical: 20),
                            child: AppBannerAd(),
                          );
                        }
                        final s = _scenarios[index];
                        final id = s['id'] as String;
                        final title = s['title'] as String;
                        final desc = s['description'] as String;
                        final difficulty = s['difficulty'] as String;
                        final diffColor = _getDifficultyColor(difficulty);

                        return Container(
                          margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFF161624), Color(0xFF1E1E2F)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: const Color(0xFF334155).withValues(alpha: 0.5),
                              width: 1,
                            ),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(20.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF6366F1).withValues(alpha: 0.15),
                                        shape: BoxShape.circle,
                                      ),
                                      child: Icon(
                                        _getScenarioIcon(title),
                                        color: const Color(0xFF818CF8),
                                        size: 24,
                                      ),
                                    ),
                                    const SizedBox(width: 16),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            title,
                                            style: GoogleFonts.outfit(
                                              color: Colors.white,
                                              fontSize: 18,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                          const SizedBox(height: 6),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                            decoration: BoxDecoration(
                                              color: diffColor.withValues(alpha: 0.15),
                                              borderRadius: BorderRadius.circular(8),
                                              border: Border.all(color: diffColor.withValues(alpha: 0.3), width: 1),
                                            ),
                                            child: Text(
                                              _getDifficultyText(difficulty),
                                              style: GoogleFonts.outfit(
                                                color: diffColor,
                                                fontSize: 11,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  desc,
                                  style: GoogleFonts.outfit(
                                    color: const Color(0xFF94A3B8),
                                    fontSize: 14,
                                    height: 1.4,
                                  ),
                                ),
                                const SizedBox(height: 20),
                                SizedBox(
                                  width: double.infinity,
                                  height: 48,
                                  child: ElevatedButton(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFF6366F1),
                                      foregroundColor: Colors.white,
                                      elevation: 0,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                    ),
                                    onPressed: _isCreatingSession ? null : () => _startSession(id),
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        const Icon(Icons.record_voice_over, size: 18),
                                        const SizedBox(width: 8),
                                        Text(
                                          'Bắt Đầu Luyện Nói',
                                          style: GoogleFonts.outfit(
                                            fontSize: 15,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                      childCount: _scenarios.length + 1,
                    ),
                  ),
              ],
            ),
          ),
          if (_isCreatingSession)
            Container(
              color: Colors.black54,
              child: const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(color: Color(0xFF6366F1)),
                    SizedBox(height: 16),
                    Text(
                      'Đang khởi tạo phòng hội thoại...',
                      style: TextStyle(color: Colors.white, decoration: TextDecoration.none, fontSize: 15),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

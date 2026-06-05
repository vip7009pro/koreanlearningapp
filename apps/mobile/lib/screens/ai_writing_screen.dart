import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../core/ads_manager.dart';
import '../core/api_client.dart';
import '../providers/auth_provider.dart';
import '../widgets/app_banner_ad.dart';

const List<Map<String, String>> _defaultTopics = [
  {
    'title': '🎤 Tự giới thiệu',
    'prompt':
        'Hãy giới thiệu bản thân bằng tiếng Hàn (tên, tuổi, quê quán, sở thích).'
  },
  {
    'title': '🏠 Gia đình',
    'prompt': 'Viết một đoạn văn ngắn giới thiệu gia đình bạn bằng tiếng Hàn.'
  },
  {
    'title': '🍜 Đồ ăn yêu thích',
    'prompt':
        'Viết về món ăn yêu thích của bạn bằng tiếng Hàn. Tại sao bạn thích nó?'
  },
  {
    'title': '📅 Kế hoạch cuối tuần',
    'prompt': 'Viết về kế hoạch cuối tuần này của bạn bằng tiếng Hàn.'
  },
  {
    'title': '✈️ Du lịch',
    'prompt':
        'Kể về một chuyến du lịch đáng nhớ hoặc nơi bạn muốn đến bằng tiếng Hàn.'
  },
  {
    'title': '🏫 Trường học',
    'prompt':
        'Viết về cuộc sống học đường hoặc công việc hằng ngày bằng tiếng Hàn.'
  },
  {
    'title': '🌤️ Thời tiết',
    'prompt': 'Mô tả thời tiết hôm nay và hoạt động phù hợp bằng tiếng Hàn.'
  },
  {
    'title': '🎵 Âm nhạc K-POP',
    'prompt':
        'Viết về ca sĩ hoặc bài hát Hàn Quốc mà bạn yêu thích bằng tiếng Hàn.'
  },
  {
    'title': '🛍️ Mua sắm',
    'prompt': 'Viết một đoạn hội thoại hoặc tình huống mua sắm bằng tiếng Hàn.'
  },
  {
    'title': '🎬 Phim Hàn',
    'prompt':
        'Kể về bộ phim hoặc drama Hàn Quốc yêu thích của bạn bằng tiếng Hàn.'
  },
];

class AiWritingScreen extends ConsumerStatefulWidget {
  const AiWritingScreen({super.key});

  @override
  ConsumerState<AiWritingScreen> createState() => _AiWritingScreenState();
}

class _AiWritingScreenState extends ConsumerState<AiWritingScreen> {
  // Scroll Controllers
  final ScrollController _freeScrollController = ScrollController();
  final ScrollController _topikScrollController = ScrollController();

  // Tab 1 (Free) States
  final TextEditingController _controller = TextEditingController();
  final TextEditingController _customTopicCtrl = TextEditingController();
  bool _isLoading = false;
  Map<String, dynamic>? _result;
  int _selectedTopicIndex = 0;
  bool _isCustomTopic = false;
  String _selectedProvider = 'google';

  // Tab 2 (TOPIK) States
  String _selectedTopikType = '51';
  final TextEditingController _topikAnswerCtrl = TextEditingController();
  final TextEditingController _topikPromptCtrl = TextEditingController();
  final TextEditingController _topikAnswer1Ctrl = TextEditingController();
  final TextEditingController _topikAnswer2Ctrl = TextEditingController();
  String? _generatedQuestion;
  String? _generatedInstructions;
  String? _generatedSampleAnswer;
  String? _generatedExplanation;
  bool _isGeneratingQuestion = false;
  bool _showTopikSampleAnswer = false;
  bool _isTopikLoading = false;
  Map<String, dynamic>? _topikResult;

  String get _activePrompt {
    if (_isCustomTopic) return _customTopicCtrl.text.trim();
    return _defaultTopics[_selectedTopicIndex]['prompt']!;
  }

  void _showOutOfTicketsDialog() {
    showDialog(
      context: context,
      builder: (ctx) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        final dialogBg = isDark ? const Color(0xFF1E1E2C) : Colors.white;
        final textColor = isDark ? Colors.white : Colors.black87;
        final subtitleColor = isDark ? Colors.white70 : Colors.black54;

        return AlertDialog(
          backgroundColor: dialogBg,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          titlePadding: const EdgeInsets.fromLTRB(24, 28, 24, 8),
          contentPadding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
          title: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.auto_awesome,
                color: Colors.amber,
                size: 48,
              ),
              const SizedBox(height: 16),
              Text(
                'Hết lượt chấm AI 🤖',
                textAlign: TextAlign.center,
                style: GoogleFonts.outfit(
                  color: textColor,
                  fontWeight: FontWeight.bold,
                  fontSize: 22,
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Bạn đã sử dụng hết lượt chấm điểm AI miễn phí. Hãy mua thêm vé chấm điểm hoặc đăng ký Premium để tiếp tục học tập không giới hạn.',
                textAlign: TextAlign.center,
                style: GoogleFonts.outfit(
                  color: subtitleColor,
                  fontSize: 15,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 24),
              // Button stack
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF10B981), // Emerald green
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  icon: const Icon(Icons.video_library, size: 18),
                  label: Text(
                    'Xem QC nhận 1 lượt',
                    style: GoogleFonts.outfit(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  onPressed: () {
                    Navigator.pop(ctx);
                    _watchRewardAd();
                  },
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF6366F1), // Indigo
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  icon: const Icon(Icons.shopping_bag, size: 18),
                  label: Text(
                    'Đến Cửa Hàng',
                    style: GoogleFonts.outfit(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  onPressed: () {
                    Navigator.pop(ctx);
                    context.push('/store');
                  },
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                height: 44,
                child: TextButton(
                  style: TextButton.styleFrom(
                    foregroundColor: isDark ? Colors.white54 : Colors.black45,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  onPressed: () => Navigator.pop(ctx),
                  child: Text(
                    'Để sau',
                    style: GoogleFonts.outfit(
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _watchRewardAd() async {
    final ads = ref.read(adsManagerProvider);
    await ads.showRewardedAdWithLoadingDialog(
      context: context,
      onRewardEarned: () async {
        setState(() => _isLoading = true);
        try {
          final api = ref.read(apiClientProvider);
          final res = await api.claimRewardAdTicket();
          if (res.data['success'] == true) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('🎉 Nhận thành công 1 vé chấm AI miễn phí!'),
                  backgroundColor: Colors.green,
                ),
              );
            }
            await ref.read(authProvider.notifier).refreshProfile();
          }
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Lỗi nhận vé: $e')),
            );
          }
        } finally {
          if (mounted) setState(() => _isLoading = false);
        }
      },
    );
  }

  Future<void> _submitText() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    if (_activePrompt.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vui lòng nhập chủ đề viết')),
      );
      return;
    }

    final user = ref.read(authProvider).user;
    final hasUnlimitedAi = user?['role'] == 'ADMIN' ||
        (user?['subscription'] != null &&
            user?['subscription']?['planType'] == 'PREMIUM');
    final currentTickets = user?['aiTicketsBalance'] ?? 0;

    if (!hasUnlimitedAi && currentTickets <= 0) {
      _showOutOfTicketsDialog();
      return;
    }

    setState(() {
      _isLoading = true;
      _result = null;
    });

    try {
      final api = ref.read(apiClientProvider);
      final res = await api.correctWriting(
        _activePrompt,
        text,
        provider: _selectedProvider,
      );
      if (mounted) {
        setState(() {
          _result = res.data;
        });
        ref.read(authProvider.notifier).refreshProfile();

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('🎉 AI đã hoàn thành chấm điểm!'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 3),
          ),
        );

        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (_freeScrollController.hasClients) {
            _freeScrollController.animateTo(
              _freeScrollController.position.maxScrollExtent,
              duration: const Duration(milliseconds: 800),
              curve: Curves.easeInOut,
            );
          }
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi kết nối AI: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _generateTopikQuestion() async {
    setState(() {
      _isGeneratingQuestion = true;
      _generatedQuestion = null;
      _generatedInstructions = null;
      _generatedSampleAnswer = null;
      _generatedExplanation = null;
      _showTopikSampleAnswer = false;
      _topikResult = null;
      _topikAnswer1Ctrl.clear();
      _topikAnswer2Ctrl.clear();
      _topikAnswerCtrl.clear();
    });
    try {
      final api = ref.read(apiClientProvider);
      final res = await api.generateWritingQuestion(_selectedTopikType);
      if (res.data['success'] == true) {
        final data = res.data;
        setState(() {
          _generatedQuestion = data['question'];
          _generatedInstructions = data['instructions'];
          _generatedSampleAnswer = data['sampleAnswer'];
          _generatedExplanation = data['explanation'];
          _topikPromptCtrl.text = data['question'] ?? '';
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi tạo đề bài: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isGeneratingQuestion = false;
        });
      }
    }
  }

  Future<void> _submitTopikText() async {
    final prompt = _topikPromptCtrl.text.trim();
    if (prompt.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vui lòng nhập đề bài hoặc tạo đề mẫu')),
      );
      return;
    }

    String text = '';
    if (_selectedTopikType == '51' || _selectedTopikType == '52') {
      final t1 = _topikAnswer1Ctrl.text.trim();
      final t2 = _topikAnswer2Ctrl.text.trim();
      if (t1.isEmpty || t2.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Vui lòng nhập cả hai đáp án ㉠ và ㉡')),
        );
        return;
      }
      text = '㉠: $t1\n㉡: $t2';
    } else {
      text = _topikAnswerCtrl.text.trim();
      if (text.isEmpty) return;
    }

    final user = ref.read(authProvider).user;
    final hasUnlimitedAi = user?['role'] == 'ADMIN' ||
        (user?['subscription'] != null &&
            user?['subscription']?['planType'] == 'PREMIUM');
    final currentTickets = user?['aiTicketsBalance'] ?? 0;

    if (!hasUnlimitedAi && currentTickets <= 0) {
      _showOutOfTicketsDialog();
      return;
    }

    setState(() {
      _isTopikLoading = true;
      _topikResult = null;
    });

    try {
      final api = ref.read(apiClientProvider);
      final formattedPrompt = 'Câu $_selectedTopikType: $prompt';
      
      final res = await api.correctWriting(
        formattedPrompt,
        text,
        provider: _selectedProvider,
        questionType: _selectedTopikType,
        sampleAnswer: _generatedSampleAnswer,
        explanation: _generatedExplanation,
      );
      if (mounted) {
        setState(() {
          _topikResult = res.data;
        });
        ref.read(authProvider.notifier).refreshProfile();

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('🎉 Giám khảo AI đã hoàn thành chấm điểm!'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 3),
          ),
        );

        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (_topikScrollController.hasClients) {
            _topikScrollController.animateTo(
              _topikScrollController.position.maxScrollExtent,
              duration: const Duration(milliseconds: 800),
              curve: Curves.easeInOut,
            );
          }
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi kết nối AI: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isTopikLoading = false);
    }
  }

  @override
  void dispose() {
    _freeScrollController.dispose();
    _topikScrollController.dispose();
    _controller.dispose();
    _customTopicCtrl.dispose();
    _topikAnswerCtrl.dispose();
    _topikPromptCtrl.dispose();
    _topikAnswer1Ctrl.dispose();
    _topikAnswer2Ctrl.dispose();
    super.dispose();
  }

  Widget _buildTopikScaffoldCard(String type) {
    String title = '';
    String instructions = '';
    switch (type) {
      case '51':
        title = 'Câu 51 - Điền vào đoạn văn thực tế (Tối đa 10đ)';
        instructions =
            '• Thường là email, thông báo, tin nhắn nhờ vả/xin lỗi/cảm ơn.\n• Cần điền vào 2 chỗ trống (㉠) và (㉡).\n• BẮT BUỘC dùng đuôi câu tôn kính: -(스)ㅂ니다 / -(스)ㅂ니까? / -(으)십시오.\n• Chỉ cần nhập đáp án điền vào chỗ trống ㉠ và ㉡ tương ứng dưới đây, KHÔNG cần chép lại toàn bộ văn bản.';
        break;
      case '52':
        title = 'Câu 52 - Điền vào đoạn văn giải thích (Tối đa 10đ)';
        instructions =
            '• Đoạn văn giải thích kiến thức khoa học, định nghĩa đời sống, hiện tượng tâm lý.\n• Cần điền vào 2 chỗ trống (㉠) và (㉡).\n• BẮT BUỘC dùng đuôi văn viết: -ㄴ/는다, -다, -(이)다.\n• Chỉ cần nhập đáp án điền vào chỗ trống ㉠ và ㉡ tương ứng dưới đây, KHÔNG cần chép lại toàn bộ văn bản.';
        break;
      case '53':
        title = 'Câu 53 - Viết phân tích biểu đồ (Tối đa 30đ)';
        instructions =
            '• Phân tích số liệu biểu đồ cột/tròn, nêu nguyên nhân, triển vọng.\n• Độ dài yêu cầu: 200 - 300 chữ.\n• BẮT BUỘC dùng đuôi văn viết: -ㄴ/는다. Tuyệt đối KHÔNG viết số liệu thành chữ chữ số hay tự ý chèn quan điểm cá nhân.';
        break;
      case '54':
        title = 'Câu 54 - Viết nghị luận xã hội (Tối đa 50đ)';
        instructions =
            '• Bày tỏ quan điểm về một hiện tượng xã hội thông qua 3 câu hỏi gợi ý.\n• Độ dài yêu cầu: 600 - 700 chữ.\n• BẮT BUỘC dùng đuôi văn viết: -ㄴ/는다. Nên chia làm 3-4 đoạn văn chuẩn mực, dùng liên từ và từ vựng Hán Hàn cao cấp.';
        break;
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? Colors.grey.shade900 : Colors.indigo.shade50.withValues(alpha: 0.5);

    return Card(
      color: cardBg,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.indigo.withValues(alpha: 0.15)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: GoogleFonts.outfit(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.indigo.shade700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              instructions,
              style: const TextStyle(fontSize: 13, height: 1.45),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFreeWritingTab() {
    final user = ref.watch(authProvider).user;
    final hasUnlimitedAi = user?['role'] == 'ADMIN' ||
        (user?['subscription'] != null &&
            user?['subscription']?['planType'] == 'PREMIUM');
    final currentTickets = user?['aiTicketsBalance'] ?? 0;

    return SingleChildScrollView(
      controller: _freeScrollController,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Topic selector
          const Text('Chọn chủ đề viết',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          SizedBox(
            height: 44,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                ..._defaultTopics.asMap().entries.map((e) {
                  final isSelected =
                      !_isCustomTopic && _selectedTopicIndex == e.key;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(e.value['title']!,
                          style: const TextStyle(fontSize: 13)),
                      selected: isSelected,
                      selectedColor: Theme.of(context)
                          .colorScheme
                          .primary
                          .withValues(alpha: 0.2),
                      onSelected: (_) => setState(() {
                        _selectedTopicIndex = e.key;
                        _isCustomTopic = false;
                      }),
                    ),
                  );
                }),
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    avatar: const Icon(Icons.edit, size: 16),
                    label: const Text('Tùy chỉnh',
                        style: TextStyle(fontSize: 13)),
                    selected: _isCustomTopic,
                    selectedColor: Colors.orange.withValues(alpha: 0.2),
                    onSelected: (_) => setState(() => _isCustomTopic = true),
                  ),
                ),
              ],
            ),
          ),
          if (ref.watch(authProvider).user?['role'] == 'ADMIN') ...[
            const SizedBox(height: 12),
            const Text(
              'Chọn provider AI',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ChoiceChip(
                  label: const Text('Google ưu tiên'),
                  selected: _selectedProvider == 'google',
                  onSelected: (_) =>
                      setState(() => _selectedProvider = 'google'),
                ),
                ChoiceChip(
                  label: const Text('OpenRouter ưu tiên'),
                  selected: _selectedProvider == 'openrouter',
                  onSelected: (_) =>
                      setState(() => _selectedProvider = 'openrouter'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              _selectedProvider == 'google'
                  ? 'Google sẽ được thử trước, nếu lỗi hệ thống sẽ tự fallback sang OpenRouter.'
                  : 'OpenRouter sẽ được thử trước, nếu lỗi hệ thống sẽ tự fallback sang Google.',
              style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
            ),
            const SizedBox(height: 16),
          ],

          // Display selected topic or custom input
          if (_isCustomTopic)
            TextField(
              controller: _customTopicCtrl,
              decoration: InputDecoration(
                hintText: 'Nhập chủ đề viết tùy chỉnh...',
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12)),
                prefixIcon: const Icon(Icons.edit_note),
              ),
              maxLines: 2,
            )
          else
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.blue.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.blue.withValues(alpha: 0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.edit_note, color: Colors.blue),
                      const SizedBox(width: 8),
                      Text(
                        _defaultTopics[_selectedTopicIndex]['title']!,
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, color: Colors.blue),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(_defaultTopics[_selectedTopicIndex]['prompt']!,
                      style: const TextStyle(fontSize: 15)),
                ],
              ),
            ),

          const SizedBox(height: 16),
          TextField(
            controller: _controller,
            maxLines: 6,
            decoration: InputDecoration(
              hintText: 'Nhập tiếng Hàn của bạn vào đây...',
              border:
                  OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
          if (!hasUnlimitedAi) ...[
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Số vé chấm AI của bạn: $currentTickets',
                  style: const TextStyle(fontWeight: FontWeight.w500),
                ),
                TextButton.icon(
                  icon: const Icon(Icons.add_shopping_cart, size: 16),
                  label: const Text('Mua thêm'),
                  onPressed: () => context.push('/store'),
                ),
              ],
            ),
          ],
          const SizedBox(height: 16),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: _isLoading ? null : _submitText,
            icon: _isLoading ? const SizedBox() : const Icon(Icons.send),
            label: _isLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : const Text('Gửi cho AI chấm điểm'),
          ),
          const SizedBox(height: 16),
          const AppBannerAd(),
          if (_result != null) ...[
            const SizedBox(height: 32),
            const Text('Kết quả phân tích 📝',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _ScoreCircle(score: _result!['score'] ?? 0),
              ],
            ),
            const SizedBox(height: 16),
            Card(
              color: Colors.green.shade50,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.lightbulb, color: Colors.green),
                        SizedBox(width: 8),
                        Text('Nhận xét của AI',
                            style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.green)),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(_result!['feedback'] ?? '',
                        style: const TextStyle(color: Colors.black87)),
                  ],
                ),
              ),
            ),
            if (_result!['correctedText'] != null &&
                _result!['correctedText'] != _controller.text.trim()) ...[
              const SizedBox(height: 16),
              Card(
                color: Colors.blue.shade50,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.auto_fix_high, color: Colors.blue),
                          SizedBox(width: 8),
                          Text('Bài viết đã sửa',
                              style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.blue)),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(_result!['correctedText'] ?? '',
                          style: const TextStyle(fontSize: 15, color: Colors.black87)),
                    ],
                  ),
                ),
              ),
            ],
            const SizedBox(height: 16),
            if (_result!['errors'] != null &&
                (_result!['errors'] as List).isNotEmpty) ...[
              const Text('Lỗi cần chú ý',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              ...(_result!['errors'] as List).map((err) => Card(
                    child: ListTile(
                      leading:
                          const Icon(Icons.error_outline, color: Colors.red),
                      title: Text(
                          'Sửa: ${err['original']} ➡️ ${err['corrected']}',
                          style:
                              const TextStyle(fontWeight: FontWeight.w500)),
                      subtitle: Text(err['explanation'] ?? ''),
                    ),
                  ))
            ]
          ]
        ],
      ),
    );
  }

  Widget _buildTopikWritingTab() {
    final user = ref.watch(authProvider).user;
    final hasUnlimitedAi = user?['role'] == 'ADMIN' ||
        (user?['subscription'] != null &&
            user?['subscription']?['planType'] == 'PREMIUM');
    final currentTickets = user?['aiTicketsBalance'] ?? 0;
    final maxScore = _selectedTopikType == '51' || _selectedTopikType == '52' ? 10 : (_selectedTopikType == '53' ? 30 : 50);

    return SingleChildScrollView(
      controller: _topikScrollController,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Select Q51-54
          const Text('Chọn dạng đề thi TOPIK II',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: ['51', '52', '53', '54'].map((type) {
              final isSelected = _selectedTopikType == type;
              return ChoiceChip(
                label: Text('Câu $type', style: const TextStyle(fontWeight: FontWeight.bold)),
                selected: isSelected,
                selectedColor: Theme.of(context).colorScheme.primary.withValues(alpha: 0.2),
                onSelected: (_) {
                  setState(() {
                    _selectedTopikType = type;
                    _generatedQuestion = null;
                    _generatedInstructions = null;
                    _generatedSampleAnswer = null;
                    _generatedExplanation = null;
                    _showTopikSampleAnswer = false;
                    _topikPromptCtrl.clear();
                    _topikAnswerCtrl.clear();
                    _topikAnswer1Ctrl.clear();
                    _topikAnswer2Ctrl.clear();
                    _topikResult = null;
                  });
                },
              );
            }).toList(),
          ),
          const SizedBox(height: 16),
          _buildTopikScaffoldCard(_selectedTopikType),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
              backgroundColor: Colors.teal.shade700,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: _isGeneratingQuestion ? null : _generateTopikQuestion,
            icon: _isGeneratingQuestion
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : const Icon(Icons.psychology),
            label: const Text('🤖 Tạo đề bài ngẫu nhiên bằng AI'),
          ),

          if (_generatedQuestion != null) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.blue.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.blue.withValues(alpha: 0.2)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.assignment, color: Colors.blue),
                      const SizedBox(width: 8),
                      Text(
                        'Đề bài Câu $_selectedTopikType do AI thiết lập:',
                        style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blue),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  SelectableText(
                    _generatedQuestion!,
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500, height: 1.4),
                  ),
                  if (_generatedInstructions != null && _generatedInstructions!.isNotEmpty) ...[
                    const Divider(height: 24),
                    const Text('Hướng dẫn:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    const SizedBox(height: 4),
                    Text(_generatedInstructions!, style: TextStyle(color: Colors.grey.shade700, fontSize: 13)),
                  ],
                ],
              ),
            ),
          ],

          const SizedBox(height: 16),
          TextField(
            controller: _topikPromptCtrl,
            maxLines: 2,
            decoration: InputDecoration(
              labelText: 'Đề bài / Yêu cầu viết (Nhập tự do hoặc AI sinh tự động)',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
          const SizedBox(height: 16),
          if (_selectedTopikType == '51' || _selectedTopikType == '52') ...[
            TextField(
              controller: _topikAnswer1Ctrl,
              decoration: InputDecoration(
                labelText: 'Đáp án điền vào chỗ trống ㉠',
                hintText: 'Nhập cụm từ/câu thích hợp cho ㉠...',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                prefixIcon: const Icon(Icons.looks_one_outlined),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _topikAnswer2Ctrl,
              decoration: InputDecoration(
                labelText: 'Đáp án điền vào chỗ trống ㉡',
                hintText: 'Nhập cụm từ/câu thích hợp cho ㉡...',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                prefixIcon: const Icon(Icons.looks_two_outlined),
              ),
            ),
          ] else ...[
            TextField(
              controller: _topikAnswerCtrl,
              maxLines: 6,
              decoration: InputDecoration(
                hintText: 'Nhập bài viết bằng tiếng Hàn của bạn vào đây...',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],

          if (!hasUnlimitedAi) ...[
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Số vé chấm AI của bạn: $currentTickets',
                  style: const TextStyle(fontWeight: FontWeight.w500),
                ),
                TextButton.icon(
                  icon: const Icon(Icons.add_shopping_cart, size: 16),
                  label: const Text('Mua thêm'),
                  onPressed: () => context.push('/store'),
                ),
              ],
            ),
          ],

          const SizedBox(height: 16),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: _isTopikLoading ? null : _submitTopikText,
            icon: _isTopikLoading ? const SizedBox() : const Icon(Icons.gavel),
            label: _isTopikLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : const Text('Gửi bài cho AI chấm điểm'),
          ),

          const SizedBox(height: 16),
          const AppBannerAd(),

          if (_topikResult != null) ...[
            const SizedBox(height: 32),
            const Text('Kết quả phân tích từ Giám khảo AI 🎯',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _TopikScoreCircle(score: _topikResult!['score'] ?? 0, maxScore: maxScore),
              ],
            ),
            const SizedBox(height: 16),
            Card(
              color: Colors.green.shade50,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.lightbulb, color: Colors.green),
                        SizedBox(width: 8),
                        Text('Nhận xét của Giám khảo AI',
                            style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green)),
                      ],
                    ),
                    const SizedBox(height: 8),
                    MarkdownBody(
                      data: _topikResult!['feedback'] ?? '',
                      selectable: true,
                      styleSheet: MarkdownStyleSheet.fromTheme(Theme.of(context)).copyWith(
                        p: const TextStyle(color: Colors.black87),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (_topikResult!['correctedText'] != null) ...[
              const SizedBox(height: 16),
              Card(
                color: Colors.blue.shade50,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.auto_fix_high, color: Colors.blue),
                          SizedBox(width: 8),
                          Text('Bài viết gợi ý sửa đổi',
                              style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue)),
                        ],
                      ),
                      const SizedBox(height: 8),
                      MarkdownBody(
                        data: _topikResult!['correctedText'] ?? '',
                        selectable: true,
                        styleSheet: MarkdownStyleSheet.fromTheme(Theme.of(context)).copyWith(
                          p: const TextStyle(fontSize: 15, color: Colors.black87),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
            if (_topikResult!['sampleAnswer'] != null &&
                _topikResult!['sampleAnswer'].toString().trim().isNotEmpty) ...[
              const SizedBox(height: 16),
              Card(
                color: Colors.teal.shade50,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.check_circle_outline, color: Colors.teal),
                          SizedBox(width: 8),
                          Text('Đáp án mẫu đạt điểm tối đa',
                              style: TextStyle(fontWeight: FontWeight.bold, color: Colors.teal)),
                        ],
                      ),
                      const SizedBox(height: 8),
                      MarkdownBody(
                        data: _topikResult!['sampleAnswer'] ?? '',
                        selectable: true,
                        styleSheet: MarkdownStyleSheet.fromTheme(Theme.of(context)).copyWith(
                          p: const TextStyle(fontSize: 14, color: Colors.black87, fontWeight: FontWeight.w500),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
            if (_topikResult!['explanation'] != null &&
                _topikResult!['explanation'].toString().trim().isNotEmpty) ...[
              const SizedBox(height: 16),
              Card(
                color: Colors.amber.shade50,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.info_outline, color: Colors.amber),
                          SizedBox(width: 8),
                          Text('Giải nghĩa & Ngữ pháp cốt lõi',
                              style: TextStyle(fontWeight: FontWeight.bold, color: Colors.amber)),
                        ],
                      ),
                      const SizedBox(height: 8),
                      MarkdownBody(
                        data: _topikResult!['explanation'] ?? '',
                        selectable: true,
                        styleSheet: MarkdownStyleSheet.fromTheme(Theme.of(context)).copyWith(
                          p: const TextStyle(fontSize: 13, color: Colors.black87, height: 1.45),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
            const SizedBox(height: 16),
            if (_topikResult!['errors'] != null &&
                (_topikResult!['errors'] as List).isNotEmpty) ...[
              const Text('Lỗi cần chú ý',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              ...(_topikResult!['errors'] as List).map((err) => Card(
                    child: ListTile(
                      leading:
                          const Icon(Icons.error_outline, color: Colors.red),
                      title: Text(
                          'Sửa: ${err['original']} ➡️ ${err['corrected']}',
                          style:
                              const TextStyle(fontWeight: FontWeight.w500)),
                      subtitle: Text(err['explanation'] ?? ''),
                    ),
                  ))
            ]
          ],
          if (_generatedQuestion != null) ...[
            const SizedBox(height: 24),
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () {
                setState(() {
                  _showTopikSampleAnswer = !_showTopikSampleAnswer;
                });
              },
              icon: Icon(_showTopikSampleAnswer ? Icons.visibility_off : Icons.visibility),
              label: Text(_showTopikSampleAnswer ? 'Ẩn đáp án mẫu & Giải thích đề bài' : 'Xem đáp án mẫu & Giải thích đề bài'),
            ),
            if (_showTopikSampleAnswer) ...[
              const SizedBox(height: 12),
              if (_generatedSampleAnswer != null)
                Card(
                  color: Colors.green.shade50,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.check_circle_outline, color: Colors.green),
                            SizedBox(width: 8),
                            Text('Đáp án mẫu đạt điểm tối đa đề bài:',
                                style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green)),
                          ],
                        ),
                        const SizedBox(height: 8),
                        MarkdownBody(
                          data: _generatedSampleAnswer!,
                          selectable: true,
                          styleSheet: MarkdownStyleSheet.fromTheme(Theme.of(context)).copyWith(
                            p: const TextStyle(fontSize: 14, color: Colors.black87, fontWeight: FontWeight.w500),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              if (_generatedExplanation != null)
                Card(
                  color: Colors.amber.shade50,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.lightbulb_outline, color: Colors.amber),
                            SizedBox(width: 8),
                            Text('Giải nghĩa & Ngữ pháp cốt lõi đề bài:',
                                style: TextStyle(fontWeight: FontWeight.bold, color: Colors.amber)),
                          ],
                        ),
                        const SizedBox(height: 8),
                        MarkdownBody(
                          data: _generatedExplanation!,
                          selectable: true,
                          styleSheet: MarkdownStyleSheet.fromTheme(Theme.of(context)).copyWith(
                            p: const TextStyle(fontSize: 13, color: Colors.black87, height: 1.45),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Luyện Viết AI 🤖'),
          actions: [
            IconButton(
              tooltip: 'Lịch sử',
              icon: const Icon(Icons.history),
              onPressed: () => context.push('/writing-history'),
            ),
          ],
          bottom: TabBar(
            labelStyle: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 14),
            unselectedLabelStyle: GoogleFonts.outfit(fontWeight: FontWeight.normal, fontSize: 14),
            tabs: const [
              Tab(text: 'Viết tự do ✍️'),
              Tab(text: 'Luyện thi TOPIK II (Câu 51-54) 🎓'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _buildFreeWritingTab(),
            _buildTopikWritingTab(),
          ],
        ),
      ),
    );
  }
}

class _ScoreCircle extends StatelessWidget {
  final int score;
  const _ScoreCircle({required this.score});

  @override
  Widget build(BuildContext context) {
    Color color = Colors.green;
    if (score < 50) {
      color = Colors.red;
    } else if (score < 80) {
      color = Colors.orange;
    }

    return Stack(
      alignment: Alignment.center,
      children: [
        SizedBox(
          width: 80,
          height: 80,
          child: CircularProgressIndicator(
            value: score / 100,
            strokeWidth: 8,
            backgroundColor: color.withValues(alpha: 0.2),
            valueColor: AlwaysStoppedAnimation(color),
          ),
        ),
        Text('$score',
            style: TextStyle(
                fontSize: 24, fontWeight: FontWeight.bold, color: color)),
      ],
    );
  }
}

class _TopikScoreCircle extends StatelessWidget {
  final int score;
  final int maxScore;
  const _TopikScoreCircle({required this.score, required this.maxScore});

  @override
  Widget build(BuildContext context) {
    Color color = Colors.green;
    final ratio = score / maxScore;
    if (ratio < 0.5) {
      color = Colors.red;
    } else if (ratio < 0.8) {
      color = Colors.orange;
    }

    return Stack(
      alignment: Alignment.center,
      children: [
        SizedBox(
          width: 80,
          height: 80,
          child: CircularProgressIndicator(
            value: ratio.clamp(0.0, 1.0),
            strokeWidth: 8,
            backgroundColor: color.withValues(alpha: 0.2),
            valueColor: AlwaysStoppedAnimation(color),
          ),
        ),
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('$score',
                style: TextStyle(
                    fontSize: 22, fontWeight: FontWeight.bold, color: color)),
            Text('/$maxScore',
                style: TextStyle(
                    fontSize: 12, color: Colors.grey.shade600, fontWeight: FontWeight.w500)),
          ],
        ),
      ],
    );
  }
}

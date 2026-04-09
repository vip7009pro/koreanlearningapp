import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../core/api_client.dart';
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
  final TextEditingController _controller = TextEditingController();
  final TextEditingController _customTopicCtrl = TextEditingController();
  bool _isLoading = false;
  Map<String, dynamic>? _result;
  int _selectedTopicIndex = 0;
  bool _isCustomTopic = false;
  String _selectedProvider = 'google';

  String get _activePrompt {
    if (_isCustomTopic) return _customTopicCtrl.text.trim();
    return _defaultTopics[_selectedTopicIndex]['prompt']!;
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

  @override
  void dispose() {
    _controller.dispose();
    _customTopicCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Luyện Viết AI 🤖'),
        actions: [
          IconButton(
            tooltip: 'Lịch sử',
            icon: const Icon(Icons.history),
            onPressed: () => context.push('/writing-history'),
          ),
        ],
      ),
      body: SingleChildScrollView(
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
                      Text(_result!['feedback'] ?? ''),
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
                            style: const TextStyle(fontSize: 15)),
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

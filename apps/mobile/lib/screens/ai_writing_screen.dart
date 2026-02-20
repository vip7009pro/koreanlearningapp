import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/api_client.dart';

class AiWritingScreen extends ConsumerStatefulWidget {
  const AiWritingScreen({super.key});

  @override
  ConsumerState<AiWritingScreen> createState() => _AiWritingScreenState();
}

class _AiWritingScreenState extends ConsumerState<AiWritingScreen> {
  final TextEditingController _controller = TextEditingController();
  bool _isLoading = false;
  Map<String, dynamic>? _result;
  final String _prompt =
      'Hãy giới thiệu ngắn gọn về bản thân hoặc công việc của bạn bằng tiếng Hàn.';

  Future<void> _submitText() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;

    setState(() {
      _isLoading = true;
      _result = null;
    });

    try {
      final api = ref.read(apiClientProvider);
      final res = await api.correctWriting(_prompt, text);
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
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Luyện Viết AI 🤖')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
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
                  const Row(
                    children: [
                      Icon(Icons.edit_note, color: Colors.blue),
                      SizedBox(width: 8),
                      Text('Chủ đề viết',
                          style: TextStyle(
                              fontWeight: FontWeight.bold, color: Colors.blue)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(_prompt, style: const TextStyle(fontSize: 16)),
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
    if (score < 50)
      color = Colors.red;
    else if (score < 80) color = Colors.orange;

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

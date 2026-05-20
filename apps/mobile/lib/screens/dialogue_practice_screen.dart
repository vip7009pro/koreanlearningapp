import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:flutter_tts/flutter_tts.dart';
import '../core/api_client.dart';
import '../providers/auth_provider.dart';

class DialoguePracticeScreen extends ConsumerStatefulWidget {
  final String sessionId;
  const DialoguePracticeScreen({super.key, required this.sessionId});

  @override
  ConsumerState<DialoguePracticeScreen> createState() => _DialoguePracticeScreenState();
}

class _DialoguePracticeScreenState extends ConsumerState<DialoguePracticeScreen> {
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  
  final SpeechToText _speechToText = SpeechToText();
  final FlutterTts _flutterTts = FlutterTts();
  
  bool _isLoading = true;
  bool _isSending = false;
  String? _error;
  
  Map<String, dynamic>? _session;
  List<dynamic> _turns = [];
  
  bool _speechEnabled = false;
  bool _isListening = false;
  bool _isKeyboardMode = false;

  @override
  void initState() {
    super.initState();
    _loadHistory();
    _initSpeech();
    _initTts();
  }

  @override
  void dispose() {
    _flutterTts.stop();
    _speechToText.stop();
    _textController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadHistory() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final api = ref.read(apiClientProvider);
      final res = await api.getDialogueSessionHistory(widget.sessionId);
      if (!mounted) return;
      
      final sessionData = res.data as Map<String, dynamic>;
      setState(() {
        _session = sessionData;
        _turns = (sessionData['turns'] as List<dynamic>?) ?? [];
        _isLoading = false;
      });
      
      _scrollToBottom();
      
      // Auto-play the starter message if it is the only message
      if (_turns.length == 1 && _turns[0]['role'] == 'AI') {
        _speak(_turns[0]['content'] as String);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Không thể tải lịch sử trò chuyện.';
        _isLoading = false;
      });
    }
  }

  Future<void> _initSpeech() async {
    try {
      final available = await _speechToText.initialize(
        onStatus: (status) {
          debugPrint('Speech status: $status');
          if (status == 'done' || status == 'notListening') {
            setState(() => _isListening = false);
          }
        },
        onError: (error) {
          debugPrint('Speech error: $error');
          setState(() => _isListening = false);
        },
      );
      setState(() {
        _speechEnabled = available;
      });
    } catch (e) {
      debugPrint('Speech init failed: $e');
    }
  }

  void _initTts() {
    _flutterTts.setLanguage('ko-KR');
    _flutterTts.setSpeechRate(0.45);
    _flutterTts.setVolume(1.0);
  }

  Future<void> _speak(String text) async {
    await _flutterTts.stop();
    await _flutterTts.speak(text);
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _startListening() async {
    if (!_speechEnabled) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Không hỗ trợ Speech-to-Text trên thiết bị này.')),
      );
      return;
    }

    setState(() {
      _isListening = true;
    });

    await _speechToText.listen(
      localeId: 'ko-KR',
      onResult: (result) {
        setState(() {
          _textController.text = result.recognizedWords;
        });
      },
    );
  }

  Future<void> _stopListening() async {
    await _speechToText.stop();
    setState(() => _isListening = false);
  }

  Future<void> _sendTurn() async {
    final text = _textController.text.trim();
    if (text.isEmpty) return;

    _textController.clear();
    setState(() {
      _isSending = true;
      // Optimistically add user turn to local UI
      _turns.add({
        'role': 'USER',
        'content': text,
        'createdAt': DateTime.now().toIso8601String(),
      });
    });
    _scrollToBottom();

    try {
      final api = ref.read(apiClientProvider);
      final res = await api.submitDialogueTurn(widget.sessionId, text);
      final data = res.data;
      
      if (!mounted) return;
      setState(() {
        // Replace last item with actual evaluated user turn and add AI response
        _turns.removeLast();
        _turns.add(data['userTurn']);
        _turns.add(data['aiTurn']);
        _isSending = false;
      });

      _scrollToBottom();
      _speak(data['aiTurn']['content'] as String);
      
      // Update XP & Stats asynchronously
      ref.read(authProvider.notifier).refreshProfile();
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSending = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Lỗi gửi phản hồi: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final scenario = _session?['scenario'];
    final scenarioTitle = scenario?['title'] ?? 'Đàm thoại AI';

    return Scaffold(
      backgroundColor: const Color(0xFF0F0F1A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF161624),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          scenarioTitle,
          style: GoogleFonts.outfit(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF6366F1)))
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.error_outline, size: 48, color: Colors.redAccent),
                        const SizedBox(height: 16),
                        Text(
                          _error!,
                          style: GoogleFonts.outfit(color: Colors.white70, fontSize: 16),
                        ),
                        const SizedBox(height: 20),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF6366F1)),
                          onPressed: _loadHistory,
                          child: const Text('Tải lại'),
                        ),
                      ],
                    ),
                  ),
                )
              : Column(
                  children: [
                    Expanded(
                      child: ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
                        itemCount: _turns.length,
                        itemBuilder: (context, index) {
                          final turn = _turns[index];
                          final isUser = turn['role'] == 'USER';
                          return _buildChatBubble(turn, isUser);
                        },
                      ),
                    ),
                    if (_isSending)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 10.0),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF818CF8)),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'AI đang đánh giá & trả lời...',
                              style: GoogleFonts.outfit(color: Colors.white60, fontSize: 13),
                            ),
                          ],
                        ),
                      ),
                    _buildInputPanel(),
                  ],
                ),
    );
  }

  Widget _buildChatBubble(Map<String, dynamic> turn, bool isUser) {
    final content = turn['content'] as String;
    final grammarFeedback = turn['grammarFeedback'] as Map<dynamic, dynamic>?;
    final score = turn['pronunciationScore'] as int?;

    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: Column(
        crossAxisAlignment: isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (!isUser) ...[
                CircleAvatar(
                  backgroundColor: const Color(0xFF6366F1).withValues(alpha: 0.2),
                  child: const Icon(Icons.face_retouching_natural, color: Color(0xFF818CF8), size: 20),
                ),
                const SizedBox(width: 8),
              ],
              Flexible(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: isUser ? const Color(0xFF6366F1) : const Color(0xFF1E1E2F),
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(16),
                      topRight: const Radius.circular(16),
                      bottomLeft: isUser ? const Radius.circular(16) : const Radius.circular(0),
                      bottomRight: isUser ? const Radius.circular(0) : const Radius.circular(16),
                    ),
                    border: isUser
                        ? null
                        : Border.all(color: const Color(0xFF334155).withValues(alpha: 0.5), width: 1),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        content,
                        style: GoogleFonts.outfit(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      if (!isUser) ...[
                        const SizedBox(height: 4),
                        GestureDetector(
                          onTap: () => _speak(content),
                          child: const Padding(
                            padding: EdgeInsets.symmetric(vertical: 2.0),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.volume_up, size: 14, color: Color(0xFF818CF8)),
                                SizedBox(width: 4),
                                Text(
                                  'Nghe phát âm',
                                  style: TextStyle(color: Color(0xFF818CF8), fontSize: 11, fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ]
                    ],
                  ),
                ),
              ),
              if (isUser) ...[
                const SizedBox(width: 8),
                CircleAvatar(
                  backgroundColor: const Color(0xFF0D9488).withValues(alpha: 0.2),
                  child: const Icon(Icons.person, color: Color(0xFF14B8A6), size: 20),
                ),
              ],
            ],
          ),
          if (isUser && (score != null || grammarFeedback != null))
            Padding(
              padding: const EdgeInsets.only(top: 8.0, right: 48.0),
              child: _buildEvaluationPanel(score, grammarFeedback),
            ),
        ],
      ),
    );
  }

  Widget _buildEvaluationPanel(int? score, Map<dynamic, dynamic>? feedback) {
    final explanation = feedback?['explanation'] as String? ?? '';
    final suggestions = (feedback?['suggestions'] as List<dynamic>?) ?? [];

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF161624),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF334155).withValues(alpha: 0.3), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.analytics, size: 16, color: Color(0xFF14B8A6)),
              const SizedBox(width: 6),
              Text(
                'AI Shadowing Evaluation',
                style: GoogleFonts.outfit(color: const Color(0xFF14B8A6), fontSize: 12, fontWeight: FontWeight.bold),
              ),
              const Spacer(),
              if (score != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFF14B8A6).withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    '$score điểm',
                    style: GoogleFonts.outfit(color: const Color(0xFF2DD4BF), fontSize: 11, fontWeight: FontWeight.bold),
                  ),
                ),
            ],
          ),
          if (explanation.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              explanation,
              style: GoogleFonts.outfit(color: Colors.white70, fontSize: 13, height: 1.4),
            ),
          ],
          if (suggestions.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              'Gợi ý diễn đạt tự nhiên hơn:',
              style: GoogleFonts.outfit(color: const Color(0xFF818CF8), fontSize: 12, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            ...suggestions.map((s) => Padding(
                  padding: const EdgeInsets.only(bottom: 4.0),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('• ', style: TextStyle(color: Colors.white60)),
                      Expanded(
                        child: Text(
                          s.toString(),
                          style: GoogleFonts.outfit(color: Colors.white60, fontSize: 12, height: 1.4),
                        ),
                      ),
                    ],
                  ),
                )),
          ],
        ],
      ),
    );
  }

  Widget _buildInputPanel() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: const BoxDecoration(
        color: Color(0xFF161624),
        border: Border(top: BorderSide(color: Color(0xFF1E293B), width: 1)),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            IconButton(
              icon: Icon(
                _isKeyboardMode ? Icons.mic : Icons.keyboard,
                color: Colors.white54,
              ),
              onPressed: () {
                setState(() {
                  _isKeyboardMode = !_isKeyboardMode;
                  _stopListening();
                });
              },
            ),
            Expanded(
              child: _isKeyboardMode
                  ? Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFF0F0F1A),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFF334155), width: 1),
                      ),
                      child: TextField(
                        controller: _textController,
                        style: GoogleFonts.outfit(color: Colors.white, fontSize: 15),
                        decoration: InputDecoration(
                          hintText: 'Nhập câu trả lời bằng tiếng Hàn...',
                          hintStyle: GoogleFonts.outfit(color: Colors.white30, fontSize: 14),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                          border: InputBorder.none,
                        ),
                      ),
                    )
                  : GestureDetector(
                      onTap: _isListening ? _stopListening : _startListening,
                      child: Container(
                        height: 48,
                        decoration: BoxDecoration(
                          color: _isListening ? const Color(0xFFEF4444).withValues(alpha: 0.15) : const Color(0xFF6366F1).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: _isListening ? Colors.redAccent : const Color(0xFF6366F1).withValues(alpha: 0.3),
                            width: 1,
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              _isListening ? Icons.stop : Icons.mic,
                              color: _isListening ? Colors.redAccent : const Color(0xFF818CF8),
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              _isListening ? 'Đang nghe... Nhấn để dừng' : 'Nhấn để Nói tiếng Hàn',
                              style: GoogleFonts.outfit(
                                color: _isListening ? Colors.redAccent : const Color(0xFF818CF8),
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
            ),
            const SizedBox(width: 8),
            _isKeyboardMode
                ? IconButton(
                    icon: const Icon(Icons.send, color: Color(0xFF6366F1)),
                    onPressed: _sendTurn,
                  )
                : IconButton(
                    icon: const Icon(Icons.send, color: Color(0xFF6366F1)),
                    onPressed: _textController.text.isNotEmpty ? _sendTurn : null,
                  ),
          ],
        ),
      ),
    );
  }
}

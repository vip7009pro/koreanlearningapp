import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:dio/dio.dart';
import 'package:go_router/go_router.dart';
import '../core/api_client.dart';
import '../providers/auth_provider.dart';

class DialoguePracticeScreen extends ConsumerStatefulWidget {
  final String id;
  final bool isNew;
  const DialoguePracticeScreen({super.key, required this.id, required this.isNew});

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
  String? _sessionId;
  bool _isNew = false;
  bool _isAutoSubmit = true;
  
  Map<String, dynamic>? _session;
  Map<String, dynamic>? _scenario;
  List<dynamic> _turns = [];
  
  bool _speechEnabled = false;
  bool _isListening = false;
  bool _isKeyboardMode = false;

  @override
  void initState() {
    super.initState();
    _isNew = widget.isNew;
    if (_isNew) {
      _sessionId = null;
      _loadScenarioInfo();
    } else {
      _sessionId = widget.id;
      _loadHistory();
    }
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
      final res = await api.getDialogueSessionHistory(_sessionId!);
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

  Future<void> _loadScenarioInfo() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final api = ref.read(apiClientProvider);
      final res = await api.getDialogueScenarios();
      if (!mounted) return;
      
      final list = res.data as List<dynamic>;
      final scenario = list.firstWhere((s) => s['id'] == widget.id, orElse: () => null);
      
      setState(() {
        _scenario = scenario;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Không thể tải thông tin kịch bản.';
        _isLoading = false;
      });
    }
  }

  Future<void> _startPractice() async {
    final user = ref.read(authProvider).user;
    final isPremium = user?['role'] == 'ADMIN' ||
        (user?['subscription'] != null &&
            user?['subscription']?['planType'] != 'FREE');
    final currentTickets = user?['aiTicketsBalance'] ?? 0;

    if (!isPremium && currentTickets <= 0) {
      _showOutOfTicketsDialog();
      return;
    }

    setState(() {
      _isSending = true;
      _error = null;
    });

    try {
      final api = ref.read(apiClientProvider);
      final res = await api.createDialogueSession(widget.id);
      final sessionData = res.data as Map<String, dynamic>;
      
      if (!mounted) return;
      setState(() {
        _session = sessionData;
        _sessionId = sessionData['id'] as String;
        _turns = (sessionData['turns'] as List<dynamic>?) ?? [];
        _isNew = false;
        _isSending = false;
        _isLoading = false;
      });

      _scrollToBottom();

      // Auto-play the starter message
      if (_turns.isNotEmpty && _turns[0]['role'] == 'AI') {
        _speak(_turns[0]['content'] as String);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Không thể tạo phiên hội thoại mới: $e';
        _isSending = false;
      });
    }
  }

  Future<void> _confirmDeleteSession(BuildContext context, String sessionId, StateSetter setModalState, String scenarioId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF161624),
        title: Text(
          'Xóa lịch sử?',
          style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        content: Text(
          'Bạn có chắc chắn muốn xóa lượt hội thoại này? Hành động này không thể hoàn tác.',
          style: GoogleFonts.outfit(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Hủy', style: GoogleFonts.outfit(color: Colors.white54)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('Xóa', style: GoogleFonts.outfit(color: Colors.redAccent, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        final api = ref.read(apiClientProvider);
        await api.deleteDialogueSession(sessionId);
        
        if (_sessionId == sessionId) {
          setState(() {
            _sessionId = null;
            _session = null;
            _turns = [];
            _isNew = true;
          });
          _loadScenarioInfo();
        }
        
        setModalState(() {});
        
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Đã xóa lượt hội thoại.')),
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Lỗi khi xóa: $e')),
          );
        }
      }
    }
  }

  Color _getDifficultyColor(String diff) {
    switch (diff.toUpperCase()) {
      case 'EASY':
        return const Color(0xFF10B981);
      case 'MEDIUM':
        return const Color(0xFFF59E0B);
      case 'HARD':
        return const Color(0xFFEF4444);
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
    final t = title.toLowerCase();
    if (t.contains('phỏng vấn') || t.contains('việc')) {
      return Icons.business_center;
    } else if (t.contains('món') || t.contains('quán') || t.contains('nhà hàng')) {
      return Icons.restaurant;
    } else if (t.contains('đường') || t.contains('ga') || t.contains('tàu')) {
      return Icons.map;
    }
    return Icons.chat_bubble;
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
      _textController.clear();
    });

    await _speechToText.listen(
      listenOptions: SpeechListenOptions(
        localeId: 'ko-KR',
        pauseFor: const Duration(seconds: 4),
        listenFor: const Duration(seconds: 30),
      ),
      onResult: (result) {
        setState(() {
          _textController.text = result.recognizedWords;
        });
        
        // Auto-send when final result is received if auto-submit is enabled
        if (_isAutoSubmit && result.finalResult) {
          final recognizedText = result.recognizedWords.trim();
          if (recognizedText.isNotEmpty && !_isSending) {
            _sendTurn();
          }
        }
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

    final user = ref.read(authProvider).user;
    final isPremium = user?['role'] == 'ADMIN' ||
        (user?['subscription'] != null &&
            user?['subscription']?['planType'] != 'FREE');
    final currentTickets = user?['aiTicketsBalance'] ?? 0;

    if (!isPremium && currentTickets <= 0) {
      _showOutOfTicketsDialog();
      return;
    }

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
      final res = await api.submitDialogueTurn(_sessionId!, text);
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
    final scenarioTitle = _isNew 
        ? (_scenario?['title'] as String? ?? 'Đàm thoại AI') 
        : (_session?['scenario']?['title'] as String? ?? 'Đàm thoại AI');

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
        actions: [
          if (_session != null || _scenario != null)
            IconButton(
              icon: const Icon(Icons.history, color: Colors.white),
              onPressed: _showHistoryBottomSheet,
            ),
        ],
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
                          onPressed: _isNew ? _loadScenarioInfo : _loadHistory,
                          child: const Text('Tải lại'),
                        ),
                      ],
                    ),
                  ),
                )
              : _isNew
                  ? _buildStartScreen()
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
                    if (!_isKeyboardMode && (_isListening || _textController.text.isNotEmpty))
                      Container(
                        width: double.infinity,
                        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1E1E2F),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: _isListening
                                ? const Color(0xFF6366F1).withValues(alpha: 0.4)
                                : const Color(0xFF334155),
                            width: 1,
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              _isListening ? Icons.record_voice_over : Icons.keyboard_voice,
                              color: _isListening ? const Color(0xFF14B8A6) : Colors.white54,
                              size: 18,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                _textController.text.isEmpty
                                    ? (_isListening ? 'Đang nhận diện giọng nói...' : '')
                                    : _textController.text,
                                style: GoogleFonts.outfit(
                                  color: Colors.white,
                                  fontSize: 14,
                                  fontStyle: _textController.text.isEmpty ? FontStyle.italic : FontStyle.normal,
                                ),
                              ),
                            ),
                            if (_textController.text.isNotEmpty && !_isListening)
                              IconButton(
                                icon: const Icon(Icons.clear, size: 16, color: Colors.white54),
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                                onPressed: () {
                                  setState(() {
                                    _textController.clear();
                                  });
                                },
                              ),
                          ],
                        ),
                      ),
                    _buildInputPanel(),
                  ],
                ),
    );
  }

  Future<void> _showHistoryBottomSheet() async {
    final scenarioId = _isNew ? widget.id : (_session?['scenario']?['id'] as String?);
    final scenarioTitle = _isNew ? (_scenario?['title'] as String? ?? 'Hội thoại') : (_session?['scenario']?['title'] as String? ?? 'Hội thoại');
    if (scenarioId == null) return;
    
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF161624),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Consumer(
              builder: (context, ref, _) {
                final api = ref.read(apiClientProvider);
                
                return FutureBuilder<Response>(
                  future: api.getDialogueSessionsForScenario(scenarioId),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const SizedBox(
                        height: 300,
                        child: Center(child: CircularProgressIndicator(color: Color(0xFF6366F1))),
                      );
                    }
                    
                    if (snapshot.hasError) {
                      return SizedBox(
                        height: 300,
                        child: Center(
                          child: Text(
                            'Lỗi tải lịch sử: ${snapshot.error}',
                            style: GoogleFonts.outfit(color: Colors.redAccent),
                          ),
                        ),
                      );
                    }
                    
                    final sessions = (snapshot.data?.data as List<dynamic>?) ?? [];
                    
                    return Container(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Text(
                                  'Lịch sử: $scenarioTitle',
                                  style: GoogleFonts.outfit(
                                    color: Colors.white,
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.close, color: Colors.white70),
                                onPressed: () => Navigator.pop(context),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          // New session button
                          SizedBox(
                            width: double.infinity,
                            height: 45,
                            child: ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF6366F1),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                              onPressed: _isSending ? null : () {
                                Navigator.pop(context); // Close bottom sheet
                                setState(() {
                                  _sessionId = null;
                                  _session = null;
                                  _turns = [];
                                  _isNew = true;
                                });
                                _loadScenarioInfo();
                              },
                              icon: const Icon(Icons.add, color: Colors.white),
                              label: Text(
                                'Bắt đầu hội thoại mới',
                                style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold),
                              ),
                            ),
                          ),
                          const SizedBox(height: 15),
                          if (sessions.isEmpty)
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 30.0),
                              child: Center(
                                child: Text(
                                  'Chưa có lịch sử luyện tập nào.',
                                  style: GoogleFonts.outfit(color: Colors.white38),
                                ),
                              ),
                            )
                          else
                            Flexible(
                              child: ListView.builder(
                                shrinkWrap: true,
                                itemCount: sessions.length,
                                itemBuilder: (context, idx) {
                                  final s = sessions[idx] as Map<String, dynamic>;
                                  final sId = s['id'] as String;
                                  final createdAtStr = s['createdAt'] as String;
                                  final createdDate = DateTime.parse(createdAtStr).toLocal();
                                  final turnsList = (s['turns'] as List<dynamic>?) ?? [];
                                  
                                  // Compute average score or latest score
                                  int? avgScore;
                                  final scores = turnsList
                                      .where((t) => t['role'] == 'USER' && t['pronunciationScore'] != null)
                                      .map((t) => t['pronunciationScore'] as int)
                                      .toList();
                                  if (scores.isNotEmpty) {
                                    avgScore = (scores.reduce((a, b) => a + b) / scores.length).round();
                                  }
                                  
                                  final isCurrent = sId == _sessionId;
                                  
                                  final formattedDate = 
                                      '${createdDate.day}/${createdDate.month}/${createdDate.year} '
                                      '${createdDate.hour.toString().padLeft(2, '0')}:${createdDate.minute.toString().padLeft(2, '0')}';
                                  
                                  return Container(
                                    margin: const EdgeInsets.only(bottom: 10),
                                    decoration: BoxDecoration(
                                      color: isCurrent 
                                          ? const Color(0xFF6366F1).withOpacity(0.15) 
                                          : const Color(0xFF1E1E2F),
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(
                                        color: isCurrent 
                                            ? const Color(0xFF6366F1) 
                                            : const Color(0xFF334155).withOpacity(0.5),
                                        width: 1,
                                      ),
                                    ),
                                    child: ListTile(
                                      title: Text(
                                        formattedDate,
                                        style: GoogleFonts.outfit(
                                          color: Colors.white,
                                          fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
                                        ),
                                      ),
                                      subtitle: Text(
                                        'Số lượt thoại: ${turnsList.length} ${avgScore != null ? "| Điểm TB: $avgScore" : ""}',
                                        style: GoogleFonts.outfit(color: Colors.white60, fontSize: 13),
                                      ),
                                      trailing: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          if (isCurrent)
                                            const Icon(Icons.check_circle, color: Color(0xFF10B981))
                                          else
                                            const Icon(Icons.arrow_forward_ios, size: 14, color: Colors.white54),
                                          const SizedBox(width: 8),
                                          IconButton(
                                            icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 20),
                                            padding: EdgeInsets.zero,
                                            constraints: const BoxConstraints(),
                                            onPressed: () {
                                              _confirmDeleteSession(context, sId, setModalState, scenarioId);
                                            },
                                          ),
                                        ],
                                      ),
                                      onTap: () {
                                        Navigator.pop(context);
                                        if (!isCurrent) {
                                          setState(() {
                                            _sessionId = sId;
                                            _isNew = false;
                                          });
                                          _loadHistory();
                                        }
                                      },
                                    ),
                                  );
                                },
                              ),
                            ),
                        ],
                      ),
                    );
                  },
                );
              },
            );
          },
        );
      },
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
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.psychology, size: 16, color: Colors.white54),
                    const SizedBox(width: 6),
                    Text(
                      'Tự động gửi câu trả lời',
                      style: GoogleFonts.outfit(color: Colors.white70, fontSize: 12),
                    ),
                  ],
                ),
                Transform.scale(
                  scale: 0.8,
                  child: Switch(
                    value: _isAutoSubmit,
                    activeThumbColor: const Color(0xFF6366F1),
                    activeTrackColor: const Color(0xFF6366F1).withValues(alpha: 0.5),
                    onChanged: (val) {
                      setState(() {
                        _isAutoSubmit = val;
                      });
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
            IconButton(
              icon: Icon(
                _isKeyboardMode ? Icons.mic : Icons.keyboard,
                color: _isSending ? Colors.white24 : Colors.white54,
              ),
              onPressed: _isSending
                  ? null
                  : () {
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
                        border: Border.all(
                          color: _isSending ? const Color(0xFF1E293B) : const Color(0xFF334155),
                          width: 1,
                        ),
                      ),
                      child: TextField(
                        controller: _textController,
                        enabled: !_isSending,
                        style: GoogleFonts.outfit(
                          color: _isSending ? Colors.white30 : Colors.white,
                          fontSize: 15,
                        ),
                        decoration: InputDecoration(
                          hintText: _isSending ? 'Đang gửi phản hồi...' : 'Nhập câu trả lời bằng tiếng Hàn...',
                          hintStyle: GoogleFonts.outfit(color: Colors.white30, fontSize: 14),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                          border: InputBorder.none,
                        ),
                      ),
                    )
                  : GestureDetector(
                      onTap: _isSending
                          ? null
                          : (_isListening ? _stopListening : _startListening),
                      child: Container(
                        height: 48,
                        decoration: BoxDecoration(
                          color: _isSending
                              ? const Color(0xFF161624)
                              : (_isListening
                                  ? const Color(0xFFEF4444).withValues(alpha: 0.15)
                                  : const Color(0xFF6366F1).withValues(alpha: 0.1)),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: _isSending
                                ? const Color(0xFF1E293B)
                                : (_isListening
                                    ? Colors.redAccent
                                    : const Color(0xFF6366F1).withValues(alpha: 0.3)),
                            width: 1,
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              _isListening ? Icons.stop : Icons.mic,
                              color: _isSending
                                  ? Colors.white24
                                  : (_isListening ? Colors.redAccent : const Color(0xFF818CF8)),
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              _isSending
                                  ? 'Đang gửi phản hồi...'
                                  : (_isListening ? 'Đang nghe... Nhấn để dừng' : 'Nhấn để Nói tiếng Hàn'),
                              style: GoogleFonts.outfit(
                                color: _isSending
                                    ? Colors.white30
                                    : (_isListening ? Colors.redAccent : const Color(0xFF818CF8)),
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
            IconButton(
              icon: Icon(
                Icons.send,
                color: _isSending || _textController.text.trim().isEmpty
                    ? Colors.white24
                    : const Color(0xFF6366F1),
              ),
              onPressed: _isSending || _textController.text.trim().isEmpty ? null : _sendTurn,
            ),
          ],
        ),
      ],
    ),
  ),
);
  }

  Widget _buildStartScreen() {
    if (_scenario == null) {
      return const Center(child: CircularProgressIndicator(color: Color(0xFF6366F1)));
    }

    final title = _scenario!['title'] as String? ?? '';
    final desc = _scenario!['description'] as String? ?? '';
    final difficulty = _scenario!['difficulty'] as String? ?? 'EASY';
    
    final Color diffColor = _getDifficultyColor(difficulty);
    final String diffText = _getDifficultyText(difficulty);
    final IconData scenarioIcon = _getScenarioIcon(title);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: const Color(0xFF6366F1).withValues(alpha: 0.1),
              shape: BoxShape.circle,
              border: Border.all(
                color: const Color(0xFF6366F1).withValues(alpha: 0.3),
                width: 2,
              ),
            ),
            child: Icon(
              scenarioIcon,
              color: const Color(0xFF818CF8),
              size: 64,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            title,
            textAlign: TextAlign.center,
            style: GoogleFonts.outfit(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(
              color: diffColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: diffColor.withValues(alpha: 0.3), width: 1),
            ),
            child: Text(
              diffText,
              style: GoogleFonts.outfit(
                color: diffColor,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(height: 24),
          Card(
            color: const Color(0xFF161624),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: const BorderSide(color: Color(0xFF1E293B), width: 1),
            ),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Text(
                desc,
                textAlign: TextAlign.center,
                style: GoogleFonts.outfit(
                  color: const Color(0xFF94A3B8),
                  fontSize: 14,
                  height: 1.6,
                ),
              ),
            ),
          ),
          const SizedBox(height: 48),
          _isSending
              ? const CircularProgressIndicator(color: Color(0xFF6366F1))
              : Container(
                  width: 220,
                  height: 56,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(28),
                    gradient: const LinearGradient(
                      colors: [Color(0xFF6366F1), Color(0xFF4F46E5)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF6366F1).withValues(alpha: 0.3),
                        blurRadius: 16,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(28),
                      onTap: _startPractice,
                      child: Center(
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.play_arrow, color: Colors.white, size: 24),
                            const SizedBox(width: 8),
                            Text(
                              'Bắt đầu hội thoại',
                              style: GoogleFonts.outfit(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
        ],
      ),
    );
  }

  void _showOutOfTicketsDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF161624),
        title: Text(
          'Hết lượt dùng AI 🤖',
          style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        content: Text(
          'Bạn đã sử dụng hết lượt dùng AI miễn phí. Hãy mua thêm vé hoặc đăng ký Premium để tiếp tục hội thoại không giới hạn.',
          style: GoogleFonts.outfit(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Để sau', style: GoogleFonts.outfit(color: Colors.white54)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF6366F1),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            ),
            onPressed: () {
              Navigator.pop(ctx);
              context.push('/store');
            },
            child: Text('Đến Cửa Hàng', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}

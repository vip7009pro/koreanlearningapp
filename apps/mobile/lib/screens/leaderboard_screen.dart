import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/api_client.dart';
import '../providers/auth_provider.dart';

class LeaderboardScreen extends ConsumerStatefulWidget {
  const LeaderboardScreen({super.key});

  @override
  ConsumerState<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends ConsumerState<LeaderboardScreen> {
  bool _isLoading = true;
  List<dynamic> _users = [];

  @override
  void initState() {
    super.initState();
    _loadLeaderboard();
  }

  Future<void> _loadLeaderboard() async {
    final api = ref.read(apiClientProvider);
    try {
      final res = await api.getLeaderboard();
      if (mounted) {
        setState(() {
          _users = res.data ?? [];
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authProvider);
    final currentUserId = auth.user?['id'];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Bảng xếp hạng 🏆'),
        elevation: 0,
        backgroundColor: const Color(0xFF2563EB),
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _users.isEmpty
              ? const Center(child: Text('Chưa có dữ liệu bảng xếp hạng'))
              : Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.only(
                          bottom: 24, left: 16, right: 16, top: 16),
                      decoration: const BoxDecoration(
                        color: Color(0xFF2563EB),
                        borderRadius: BorderRadius.only(
                          bottomLeft: Radius.circular(32),
                          bottomRight: Radius.circular(32),
                        ),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          if (_users.length >= 2)
                            _buildTopThreePodcast(
                                _users[1], 2, Colors.grey.shade300, 100),
                          const SizedBox(width: 16),
                          if (_users.isNotEmpty)
                            _buildTopThreePodcast(
                                _users[0], 1, Colors.amber, 130),
                          const SizedBox(width: 16),
                          if (_users.length >= 3)
                            _buildTopThreePodcast(
                                _users[2], 3, Colors.deepOrange.shade300, 80),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    Expanded(
                      child: ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: _users.length,
                        itemBuilder: (context, index) {
                          final rank = index + 1;
                          final u = _users[index];
                          final isMe = u['id'] == currentUserId;

                          return Card(
                            elevation: isMe ? 4 : 1,
                            color: isMe ? Colors.blue.shade50 : Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                              side: BorderSide(
                                  color: isMe
                                      ? Colors.blue.shade200
                                      : Colors.transparent),
                            ),
                            margin: const EdgeInsets.only(bottom: 12),
                            child: ListTile(
                              leading: CircleAvatar(
                                backgroundColor:
                                    isMe ? Colors.blue : Colors.grey.shade200,
                                child: Text(
                                  '$rank',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: isMe ? Colors.white : Colors.black87,
                                  ),
                                ),
                              ),
                              title: Text(
                                '${u['displayName'] ?? 'User'}${isMe ? ' (Bạn)' : ''}',
                                style: TextStyle(
                                  fontWeight: isMe
                                      ? FontWeight.bold
                                      : FontWeight.normal,
                                ),
                              ),
                              trailing: Text(
                                '${u['totalXP']} XP',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF2563EB),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
    );
  }

  Widget _buildTopThreePodcast(
      dynamic user, int rank, Color color, double height) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        if (rank == 1)
          const Icon(Icons.workspace_premium, color: Colors.amber, size: 40),
        CircleAvatar(
          radius: rank == 1 ? 36 : 28,
          backgroundColor: Colors.white,
          child: CircleAvatar(
            radius: rank == 1 ? 32 : 24,
            backgroundColor: color.withValues(alpha: 0.2),
            child: Text(
              (user['displayName'] ?? 'U')[0],
              style: TextStyle(
                fontSize: rank == 1 ? 28 : 20,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          user['displayName'] ?? '',
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
          overflow: TextOverflow.ellipsis,
        ),
        Text(
          '${user['totalXP']} XP',
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.8),
            fontSize: 12,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          width: 70,
          height: height,
          decoration: BoxDecoration(
            color: color,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(8),
              topRight: Radius.circular(8),
            ),
          ),
          child: Center(
            child: Text(
              '$rank',
              style: const TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),
        )
      ],
    );
  }
}

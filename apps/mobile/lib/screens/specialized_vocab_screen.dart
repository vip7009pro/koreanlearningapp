import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../core/api_client.dart';
import '../core/tts_service.dart';
import '../providers/app_settings_provider.dart';
import '../widgets/app_banner_ad.dart';

class SpecializedVocabScreen extends ConsumerStatefulWidget {
  const SpecializedVocabScreen({super.key});

  @override
  ConsumerState<SpecializedVocabScreen> createState() => _SpecializedVocabScreenState();
}

class _SpecializedVocabScreenState extends ConsumerState<SpecializedVocabScreen>
    with SingleTickerProviderStateMixin {
  TabController? _tabController;
  List<Map<String, String>> _categories = [];

  bool _loadingCategories = true;
  bool _loading = false;
  List<dynamic> _vocab = [];
  int _currentVocabIndex = 0;
  bool _showMeaning = false;
  bool _listViewMode = false;

  @override
  void initState() {
    super.initState();
    _loadCategories();
  }

  @override
  void dispose() {
    _tabController?.dispose();
    super.dispose();
  }

  Future<void> _loadCategories() async {
    setState(() {
      _loadingCategories = true;
    });

    final api = ref.read(apiClientProvider);
    try {
      final res = await api.getSpecializedCategories();
      final list = res.data as List?;
      if (list != null && list.isNotEmpty) {
        _categories = list.map((item) {
          return {
            'id': (item['name'] as String?) ?? '',
            'name': (item['displayName'] as String?) ?? '',
          };
        }).toList();
      }
    } catch (_) {
      // Fallback below
    }

    if (_categories.isEmpty) {
      _categories = [
        {'id': 'IT', 'name': 'CNTT / IT 💻'},
        {'id': 'BUSINESS', 'name': 'Văn phòng 💼'},
        {'id': 'EPS', 'name': 'Sản xuất / EPS ⚙️'},
        {'id': 'CONSTRUCTION', 'name': 'Xây dựng 🏗️'},
      ];
    }

    if (mounted) {
      setState(() {
        _loadingCategories = false;
        _tabController = TabController(length: _categories.length, vsync: this);
        _tabController!.addListener(() {
          if (_tabController!.indexIsChanging) return;
          _loadVocab();
        });
      });
      _loadVocab();
    }
  }

  Future<void> _loadVocab() async {
    if (_tabController == null) return;
    setState(() {
      _loading = true;
      _vocab = [];
      _currentVocabIndex = 0;
      _showMeaning = false;
    });

    final categoryId = _categories[_tabController!.index]['id']!;
    final api = ref.read(apiClientProvider);

    try {
      final res = await api.getSpecializedVocabulary(categoryId);
      final list = (res.data['data'] as List?) ?? [];
      if (mounted) {
        setState(() {
          _vocab = list;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  void _speakKorean(String text) {
    ref.read(ttsProvider).speak(text);
  }

  @override
  Widget build(BuildContext context) {
    final themeId = ref.watch(appSettingsProvider).themeId;
    final theme = AppSettingsNotifier.themeById(themeId);

    if (_loadingCategories) {
      return Scaffold(
        appBar: AppBar(
          title: Text(
            'Từ vựng chuyên ngành',
            style: GoogleFonts.outfit(fontWeight: FontWeight.w600),
          ),
          foregroundColor: Colors.white,
          backgroundColor: Colors.transparent,
          flexibleSpace: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: theme.gradient),
            ),
          ),
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Từ vựng chuyên ngành',
          style: GoogleFonts.outfit(fontWeight: FontWeight.w600),
        ),
        foregroundColor: Colors.white,
        backgroundColor: Colors.transparent,
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: theme.gradient),
          ),
        ),
        actions: [
          IconButton(
            tooltip: _listViewMode ? 'Xem dạng card lật' : 'Xem dạng danh sách',
            icon: Icon(_listViewMode ? Icons.style : Icons.view_list),
            onPressed: () {
              setState(() {
                _listViewMode = !_listViewMode;
                _showMeaning = false;
              });
            },
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white.withOpacity(0.7),
          indicatorColor: Colors.white,
          labelStyle: GoogleFonts.outfit(
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
          tabs: _categories.map((cat) => Tab(text: cat['name'])).toList(),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _vocab.isEmpty
              ? const Center(
                  child: Text(
                    'Không có từ vựng chuyên ngành nào.',
                    style: TextStyle(fontSize: 16, color: Colors.grey),
                  ),
                )
              : _listViewMode
                  ? _buildListView(theme)
                  : _buildCardView(theme),
    );
  }

  Widget _buildListView(AppThemeOption theme) {
    return Column(
      children: [
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: _vocab.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final v = _vocab[index];
              return Card(
                child: ListTile(
                  title: Text(
                    v['korean'] ?? '',
                    style: GoogleFonts.outfit(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 4),
                      if ((v['pronunciation'] ?? '').isNotEmpty)
                        Text(
                          '${v['pronunciation']}',
                          style: TextStyle(color: Colors.grey.shade600),
                        ),
                      const SizedBox(height: 4),
                      Text(
                        v['vietnamese'] ?? '',
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF10B981),
                        ),
                      ),
                      if ((v['exampleSentence'] ?? '').isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Text(
                          v['exampleSentence'] ?? '',
                          style: TextStyle(
                            fontStyle: FontStyle.italic,
                            color: Colors.grey.shade700,
                          ),
                        ),
                        if ((v['exampleMeaning'] ?? '').isNotEmpty)
                          Text(
                            v['exampleMeaning'] ?? '',
                            style: TextStyle(color: Colors.grey.shade600),
                          ),
                      ]
                    ],
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.bookmark_add_outlined),
                        onPressed: () => _addToSRS(v['id']),
                      ),
                      IconButton(
                        icon: Icon(Icons.volume_up, color: theme.seedColor),
                        onPressed: () => _speakKorean(v['korean'] ?? ''),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        const AppBannerAd(),
        const SizedBox(height: 12),
      ],
    );
  }

  Widget _buildCardView(AppThemeOption theme) {
    final v = _vocab[_currentVocabIndex];
    return Column(
      children: [
        Expanded(
          child: GestureDetector(
            onTap: () {
              HapticFeedback.lightImpact();
              setState(() => _showMeaning = !_showMeaning);
            },
            onHorizontalDragEnd: (details) {
              if (details.primaryVelocity! < 0 &&
                  _currentVocabIndex < _vocab.length - 1) {
                HapticFeedback.lightImpact();
                setState(() {
                  _currentVocabIndex++;
                  _showMeaning = false;
                });
              } else if (details.primaryVelocity! > 0 &&
                  _currentVocabIndex > 0) {
                HapticFeedback.lightImpact();
                setState(() {
                  _currentVocabIndex--;
                  _showMeaning = false;
                });
              }
            },
            child: Container(
              margin: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    theme.seedColor.withOpacity(0.03),
                    theme.seedColor.withOpacity(0.08),
                  ],
                ),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: Colors.grey.shade300),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.02),
                    blurRadius: 10,
                    offset: const Offset(0, 5),
                  )
                ],
              ),
              child: Center(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  child: _showMeaning
                      ? _buildMeaningBack(v, theme)
                      : _buildWordFront(v, theme),
                ),
              ),
            ),
          ),
        ),
        const AppBannerAd(),
        const SizedBox(height: 16),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back_ios_rounded),
                onPressed: _currentVocabIndex > 0
                    ? () => setState(() {
                          HapticFeedback.lightImpact();
                          _currentVocabIndex--;
                          _showMeaning = false;
                        })
                    : null,
              ),
              Text(
                '${_currentVocabIndex + 1} / ${_vocab.length}',
                style: GoogleFonts.outfit(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.arrow_forward_ios_rounded),
                onPressed: _currentVocabIndex < _vocab.length - 1
                    ? () => setState(() {
                          HapticFeedback.lightImpact();
                          _currentVocabIndex++;
                          _showMeaning = false;
                        })
                    : null,
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildWordFront(dynamic v, AppThemeOption theme) {
    return Column(
      key: const ValueKey('front'),
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          v['korean'] ?? '',
          style: GoogleFonts.outfit(
            fontSize: 48,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        if ((v['pronunciation'] ?? '').isNotEmpty)
          Text(
            v['pronunciation'] ?? '',
            style: TextStyle(
              fontSize: 18,
              color: Colors.grey.shade600,
            ),
          ),
        const SizedBox(height: 24),
        IconButton(
          icon: Icon(Icons.volume_up, size: 36, color: theme.seedColor),
          onPressed: () => _speakKorean(v['korean'] ?? ''),
        ),
        const SizedBox(height: 32),
        ElevatedButton.icon(
          onPressed: () => _addToSRS(v['id']),
          style: ElevatedButton.styleFrom(
            backgroundColor: theme.seedColor.withOpacity(0.1),
            foregroundColor: theme.seedColor,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          icon: const Icon(Icons.bookmark_add_outlined),
          label: const Text('Thêm vào ôn tập'),
        ),
        const SizedBox(height: 16),
        Text(
          'Chạm để xem nghĩa',
          style: TextStyle(color: Colors.grey.shade400, fontSize: 13),
        ),
      ],
    );
  }

  Widget _buildMeaningBack(dynamic v, AppThemeOption theme) {
    return Column(
      key: const ValueKey('back'),
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          v['korean'] ?? '',
          style: GoogleFonts.outfit(
            fontSize: 40,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        if ((v['pronunciation'] ?? '').isNotEmpty)
          Text(
            v['pronunciation'] ?? '',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey.shade600,
            ),
          ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          decoration: BoxDecoration(
            color: const Color(0xFF10B981).withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            v['vietnamese'] ?? '',
            style: GoogleFonts.outfit(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: const Color(0xFF10B981),
            ),
          ),
        ),
        if ((v['exampleSentence'] ?? '').isNotEmpty) ...[
          const SizedBox(height: 24),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              children: [
                Text(
                  v['exampleSentence'] ?? '',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.outfit(
                    fontSize: 16,
                    fontStyle: FontStyle.italic,
                    color: Colors.grey.shade800,
                  ),
                ),
                if ((v['exampleMeaning'] ?? '').isNotEmpty)
                  Text(
                    v['exampleMeaning'] ?? '',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey.shade500,
                    ),
                  ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 24),
        IconButton(
          icon: Icon(Icons.volume_up, size: 32, color: theme.seedColor),
          onPressed: () => _speakKorean(v['korean'] ?? ''),
        ),
      ],
    );
  }

  Future<void> _addToSRS(String vocabId) async {
    final api = ref.read(apiClientProvider);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await api.addToReview(vocabId);
      HapticFeedback.mediumImpact();
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Đã thêm vào danh sách ôn tập!'),
        ),
      );
    } catch (_) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Từ vựng này đã có trong danh sách ôn tập hoặc lỗi xảy ra.'),
        ),
      );
    }
  }
}

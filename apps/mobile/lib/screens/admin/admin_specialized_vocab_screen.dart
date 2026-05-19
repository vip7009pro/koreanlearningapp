import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/api_client.dart';
import '../../providers/app_settings_provider.dart';

class AdminSpecializedVocabScreen extends ConsumerStatefulWidget {
  const AdminSpecializedVocabScreen({super.key});

  @override
  ConsumerState<AdminSpecializedVocabScreen> createState() =>
      _AdminSpecializedVocabScreenState();
}

class _AdminSpecializedVocabScreenState
    extends ConsumerState<AdminSpecializedVocabScreen> {
  bool _loading = true;
  String? _error;
  List<dynamic> _items = [];
  String _activeCategory = 'IT';
  final Set<String> _selectedIds = {};

  final List<Map<String, String>> _categories = [];

  @override
  void initState() {
    super.initState();
    _loadCategories();
  }

  Future<void> _loadCategories() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    final api = ref.read(apiClientProvider);
    try {
      final res = await api.getSpecializedCategories();
      final list = res.data as List?;
      if (list != null && list.isNotEmpty) {
        _categories.clear();
        for (var item in list) {
          _categories.add({
            'id': (item['name'] as String?) ?? '',
            'label': (item['displayName'] as String?) ?? '',
            'dbId': (item['id'] as String?) ?? '',
          });
        }
      }
    } catch (_) {
      // Fallback below
    }

    if (_categories.isEmpty) {
      _categories.clear();
      _categories.addAll([
        {'id': 'IT', 'label': 'IT / CNTT'},
        {'id': 'BUSINESS', 'label': 'Văn phòng'},
        {'id': 'EPS', 'label': 'Sản xuất EPS'},
        {'id': 'CONSTRUCTION', 'label': 'Xây dựng'},
      ]);
    }

    // Ensure _activeCategory is one of the loaded categories
    if (!_categories.any((c) => c['id'] == _activeCategory)) {
      _activeCategory = _categories.first['id']!;
    }

    await _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final api = ref.read(apiClientProvider);
      final res = await api.getSpecializedVocabulary(_activeCategory);
      if (!mounted) return;
      setState(() {
        _items = res.data['data'] as List;
        _selectedIds.clear();
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _addCategory() async {
    final nameCtrl = TextEditingController();
    final labelCtrl = TextEditingController();

    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Thêm chuyên ngành mới'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtrl,
              decoration: const InputDecoration(
                labelText: 'Mã viết tắt (VD: MEDICAL, TOURISM) *',
                border: OutlineInputBorder(),
              ),
              textCapitalization: TextCapitalization.characters,
            ),
            const SizedBox(height: 10),
            TextField(
              controller: labelCtrl,
              decoration: const InputDecoration(
                labelText: 'Tên hiển thị (VD: Y học, Du lịch) *',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Hủy'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Thêm'),
          ),
        ],
      ),
    );

    if (ok != true) return;

    final name = nameCtrl.text.trim().toUpperCase();
    final label = labelCtrl.text.trim();
    if (name.isEmpty || label.isEmpty) return;

    setState(() => _loading = true);
    try {
      final api = ref.read(apiClientProvider);
      await api.createSpecializedCategory(name, label);
      _activeCategory = name;
      await _loadCategories();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Lỗi thêm chuyên ngành: $e')),
      );
      setState(() => _loading = false);
    }
  }

  Future<void> _deleteCategory() async {
    final activeCatIdx = _categories.indexWhere((c) => c['id'] == _activeCategory);
    if (activeCatIdx == -1) return;
    final activeCat = _categories[activeCatIdx];
    final dbId = activeCat['dbId'];
    if (dbId == null || dbId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Không thể xóa chuyên ngành mặc định này.')),
      );
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Xóa chuyên ngành'),
        content: Text('CẢNH BÁO: Hành động này sẽ xóa vĩnh viễn chuyên ngành "${activeCat['label']}" cùng TẤT CẢ từ vựng bên trong. Bạn có chắc muốn tiếp tục?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Hủy'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Xóa'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _loading = true);
    try {
      final api = ref.read(apiClientProvider);
      await api.deleteSpecializedCategory(dbId);
      _activeCategory = 'IT'; // Reset to default
      await _loadCategories();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Lỗi xóa chuyên ngành: $e')),
      );
      setState(() => _loading = false);
    }
  }

  Future<void> _generateAI() async {
    final countCtrl = TextEditingController(text: '10');
    String provider = 'google';
    String selectedModel = '';

    List<Map<String, String>> models = [{'id': '', 'label': '(default)'}];
    bool loadingModels = false;
    String? lastLoadedProvider;

    Future<void> loadModels(StateSetter setDialogState) async {
      setDialogState(() {
        loadingModels = true;
        models = [{'id': '', 'label': '(default)'}];
        selectedModel = '';
      });

      try {
        final api = ref.read(apiClientProvider);
        final res = await api.adminListAiModels(provider: provider);
        final data = res.data;
        final list = <Map<String, String>>[];
        final modelsRaw = (data is Map) ? data['models'] : null;
        if (modelsRaw is List) {
          for (final m in modelsRaw) {
            if (m is Map) {
              final id = (m['id'] ?? '').toString();
              final label = (m['label'] ?? id).toString();
              if (id.isNotEmpty) list.add({'id': id, 'label': label});
            }
          }
        }
        setDialogState(() {
          models = [{'id': '', 'label': '(default)'}, ...list];
          loadingModels = false;
        });
      } catch (_) {
        setDialogState(() {
          loadingModels = false;
        });
      }
    }

    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          if (lastLoadedProvider != provider) {
            lastLoadedProvider = provider;
            Future.microtask(() => loadModels(setDialogState));
          }

          return AlertDialog(
            title: Text('Sinh từ vựng AI cho $_activeCategory'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: countCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Số lượng từ *',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  initialValue: provider,
                  decoration: const InputDecoration(
                    labelText: 'AI Provider',
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'google', child: Text('Google Gemini')),
                    DropdownMenuItem(value: 'openrouter', child: Text('OpenRouter')),
                  ],
                  onChanged: (v) {
                    if (v != null) {
                      setDialogState(() {
                        provider = v;
                      });
                    }
                  },
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  key: ValueKey(provider),
                  initialValue: selectedModel,
                  decoration: const InputDecoration(
                    labelText: 'AI Model',
                    border: OutlineInputBorder(),
                  ),
                  items: models.map((m) {
                    return DropdownMenuItem<String>(
                      value: m['id'],
                      child: Text(loadingModels && m['id'] != '' ? 'Đang tải...' : m['label']!),
                    );
                  }).toList(),
                  onChanged: loadingModels
                      ? null
                      : (v) {
                          if (v != null) {
                            setDialogState(() {
                              selectedModel = v;
                            });
                          }
                        },
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Hủy'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Bắt đầu sinh'),
              ),
            ],
          );
        },
      ),
    );

    if (ok != true) return;

    final count = int.tryParse(countCtrl.text.trim()) ?? 10;
    final model = selectedModel.isEmpty ? null : selectedModel;

    setState(() => _loading = true);
    try {
      final api = ref.read(apiClientProvider);
      final res = await api.adminGenerateSpecializedVocabulary(
        _activeCategory,
        count: count,
        provider: provider,
        model: model,
      );
      final inserted = res.data['inserted'] ?? 0;
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Đã tự động sinh và thêm $inserted từ vựng mới!')),
      );
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Lỗi sinh từ vựng AI: $e')),
      );
      setState(() => _loading = false);
    }
  }

  Future<void> _delete(String id) async {
    try {
      final api = ref.read(apiClientProvider);
      await api.deleteVocabulary(id);
      _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Lỗi xóa từ vựng: $e')),
      );
    }
  }

  Future<void> _deleteBulk() async {
    if (_selectedIds.isEmpty) return;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Xóa hàng loạt'),
        content: Text('Bạn có chắc muốn xóa ${_selectedIds.length} từ đã chọn?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Hủy'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Xóa'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _loading = true);
    try {
      final api = ref.read(apiClientProvider);
      await api.deleteVocabularyBulk(_selectedIds.toList());
      _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Lỗi xóa hàng loạt: $e')),
      );
      setState(() => _loading = false);
    }
  }

  Future<void> _addEditVocab([Map<String, dynamic>? item]) async {
    final koreanCtrl = TextEditingController(text: item?['korean'] ?? '');
    final viCtrl = TextEditingController(text: item?['vietnamese'] ?? '');
    final proCtrl = TextEditingController(text: item?['pronunciation'] ?? '');
    final audioCtrl = TextEditingController(text: item?['audioUrl'] ?? '');
    final exSenCtrl = TextEditingController(text: item?['exampleSentence'] ?? '');
    final exMeanCtrl = TextEditingController(text: item?['exampleMeaning'] ?? '');
    String difficulty = item?['difficulty'] ?? 'EASY';

    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(item == null
              ? 'Thêm từ vựng chuyên ngành'
              : 'Sửa từ vựng: ${item['korean']}'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: koreanCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Từ tiếng Hàn *',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: viCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Nghĩa tiếng Việt *',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  initialValue: difficulty,
                  decoration: const InputDecoration(
                    labelText: 'Độ khó',
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'EASY', child: Text('Dễ (EASY)')),
                    DropdownMenuItem(value: 'MEDIUM', child: Text('Trung bình (MEDIUM)')),
                    DropdownMenuItem(value: 'HARD', child: Text('Khó (HARD)')),
                  ],
                  onChanged: (v) {
                    if (v != null) {
                      setDialogState(() => difficulty = v);
                    }
                  },
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: proCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Phiên âm',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: audioCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Audio URL',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: exSenCtrl,
                  minLines: 2,
                  maxLines: 4,
                  decoration: const InputDecoration(
                    labelText: 'Ví dụ minh họa (Hàn)',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: exMeanCtrl,
                  minLines: 2,
                  maxLines: 4,
                  decoration: const InputDecoration(
                    labelText: 'Dịch câu ví dụ (Việt)',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Hủy'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Lưu'),
            ),
          ],
        ),
      ),
    );

    if (ok != true) return;

    final payload = <String, dynamic>{
      'korean': koreanCtrl.text.trim(),
      'vietnamese': viCtrl.text.trim(),
      'difficulty': difficulty,
      'category': _activeCategory,
      'pronunciation': proCtrl.text.trim().isEmpty ? null : proCtrl.text.trim(),
      'audioUrl': audioCtrl.text.trim().isEmpty ? null : audioCtrl.text.trim(),
      'exampleSentence':
          exSenCtrl.text.trim().isEmpty ? null : exSenCtrl.text.trim(),
      'exampleMeaning':
          exMeanCtrl.text.trim().isEmpty ? null : exMeanCtrl.text.trim(),
    };

    if (payload['korean'] == null || (payload['korean'] as String).isEmpty) {
      return;
    }
    if (payload['vietnamese'] == null ||
        (payload['vietnamese'] as String).isEmpty) {
      return;
    }

    setState(() => _loading = true);
    try {
      final api = ref.read(apiClientProvider);
      if (item == null) {
        await api.createVocabulary(payload);
      } else {
        final id = item['id']?.toString();
        if (id != null) {
          await api.updateVocabulary(id, payload);
        }
      }
      _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Lỗi lưu từ vựng: $e')),
      );
      setState(() => _loading = false);
    }
  }

  Future<void> _bulkImportVocab() async {
    final ctrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Nhập JSON hàng loạt'),
        content: SizedBox(
          width: double.maxFinite,
          child: TextField(
            controller: ctrl,
            minLines: 10,
            maxLines: 18,
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              hintText: '[{ "korean": "...", "vietnamese": "...", "pronunciation": "...", "difficulty": "EASY/MEDIUM/HARD" }, ...]',
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Hủy'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Import'),
          ),
        ],
      ),
    );

    if (ok != true) return;

    setState(() => _loading = true);
    try {
      final raw = ctrl.text.trim();
      if (raw.isEmpty) {
        setState(() => _loading = false);
        return;
      }
      final decoded = jsonDecode(raw);
      if (decoded is! List) {
        setState(() => _loading = false);
        return;
      }

      final items = decoded.map<Map<String, dynamic>>((e) {
        final m = (e as Map).cast<String, dynamic>();
        return {
          'category': _activeCategory,
          'korean': m['korean'],
          'vietnamese': m['vietnamese'],
          'pronunciation': m['pronunciation'],
          'exampleSentence': m['exampleSentence'],
          'exampleMeaning': m['exampleMeaning'],
          'audioUrl': m['audioUrl'],
          'difficulty': m['difficulty'] ?? 'EASY',
        };
      }).toList();

      final api = ref.read(apiClientProvider);
      await api.createVocabularyBulk(items);
      _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Lỗi nhập JSON: $e')),
      );
      setState(() => _loading = false);
    }
  }

  void _copyPromptText() {
    final activeLabel = _categories.firstWhere((c) => c['id'] == _activeCategory)['label'] ?? _activeCategory;
    final existingKorean = _items.map((v) => v['korean']?.toString().trim()).where((k) => k != null && k.isNotEmpty).toList();
    final existingBlock = existingKorean.isNotEmpty
        ? '\nKHÔNG ĐƯỢC tạo trùng với các từ tiếng Hàn đã có sẵn sau đây:\n${existingKorean.map((x) => "- $x").join("\n")}\n'
        : '';

    final prompt = 'Bạn là chuyên gia ngôn ngữ tiếng Hàn. Hãy tạo danh sách 15-20 từ vựng chuyên ngành thuộc chủ đề: "$activeLabel".$existingBlock\n'
        'Chỉ trả về định dạng JSON là một mảng các đối tượng chứa thông tin từ vựng như ví dụ sau (không có bất kỳ lời giải thích, văn bản thừa hay định dạng markdown nào khác ngoài JSON):\n'
        '[\n'
        '  {\n'
        '    "korean": "개발자",\n'
        '    "vietnamese": "Nhà phát triển (lập trình viên)",\n'
        '    "pronunciation": "gae-bal-ja",\n'
        '    "exampleSentence": "그는 소프트웨어 개발자로 일하고 있습니다.",\n'
        '    "exampleMeaning": "Anh ấy đang làm việc như một nhà phát triển phần mềm.",\n'
        '    "difficulty": "MEDIUM"\n'
        '  }\n'
        ']\n\n'
        'Lưu ý:\n'
        '- "difficulty" chỉ nhận một trong 3 giá trị: "EASY", "MEDIUM", "HARD".\n'
        '- Các câu ví dụ "exampleSentence" phải tự nhiên và phù hợp với từ chuyên ngành đó.';

    Clipboard.setData(ClipboardData(text: prompt)).then((_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Đã sao chép prompt AI vào Clipboard')),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final themeId = ref.watch(appSettingsProvider).themeId;
    final theme = AppSettingsNotifier.themeById(themeId);

    final activeCatIdx = _categories.indexWhere((c) => c['id'] == _activeCategory);
    final activeCat = activeCatIdx != -1 ? _categories[activeCatIdx] : null;
    final isCustomCategory = activeCat != null &&
        activeCat['dbId'] != null &&
        activeCat['dbId']!.isNotEmpty;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Quản lý Chuyên ngành 💼'),
        actions: [
          IconButton(
            tooltip: 'Gen AI 🤖',
            icon: const Icon(Icons.smart_toy_outlined),
            onPressed: _generateAI,
          ),
          IconButton(
            tooltip: 'Thêm chuyên ngành',
            icon: const Icon(Icons.create_new_folder_outlined),
            onPressed: _addCategory,
          ),
          if (isCustomCategory)
            IconButton(
              tooltip: 'Xóa chuyên ngành này',
              icon: const Icon(Icons.folder_delete_outlined, color: Colors.red),
              onPressed: _deleteCategory,
            ),
          IconButton(
            tooltip: 'Copy Prompt AI',
            icon: const Icon(Icons.copy_outlined),
            onPressed: _copyPromptText,
          ),
          IconButton(
            tooltip: 'Import JSON',
            icon: const Icon(Icons.cloud_upload_outlined),
            onPressed: _bulkImportVocab,
          ),
          if (_selectedIds.isNotEmpty)
            IconButton(
              tooltip: 'Xóa hàng loạt',
              icon: const Icon(Icons.delete_sweep, color: Colors.red),
              onPressed: _deleteBulk,
            ),
        ],
      ),
      body: Column(
        children: [
          // Tabs
          Container(
            height: 50,
            color: Theme.of(context).cardColor,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              children: _categories.map((c) {
                final isSelected = c['id'] == _activeCategory;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(c['label']!),
                    selected: isSelected,
                    selectedColor: theme.seedColor.withValues(alpha: 0.2),
                    onSelected: (_) {
                      if (!isSelected) {
                        setState(() {
                          _activeCategory = c['id']!;
                        });
                        _load();
                      }
                    },
                  ),
                );
              }).toList(),
            ),
          ),
          const Divider(height: 1),
          // Content
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text('Lỗi: $_error'),
                            const SizedBox(height: 12),
                            ElevatedButton(
                              onPressed: _load,
                              child: const Text('Thử lại'),
                            ),
                          ],
                        ),
                      )
                    : _items.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Text('Chưa có từ vựng chuyên ngành nào.'),
                                const SizedBox(height: 12),
                                ElevatedButton.icon(
                                  onPressed: () => _addEditVocab(),
                                  icon: const Icon(Icons.add),
                                  label: const Text('Thêm từ mới'),
                                ),
                              ],
                            ),
                          )
                        : RefreshIndicator(
                            onRefresh: _load,
                            child: ListView.builder(
                              padding: const EdgeInsets.all(12),
                              itemCount: _items.length,
                              itemBuilder: (context, index) {
                                final vocab = _items[index];
                                final id = vocab['id']?.toString() ?? '';
                                final isSelected = _selectedIds.contains(id);

                                return Card(
                                  margin: const EdgeInsets.only(bottom: 10),
                                  child: ListTile(
                                    leading: Checkbox(
                                      value: isSelected,
                                      onChanged: (checked) {
                                        setState(() {
                                          if (checked == true) {
                                            _selectedIds.add(id);
                                          } else {
                                            _selectedIds.remove(id);
                                          }
                                        });
                                      },
                                    ),
                                    title: Row(
                                      children: [
                                        Text(
                                          vocab['korean'] ?? '',
                                          style: const TextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        if (vocab['pronunciation'] != null)
                                          Text(
                                            '[${vocab['pronunciation']}]',
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: Colors.grey.shade600,
                                            ),
                                          ),
                                      ],
                                    ),
                                    subtitle: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        const SizedBox(height: 4),
                                        Text(
                                          vocab['vietnamese'] ?? '',
                                          style: const TextStyle(
                                            fontSize: 14,
                                            color: Colors.black87,
                                          ),
                                        ),
                                        if (vocab['exampleSentence'] != null) ...[
                                          const SizedBox(height: 6),
                                          Text(
                                            'Ví dụ: ${vocab['exampleSentence']}',
                                            style: TextStyle(
                                              fontSize: 12,
                                              fontStyle: FontStyle.italic,
                                              color: Colors.grey.shade700,
                                            ),
                                          ),
                                          if (vocab['exampleMeaning'] != null)
                                            Text(
                                              'Nghĩa ví dụ: ${vocab['exampleMeaning']}',
                                              style: TextStyle(
                                                fontSize: 12,
                                                fontStyle: FontStyle.italic,
                                                color: Colors.grey.shade600,
                                              ),
                                            ),
                                        ],
                                      ],
                                    ),
                                    trailing: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        IconButton(
                                          icon: const Icon(Icons.edit,
                                              color: Colors.blue),
                                          onPressed: () => _addEditVocab(vocab),
                                        ),
                                        IconButton(
                                          icon: const Icon(Icons.delete,
                                              color: Colors.red),
                                          onPressed: () {
                                            showDialog(
                                              context: context,
                                              builder: (context) => AlertDialog(
                                                title: const Text('Xóa từ vựng'),
                                                content: const Text(
                                                    'Bạn có chắc chắn muốn xóa từ vựng này không?'),
                                                actions: [
                                                  TextButton(
                                                    onPressed: () =>
                                                        Navigator.pop(context),
                                                    child: const Text('Hủy'),
                                                  ),
                                                  TextButton(
                                                    onPressed: () {
                                                      Navigator.pop(context);
                                                      _delete(id);
                                                    },
                                                    style:
                                                        TextButton.styleFrom(
                                                      foregroundColor:
                                                          Colors.red,
                                                    ),
                                                    child: const Text('Xóa'),
                                                  ),
                                                ],
                                              ),
                                            );
                                          },
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: theme.seedColor,
        onPressed: () => _addEditVocab(),
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }
}

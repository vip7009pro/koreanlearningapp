import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/services.dart';
import '../../core/api_client.dart';
import '../../providers/auth_provider.dart';

class AdminUploadScreen extends ConsumerStatefulWidget {
  const AdminUploadScreen({super.key});

  @override
  ConsumerState<AdminUploadScreen> createState() => _AdminUploadScreenState();
}

class _AdminUploadScreenState extends ConsumerState<AdminUploadScreen> {
  bool _uploading = false;
  String? _lastUrl;
  String? _error;

  Future<void> _pickAndUpload({required bool isImage}) async {
    if (_uploading) return;

    setState(() {
      _uploading = true;
      _error = null;
    });

    try {
      final result = await FilePicker.platform.pickFiles(
        type: isImage ? FileType.image : FileType.custom,
        allowedExtensions: isImage
            ? null
            : ['mp3', 'wav', 'm4a', 'aac', 'ogg', 'flac'],
        withData: false,
      );

      final path = result?.files.single.path;
      if (path == null || path.isEmpty) {
        if (!mounted) return;
        setState(() => _uploading = false);
        return;
      }

      final api = ref.read(apiClientProvider);
      final res = isImage ? await api.uploadImage(path) : await api.uploadAudio(path);
      final url = (res.data as Map)['url']?.toString();

      if (!mounted) return;
      setState(() {
        _lastUrl = url;
        _uploading = false;
      });

      if (url != null && url.isNotEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Upload thành công')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _uploading = false;
      });
    }
  }

  Future<void> _copyUrl() async {
    if (_lastUrl == null || _lastUrl!.isEmpty) return;
    await Clipboard.setData(ClipboardData(text: _lastUrl!));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Đã copy URL')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final role = ref.watch(authProvider).user?['role'];
    if (role != 'ADMIN') {
      return const Scaffold(
        body: Center(child: Text('Bạn không có quyền truy cập')),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Upload (Admin)')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Upload image/audio để lấy URL và dán vào content (vocab/dialogue/quiz/thumbnail...)',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: _uploading
                              ? null
                              : () => _pickAndUpload(isImage: true),
                          icon: const Icon(Icons.image),
                          label: const Text('Upload image'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: _uploading
                              ? null
                              : () => _pickAndUpload(isImage: false),
                          icon: const Icon(Icons.audiotrack),
                          label: const Text('Upload audio'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (_uploading)
                    const LinearProgressIndicator()
                  else if (_error != null)
                    Text(
                      _error!,
                      style: const TextStyle(color: Colors.red),
                    )
                  else if (_lastUrl != null && _lastUrl!.isNotEmpty)
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('URL:'),
                        const SizedBox(height: 6),
                        SelectableText(_lastUrl!),
                        const SizedBox(height: 10),
                        OutlinedButton.icon(
                          onPressed: _copyUrl,
                          icon: const Icon(Icons.copy),
                          label: const Text('Copy URL'),
                        ),
                      ],
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

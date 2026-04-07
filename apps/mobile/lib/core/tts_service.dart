import 'dart:convert';
import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sherpa_onnx/sherpa_onnx.dart' as sherpa_onnx;

import '../providers/app_settings_provider.dart';
import 'api_client.dart';

final ttsProvider = Provider<TtsService>((ref) {
  final service = TtsService(ref);
  ref.onDispose(service.dispose);
  return service;
});

class TtsService {
  final Ref ref;
  final FlutterTts _localTts = FlutterTts();
  final AudioPlayer _cloudPlayer = AudioPlayer();
  final AudioPlayer _piperPlayer = AudioPlayer();
  bool _initialized = false;
  bool _piperInitialized = false;
  Completer<void>? _speakCompleter;
  List<dynamic>? _voices;
  Map<String, dynamic>? _maleVoice;
  Map<String, dynamic>? _femaleVoice;
  String? _cloudTempPath;
  String? _piperTempPath;
  sherpa_onnx.OfflineTts? _piperTts;

  TtsService(this.ref);

  bool get _useCloudTts =>
      ref.read(appSettingsProvider).ttsMode ==
      AppSettingsNotifier.ttsModeNatural;

  bool get _usePiperTts =>
      ref.read(appSettingsProvider).ttsMode == AppSettingsNotifier.ttsModePiper;

  String get selectedEngineLabel {
    if (_usePiperTts) return 'Piper offline (ONNX Runtime)';
    if (_useCloudTts) return 'Google Cloud TTS';
    return 'Device TTS';
  }

  bool get isPiperReady => _piperInitialized;

  String _assetBasename(String assetPath) {
    return assetPath.split('/').last;
  }

  Future<String> _copyAssetToDocuments(String assetPath) async {
    final fileName = _assetBasename(assetPath);
    final directory = await getApplicationDocumentsDirectory();
    final file = File('${directory.path}/tts_models/$fileName');
    await file.parent.create(recursive: true);

    final data = await rootBundle.load(assetPath);
    await file.writeAsBytes(data.buffer.asUint8List(), flush: true);

    return file.path;
  }

  Future<String> _copyAssetDirectoryToDocuments(
      String assetDirectoryPath) async {
    final manifest =
        jsonDecode(await rootBundle.loadString('AssetManifest.json'))
            as Map<String, dynamic>;
    final assetPrefix = '$assetDirectoryPath/';
    final assetPaths = manifest.keys
        .where((assetPath) => assetPath.startsWith(assetPrefix))
        .toList()
      ..sort();

    if (assetPaths.isEmpty) {
      throw StateError(
        'No assets found under $assetDirectoryPath in the Flutter asset bundle. '
        'Run a full rebuild after updating pubspec.yaml so the espeak-ng-data '
        'directory is packaged.',
      );
    }

    final directory = await getApplicationDocumentsDirectory();
    final targetRoot =
        Directory('${directory.path}/tts_models/$assetDirectoryPath');
    await targetRoot.create(recursive: true);

    for (final assetPath in assetPaths) {
      final relativePath = assetPath.substring(assetPrefix.length);
      if (relativePath.isEmpty) continue;

      final targetFile = File('${targetRoot.path}/$relativePath');
      await targetFile.parent.create(recursive: true);

      final data = await rootBundle.load(assetPath);
      await targetFile.writeAsBytes(data.buffer.asUint8List(), flush: true);
    }

    return targetRoot.path;
  }

  Future<String> _ensurePiperTokensFile() async {
    const tokensAsset = 'assets/models/tokens.txt';
    try {
      return await _copyAssetToDocuments(tokensAsset);
    } catch (_) {
      // Some builds may not bundle the generated tokens asset yet.
    }

    const configAsset = 'assets/models/piper-korean.onnx.json';
    final configText = await rootBundle.loadString(configAsset);
    final config = jsonDecode(configText) as Map<String, dynamic>;
    final phonemeIdMap = config['phoneme_id_map'];

    if (phonemeIdMap is! Map) {
      throw StateError('Piper model config is missing phoneme_id_map');
    }

    final lines = <String>[];
    for (final entry in phonemeIdMap.entries) {
      final symbol = entry.key.toString();
      final value = entry.value;
      if (value is List && value.isNotEmpty) {
        lines.add('$symbol ${value.first}');
      } else if (value != null) {
        lines.add('$symbol $value');
      }
    }

    final directory = await getApplicationDocumentsDirectory();
    final file = File('${directory.path}/tts_models/tokens.txt');
    await file.parent.create(recursive: true);
    await file.writeAsString('${lines.join('\n')}\n', flush: true);
    return file.path;
  }

  Future<void> _initPiper() async {
    if (_piperInitialized) return;

    try {
      sherpa_onnx.initBindings();

      const modelAsset = 'assets/models/piper-korean.onnx';
      const configAsset = 'assets/models/piper-korean.onnx.json';
      const dataDirAsset = 'assets/models/espeak-ng-data';

      final modelPath = await _copyAssetToDocuments(modelAsset);
      await _copyAssetToDocuments(configAsset);
      final dataDirPath = await _copyAssetDirectoryToDocuments(dataDirAsset);

      final tokensPath = await _ensurePiperTokensFile();

      final modelConfig = sherpa_onnx.OfflineTtsVitsModelConfig(
        model: modelPath,
        lexicon: '',
        tokens: tokensPath,
        dataDir: dataDirPath,
      );

      final config = sherpa_onnx.OfflineTtsConfig(
        model: sherpa_onnx.OfflineTtsModelConfig(
          vits: modelConfig,
          numThreads: 4,
          debug: false,
        ),
      );

      _piperTts = sherpa_onnx.OfflineTts(config);
      _piperInitialized = true;
    } catch (error, stackTrace) {
      _piperTts = null;
      _piperInitialized = false;
      debugPrint('Piper init failed: $error');
      debugPrintStack(stackTrace: stackTrace);
      throw StateError(
        'Piper offline TTS is not ready: $error',
      );
    }
  }

  Future<void> _writePiperWaveAndPlay(
    sherpa_onnx.GeneratedAudio audio, {
    bool wait = false,
    Duration timeout = const Duration(seconds: 12),
  }) async {
    final sampleRate = audio.sampleRate;
    final file = File(
      '${Directory.systemTemp.path}/piper_tts_${DateTime.now().microsecondsSinceEpoch}.wav',
    );

    final wrote = sherpa_onnx.writeWave(
      filename: file.path,
      samples: audio.samples,
      sampleRate: sampleRate,
    );

    if (!wrote) {
      throw StateError('Unable to write Piper WAV output');
    }

    await _cleanupPiperTempFile();
    _piperTempPath = file.path;

    try {
      await _piperPlayer.stop();
      final completion = Completer<void>();
      late final StreamSubscription<void> subscription;
      subscription = _piperPlayer.onPlayerComplete.listen((_) {
        if (!completion.isCompleted) completion.complete();
      });

      await _piperPlayer.play(DeviceFileSource(file.path));

      if (wait) {
        try {
          await completion.future.timeout(timeout);
        } catch (_) {
          // Best-effort: if playback completion doesn't fire, don't hang forever.
        }
      }

      await subscription.cancel();
      if (wait) {
        await _cleanupPiperTempFile();
      }
    } catch (_) {
      await _cleanupPiperTempFile();
      rethrow;
    }
  }

  Future<void> _cleanupPiperTempFile() async {
    final path = _piperTempPath;
    _piperTempPath = null;
    if (path == null || path.isEmpty) return;

    try {
      await File(path).delete();
    } catch (_) {
      // Ignore temp file cleanup failures.
    }
  }

  Future<void> _speakPiper(
    String text, {
    bool wait = false,
    Duration timeout = const Duration(seconds: 12),
  }) async {
    final normalized = text.trim();
    if (normalized.isEmpty) return;

    await _initPiper();
    final tts = _piperTts;
    if (tts == null) {
      throw StateError('Piper TTS is not initialized');
    }

    final generated = tts.generate(
      text: normalized,
      sid: 0,
      speed: 1.0,
    );

    await _writePiperWaveAndPlay(
      generated,
      wait: wait,
      timeout: timeout,
    );
  }

  Future<void> _initLocal() async {
    if (_initialized) return;
    await _localTts.setLanguage('ko-KR');
    await _localTts.setSpeechRate(0.45);
    await _localTts.setVolume(1.0);
    await _localTts.setPitch(1.0);

    _localTts.setCompletionHandler(() {
      final c = _speakCompleter;
      if (c != null && !c.isCompleted) c.complete();
    });
    _localTts.setCancelHandler(() {
      final c = _speakCompleter;
      if (c != null && !c.isCompleted) c.complete();
    });
    _localTts.setErrorHandler((_) {
      final c = _speakCompleter;
      if (c != null && !c.isCompleted) c.complete();
    });

    _initialized = true;
  }

  bool _looksLikeDialogueLine(String line) {
    final trimmed = line.trimLeft();
    return trimmed.startsWith('남자') ||
        trimmed.startsWith('여자') ||
        trimmed.startsWith('남:') ||
        trimmed.startsWith('여:') ||
        trimmed.startsWith('남자:') ||
        trimmed.startsWith('여자:');
  }

  ({String role, String text}) _parseDialogueLine(String line) {
    var text = line.trim();
    String role = '';
    if (text.startsWith('남자')) role = 'male';
    if (text.startsWith('여자')) role = 'female';
    if (text.startsWith('남:') || text.startsWith('남자:')) role = 'male';
    if (text.startsWith('여:') || text.startsWith('여자:')) role = 'female';

    text = text
        .replaceFirst(RegExp(r'^(남자|여자)\s*[:：\-]?\s*'), '')
        .replaceFirst(RegExp(r'^(남|여)\s*[:：\-]\s*'), '')
        .trim();
    return (role: role, text: text);
  }

  Future<void> _ensureVoicesLoaded() async {
    if (_voices != null) return;

    try {
      final voices = await _localTts.getVoices;
      if (voices is List) {
        _voices = voices;
      } else {
        _voices = const [];
      }

      Map<String, dynamic>? pickVoice(bool female) {
        for (final v in _voices ?? const []) {
          if (v is! Map) continue;
          final map = v.cast<String, dynamic>();
          final name = (map['name'] ?? '').toString().toLowerCase();
          final locale = (map['locale'] ?? '').toString().toLowerCase();
          if (!locale.contains('ko')) continue;

          final isFemale = name.contains('female') ||
              name.contains('woman') ||
              name.contains('여성');
          final isMale = name.contains('male') ||
              name.contains('man') ||
              name.contains('남성');
          if (female && isFemale) return map;
          if (!female && isMale) return map;
        }

        for (final v in _voices ?? const []) {
          if (v is! Map) continue;
          final map = v.cast<String, dynamic>();
          final locale = (map['locale'] ?? '').toString().toLowerCase();
          if (locale.contains('ko')) return map;
        }
        return null;
      }

      _maleVoice = pickVoice(false);
      _femaleVoice = pickVoice(true);
    } catch (_) {
      _voices = const [];
      _maleVoice = null;
      _femaleVoice = null;
    }
  }

  Future<void> _speakLocalLine(
    String text, {
    Duration timeout = const Duration(seconds: 12),
  }) async {
    final normalized = text.trim();
    if (normalized.isEmpty) return;

    await _initLocal();
    final completer = Completer<void>();
    _speakCompleter = completer;

    await _localTts.stop();
    await _localTts.speak(normalized);

    try {
      await completer.future.timeout(timeout);
    } catch (_) {
      // Best-effort: if completion doesn't fire, we don't want to hang forever.
    } finally {
      if (identical(_speakCompleter, completer)) {
        _speakCompleter = null;
      }
    }
  }

  Future<void> _speakLocalScript(
    String script, {
    Duration timeout = const Duration(seconds: 12),
  }) async {
    final normalized = script.trim();
    if (normalized.isEmpty) return;

    final lines = normalized
        .split(RegExp(r'\r?\n'))
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
    final hasDialogue = lines.any(_looksLikeDialogueLine);

    if (!hasDialogue) {
      await _speakLocalLine(normalized, timeout: timeout);
      return;
    }

    await _ensureVoicesLoaded();

    for (final line in lines) {
      final parsed = _parseDialogueLine(line);
      if (parsed.text.isEmpty) continue;

      if (parsed.role == 'male' && _maleVoice != null) {
        await _localTts
            .setVoice(_maleVoice!.map((k, v) => MapEntry(k, v.toString())));
      } else if (parsed.role == 'female' && _femaleVoice != null) {
        await _localTts
            .setVoice(_femaleVoice!.map((k, v) => MapEntry(k, v.toString())));
      }

      await _speakLocalLine(parsed.text, timeout: timeout);
    }
  }

  Future<Uint8List> _fetchCloudAudio(String text) async {
    final api = ref.read(apiClientProvider);
    return api.synthesizeKoreanSpeech(text);
  }

  Future<void> _cleanupCloudTempFile() async {
    final path = _cloudTempPath;
    _cloudTempPath = null;
    if (path == null || path.isEmpty) return;

    try {
      await File(path).delete();
    } catch (_) {
      // Ignore temp file cleanup failures.
    }
  }

  Future<void> _playCloudAudio(
    Uint8List bytes, {
    bool wait = false,
    Duration timeout = const Duration(seconds: 12),
  }) async {
    await _cleanupCloudTempFile();

    final file = File(
      '${Directory.systemTemp.path}/korean_tts_${DateTime.now().microsecondsSinceEpoch}.mp3',
    );
    await file.writeAsBytes(bytes, flush: true);
    _cloudTempPath = file.path;

    try {
      await _cloudPlayer.stop();
      final completion = Completer<void>();
      late final StreamSubscription<void> subscription;
      subscription = _cloudPlayer.onPlayerComplete.listen((_) {
        if (!completion.isCompleted) completion.complete();
      });

      await _cloudPlayer.play(DeviceFileSource(file.path));

      if (wait) {
        try {
          await completion.future.timeout(timeout);
        } catch (_) {
          // Best-effort: if playback completion doesn't fire, don't hang forever.
        }
      }

      await subscription.cancel();
      if (wait) {
        await _cleanupCloudTempFile();
      }
    } catch (_) {
      await _cleanupCloudTempFile();
      rethrow;
    }
  }

  Future<void> _speakCloud(
    String text, {
    bool wait = false,
    Duration timeout = const Duration(seconds: 12),
  }) async {
    final normalized = text.trim();
    if (normalized.isEmpty) return;

    final lines = normalized
        .split(RegExp(r'\r?\n'))
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();

    if (wait && lines.isNotEmpty) {
      for (final line in lines) {
        final parsed = _parseDialogueLine(line);
        if (parsed.text.isEmpty) continue;
        final audio = await _fetchCloudAudio(parsed.text);
        await _playCloudAudio(audio, wait: true, timeout: timeout);
      }
      return;
    }

    final audio = await _fetchCloudAudio(normalized);
    await _playCloudAudio(audio, wait: wait, timeout: timeout);
  }

  Future<void> speak(String text) async {
    final normalized = text.trim();
    if (normalized.isEmpty) return;

    if (_usePiperTts) {
      try {
        await _speakPiper(normalized);
      } catch (_) {
        await _speakLocalScript(normalized);
      }
      return;
    }

    if (_useCloudTts) {
      try {
        await _speakCloud(normalized);
      } catch (_) {
        await _speakLocalScript(normalized);
      }
      return;
    }

    await _initLocal();
    await _localTts.stop();
    await _localTts.speak(normalized);
  }

  Future<void> speakAndWait(
    String text, {
    Duration timeout = const Duration(seconds: 12),
  }) async {
    final normalized = text.trim();
    if (normalized.isEmpty) return;

    if (_usePiperTts) {
      try {
        await _speakPiper(normalized, wait: true, timeout: timeout);
      } catch (_) {
        await _speakLocalScript(normalized, timeout: timeout);
      }
      return;
    }

    if (_useCloudTts) {
      try {
        await _speakCloud(normalized, wait: true, timeout: timeout);
      } catch (_) {
        await _speakLocalScript(normalized, timeout: timeout);
      }
      return;
    }

    await _speakLocalScript(normalized, timeout: timeout);
  }

  Future<({String engineLabel, String? detail})> speakAndWaitWithEngine(
    String text, {
    Duration timeout = const Duration(seconds: 12),
  }) async {
    final normalized = text.trim();
    if (normalized.isEmpty) {
      return (engineLabel: 'No text', detail: null);
    }

    if (_usePiperTts) {
      try {
        await _speakPiper(normalized, wait: true, timeout: timeout);
        return (engineLabel: 'Piper offline (ONNX Runtime)', detail: null);
      } catch (error, stackTrace) {
        debugPrint('Piper speak failed: $error');
        debugPrintStack(stackTrace: stackTrace);
        await _speakLocalScript(normalized, timeout: timeout);
        return (
          engineLabel: 'Device TTS (fallback from Piper)',
          detail: error.toString(),
        );
      }
    }

    if (_useCloudTts) {
      try {
        await _speakCloud(normalized, wait: true, timeout: timeout);
        return (engineLabel: 'Google Cloud TTS', detail: null);
      } catch (error, stackTrace) {
        debugPrint('Google Cloud TTS speak failed: $error');
        debugPrintStack(stackTrace: stackTrace);
        await _speakLocalScript(normalized, timeout: timeout);
        return (
          engineLabel: 'Device TTS (fallback from Google Cloud TTS)',
          detail: error.toString(),
        );
      }
    }

    await _speakLocalScript(normalized, timeout: timeout);
    return (engineLabel: 'Device TTS', detail: null);
  }

  Future<void> stop() async {
    final c = _speakCompleter;
    if (c != null && !c.isCompleted) c.complete();
    _speakCompleter = null;
    await _localTts.stop();
    await _cloudPlayer.stop();
    await _piperPlayer.stop();
    await _cleanupPiperTempFile();
    await _cleanupCloudTempFile();
  }

  void dispose() {
    _piperTts?.free();
    _piperTts = null;
    unawaited(_localTts.stop());
    unawaited(_cloudPlayer.stop());
    unawaited(_piperPlayer.stop());
    unawaited(_cleanupCloudTempFile());
    unawaited(_cleanupPiperTempFile());
  }
}

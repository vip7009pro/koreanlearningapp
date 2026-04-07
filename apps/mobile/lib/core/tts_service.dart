import 'dart:async';
import 'dart:io';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_tts/flutter_tts.dart';

import '../providers/app_settings_provider.dart';
import 'api_client.dart';

final ttsProvider = Provider<TtsService>((ref) {
  final service = TtsService(ref);
  ref.onDispose(service.dispose);
  return service;
});

final deviceKoreanVoiceAvailableProvider = FutureProvider<bool>((ref) {
  return ref.read(ttsProvider).hasKoreanDeviceVoice();
});

const MethodChannel _ttsSettingsChannel = MethodChannel(
  'korean_learning_app/tts_settings',
);

class TtsService {
  final Ref ref;
  final FlutterTts _localTts = FlutterTts();
  final AudioPlayer _cloudPlayer = AudioPlayer();
  bool _initialized = false;
  Completer<void>? _speakCompleter;
  List<dynamic>? _voices;
  Map<String, dynamic>? _maleVoice;
  Map<String, dynamic>? _femaleVoice;
  String? _cloudTempPath;

  TtsService(this.ref);

  bool get _useCloudTts =>
      ref.read(appSettingsProvider).ttsMode ==
      AppSettingsNotifier.ttsModeNatural;

  String get selectedEngineLabel {
    if (_useCloudTts) return 'Google Cloud TTS';
    return 'Device TTS';
  }

  bool _isKoreanVoice(Map<String, dynamic> voice) {
    final name = (voice['name'] ?? '').toString().toLowerCase();
    final locale = (voice['locale'] ?? '').toString().toLowerCase();
    return locale.contains('ko') || name.contains('korean');
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
          if (!_isKoreanVoice(map)) continue;

          final name = (map['name'] ?? '').toString().toLowerCase();

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
          if (_isKoreanVoice(map)) return map;
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

  Future<bool> hasKoreanDeviceVoice() async {
    await _ensureVoicesLoaded();
    return (_voices ?? const [])
        .whereType<Map>()
        .map((voice) => voice.cast<String, dynamic>())
        .any(_isKoreanVoice);
  }

  Future<bool> openDeviceTtsSettings() async {
    if (!Platform.isAndroid) return false;

    try {
      final result = await _ttsSettingsChannel.invokeMethod<bool>(
        'openTtsSettings',
      );
      return result ?? true;
    } catch (_) {
      return false;
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
    await _cleanupCloudTempFile();
  }

  void dispose() {
    unawaited(_localTts.stop());
    unawaited(_cloudPlayer.stop());
    unawaited(_cleanupCloudTempFile());
  }
}

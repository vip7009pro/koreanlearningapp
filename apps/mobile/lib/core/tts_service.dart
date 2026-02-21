import 'dart:async';

import 'package:flutter_tts/flutter_tts.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final ttsProvider = Provider<TtsService>((ref) => TtsService());

class TtsService {
  final FlutterTts _tts = FlutterTts();
  bool _initialized = false;
  Completer<void>? _speakCompleter;

  Future<void> _init() async {
    if (_initialized) return;
    await _tts.setLanguage('ko-KR');
    await _tts.setSpeechRate(0.45);
    await _tts.setVolume(1.0);
    await _tts.setPitch(1.0);

    _tts.setCompletionHandler(() {
      final c = _speakCompleter;
      if (c != null && !c.isCompleted) c.complete();
    });
    _tts.setCancelHandler(() {
      final c = _speakCompleter;
      if (c != null && !c.isCompleted) c.complete();
    });
    _tts.setErrorHandler((_) {
      final c = _speakCompleter;
      if (c != null && !c.isCompleted) c.complete();
    });

    _initialized = true;
  }

  Future<void> speak(String text) async {
    await _init();
    await _tts.stop();
    await _tts.speak(text);
  }

  Future<void> speakAndWait(
    String text, {
    Duration timeout = const Duration(seconds: 12),
  }) async {
    await _init();

    final completer = Completer<void>();
    _speakCompleter = completer;

    await _tts.stop();
    await _tts.speak(text);

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

  Future<void> stop() async {
    final c = _speakCompleter;
    if (c != null && !c.isCompleted) c.complete();
    _speakCompleter = null;
    await _tts.stop();
  }
}

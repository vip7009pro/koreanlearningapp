# korean_learning_app

A new Flutter project.

## Offline Piper TTS

The app now supports a third TTS mode: Piper offline TTS powered by `sherpa_onnx`.

Place these files in `apps/mobile/assets/models/`:

- `piper-korean.onnx`
- `piper-korean.onnx.json`
- `tokens.txt` if your model requires it
- `espeak-ng-data/` with `phontab`, `phonindex`, `phondata`, and `intonations`

Then run `flutter pub get` and select `Piper offline (ONNX Runtime)` in Settings.

The other two modes remain available:

- Device TTS
- Google Cloud TTS

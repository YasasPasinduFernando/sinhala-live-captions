# Phase status

## Phase 0 — Planning

Complete. The workspace was empty. Flutter 3.47.1 and Android SDK 36 are installed.

## Phase 1 — Bootstrap

Complete.

- Application id: `com.sinhalacaptions.sinhala_live_captions`.
- `minSdk` 24.
- Pinned: `speech_to_text` 7.5.0, `whisper_cpp_flutter_plus` 0.5.1, `shared_preferences` 2.5.6.
- Manifest: `RECORD_AUDIO`, `INTERNET`, and a `RecognitionService` query. No camera, contacts, location, or background microphone service.

## Phase 2 — Architecture and UI

Complete. Home, live captions, settings, the session controller, and the demo engine remain. The demo engine is used by tests. Production starts the device or Whisper adapter.

## Phase 3 — Engines

Complete as an implementation. Sinhala accuracy on a phone is not complete.

- Device recognition uses one `speech_to_text` instance. Sinhala is accepted only when a returned locale has the language subtag `si`. English is not substituted.
- The Android service can end a listen after silence. The adapter may start another listen after the previous one finishes. It stops after five consecutive failures, and it does not restart after Stop. Listen options are a 3-second pause and a 30-second window. This is not continuous transcription.
- Offline mode uses `WhisperModelCatalog.tiny` (`ggml-tiny.bin`, multilingual, catalog size 77691713 bytes). The model downloads only from Settings. The catalog SHA-256 is the checksum. Cancelling the download stream can leave a `.part` file that a later download may resume. Removing the model is refused while a session is using it.
- Live Whisper uses `transcribeStream` on 16 kHz mono chunks from `WhisperRecorder`. Every new session requires language `si`, `detectLanguage: false`, and `translate: false`, then `WhisperPerformanceMode.responsive`. The package still forces streaming `no_context` on and `no_timestamps` off. `confirmedText` is a cumulative snapshot; only the new suffix is appended. `partialText` replaces the provisional line.
- Settings can select multilingual tiny or base. Base downloads only when the user starts that download. A model is not removed or replaced while a session is using it. Switching the selected file disposes the cached native engine.
- A real engine is not shown as listening until it reports that state. If device `listen` never reports listening, the status says the service did not start.
- Microphone permission is requested when a session starts, not when the app launches. A listening session stops if the app is paused, hidden, or detached. Returning to the app does not start the microphone. Stop stops the recorder and the stream task.

## Phase 4 — QA and documentation

Automated checks after the transcription-configuration fix, 14 October 2026:

- `flutter analyze`: no issues (6.0s).
- `flutter test`: 50 tests passed.
- `flutter build apk --debug`: succeeded in 16.0s with `GRADLE_USER_HOME=/home/yasas/.gradle`. APK: `build/app/outputs/flutter-apk/app-debug.apk` (180 MB).

Pins stayed at `speech_to_text` 7.5.0, `whisper_cpp_flutter_plus` 0.5.1, and `shared_preferences` 2.5.6.

An earlier debug APK was installed on Samsung SM-A346E (`RRCW506P5CV`). The home screen opened with `RECORD_AUDIO` denied. That install predates this fix. Spoken Sinhala was not retested, so the `[Spanish]` report and the inactive-microphone report are not closed.

## Still pending on a phone

- Sinhala locale check.
- Whisper download and checksum on the device.
- Real spoken Sinhala, including offline after the model is installed.
- Stop, mode switch, background, large text, and failure behavior from `TEST_PLAN.md`.

## Known limits

- Device recognition depends on the phone's speech service and installed languages.
- Offline Whisper needs a downloaded multilingual model. Tiny remains usable without base. Model presence and language `si` are not a measure of Sinhala accuracy.
- Package streaming always sets `no_context`. Short windows can still decode the wrong language as ordinary text, including text that looks like `[Spanish]`.
- Captions and audio are not saved.

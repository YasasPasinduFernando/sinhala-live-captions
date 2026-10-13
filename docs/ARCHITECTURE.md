# Architecture

Flutter UI and speech code are separate. State uses `ChangeNotifier`. Captions stay in memory for the current process.

## Layout

- `lib/app/` — `MaterialApp`, theme, and lifecycle. A listening session stops when the app is paused, hidden, or detached. Resume does not start the microphone.
- `lib/core/` — recognition mode, session phase, and user-facing strings.
- `lib/features/home/` — home screen.
- `lib/features/captions/` — live captions. Leaving the screen stops the session.
- `lib/features/settings/` — saved preferences and Whisper model controls.
- `lib/services/speech/` — `SpeechEngine`, `CaptionSessionController`, device and Whisper adapters, and `DemoSpeechEngine` for tests.

Production `main.dart` creates one `SpeechToText` client, one `WhisperModelManager`, and one runtime. The demo engine is not the production default.

## Speech contract

`SpeechEngine` reports availability, emits status, replaces provisional text, appends one confirmed segment, stops, cancels, and disposes. There is no pause.

Device recognition uses `speech_to_text` 7.5.0 `SpeechListenOptions`: partial results, dictation mode, a 3-second pause, and a 30-second listen window. Sinhala is selected only from locales the plugin returns. The adapter may listen again after the previous listen has finished. Stop blocks that restart. Cancel does not keep an in-flight final.

Offline Whisper uses `WhisperModelCatalog.tiny` (`ggml-tiny.bin`, multilingual, catalog SHA-256). Download runs only from Settings. `findCatalogModel` accepts the file only when the checksum matches. Cancelling the download stream can leave a `.part` file; a later download can continue it when the server accepts a range request. The model cannot be removed while a session is using it.

Live Whisper calls `WhisperEngine.load` and `transcribeMicrophone` with language `si` and `WhisperPerformanceMode.responsive`. `confirmedText` is a cumulative snapshot, so the adapter emits only the new suffix. `partialText` replaces the provisional line. A new session resets that snapshot.

`DemoSpeechEngine` is for tests. It never opens the microphone, and every sample line starts with `[උදාහරණය]`.

## Session rules

- One engine owns the microphone.
- Confirmed text is append-only. The same confirmed string is not added twice in a row.
- Provisional text replaces the previous provisional text.
- Stop lets the engine flush a final result, then ignores later events.
- Changing mode stops and disposes the current engine before the mode value changes. It does not start the new engine. Confirmed captions stay in memory.
- Clear removes displayed text only. It does not write a file.

## Settings and privacy

`shared_preferences` stores only:

- `caption_font_size` (24–48, default 30)
- `theme_preference` (`light` or `dark`)
- `high_contrast`
- `recognition_mode` (`device` or `whisper`)

The manifest requests `RECORD_AUDIO` and `INTERNET`, and queries `RecognitionService`. There is no background microphone service. Device recognition may send audio to the phone's speech service, which may use the network. After the Whisper model is on the phone, that mode keeps audio on the device. Model download uses the network. Captions and recordings are not stored.

Android application id `com.sinhalacaptions.sinhala_live_captions`, minimum SDK 24.

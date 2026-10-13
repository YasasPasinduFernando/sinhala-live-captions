# Roadmap

## Done

- Android project, pinned packages, minimum SDK 24, microphone and internet permissions, and a speech-service query.
- Accessible home, captions, and settings screens, with saved font, theme, contrast, and mode.
- In-memory session controller. Confirmed text is appended once. Provisional text is replaced.
- Device recognition through `speech_to_text` 7.5.0, limited to a real `si` locale.
- Offline Whisper through `whisper_cpp_flutter_plus` 0.5.1, multilingual tiny model, explicit download, catalog checksum, and live microphone transcription.
- Automated tests with fakes, analyzer, and a debug APK. See `PHASE_STATUS.md` for the latest command results.

## Still to do on a phone

- Confirm the phone returns a Sinhala locale, or that the app refuses device recognition when it does not.
- Download the tiny model on the phone and confirm the checksum state.
- Transcribe real spoken Sinhala, including with the network disabled after the model is installed.
- Check stop, mode switching, backgrounding, large text, and failure messages. The checklist is in `TEST_PLAN.md`.

## Not in this version

- Google Cloud Speech-to-Text.
- Accounts, analytics, or a backend.
- Saved caption history.
- A measured Sinhala accuracy, latency, or battery figure. Those stay empty until a phone test records them.

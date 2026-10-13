# Product brief

Sinhala Live Captions is an Android app for a Deaf or hard-of-hearing person. It shows spoken Sinhala as large text on the phone.

Application id: `com.sinhalacaptions.sinhala_live_captions`. Minimum Android SDK: 24.

Pinned packages:

- `speech_to_text` 7.5.0 — the phone's speech-recognition service, not Google Cloud Speech-to-Text.
- `whisper_cpp_flutter_plus` 0.5.1 — offline Whisper.
- `shared_preferences` 2.5.6 — font size, theme, contrast, and recognition mode.

## What the app does

- Home, live captions, and settings, with Sinhala labels and large controls.
- Device recognition when the phone returns a locale whose language subtag is `si` (`si`, `si_LK`, or `si-LK`). English is not used in its place.
- Offline Whisper with the multilingual tiny catalog model, language code `si`, after the user downloads it from Settings.
- Font size 24–48 (default 30), light or dark theme, and high contrast. Those choices, and the selected mode, are saved on the phone.
- Stop keeps confirmed captions in memory and releases the microphone. Leaving the app while it is listening also stops the session. Opening the app does not start the microphone.

## What it does not do

- It does not guarantee continuous captions. The Android speech service can stop after silence. The app may start another listen, and it stops trying after five consecutive failures.
- It does not download the Whisper model until the user asks. A verified model file is not a Sinhala accuracy score.
- It does not save captions or audio.
- It does not use Google Cloud Speech-to-Text, a backend, accounts, or analytics.

Sinhala accuracy and on-phone performance have not been measured.

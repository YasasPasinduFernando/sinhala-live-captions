# Test plan

## Automated

These tests do not use a microphone and do not download a Whisper model.

They cover:

- Session controller: confirmed append, provisional replacement, duplicate suppression, clear, one active engine, mode switch, stop, and dispose.
- Settings persistence and font clamp.
- Widget flows: home limits, navigation, font, theme, contrast, mode, demo start and stop, errors, long Sinhala wrapping, and a small screen.
- Device adapter fakes: missing `si` locale, initialization failure, permission failure, partial replacement, final de-duplication, five-failure restart limit, stop blocking restart, mode switch, a listen that never reports listening, and events after dispose.
- Whisper fakes: multilingual tiny and base catalog identity, `si` with detection and translation off after responsive mode, the selected model passed to the runtime, cumulative confirmed suffix, partial replacement, final update, stop versus cancel, download progress, retry, failure, cancellation, removal while in use, load failure, and a second microphone start.

These fakes do not prove native audio or Sinhala accuracy.

Latest run on 14 October 2026, Flutter at `/home/yasas/.local/flutter/bin/flutter`:

- Direct pins stayed at `shared_preferences` 2.5.6, `speech_to_text` 7.5.0, and `whisper_cpp_flutter_plus` 0.5.1.
- `flutter analyze`: no issues (6.0s).
- `flutter test`: 50 tests passed.
- `flutter build apk --debug`: succeeded in 16.0s. APK size 180 MB.

## Phone status

`adb devices -l` showed Samsung SM-A346E, serial `RRCW506P5CV`, as `device`. An earlier debug APK installed and the home screen opened. Microphone permission stayed denied. The user then reported offline text beginning with `[Spanish]` and a device session whose microphone was not active. The checklist and the known-phrase retest below have not been run on the APK built after the configuration fix.

## Install

```bash
adb devices -l
adb install -r "/home/yasas/Desktop/sinhala wisper/build/app/outputs/flutter-apk/app-debug.apk"
adb shell am start -n com.sinhalacaptions.sinhala_live_captions/.MainActivity
```

On launch, the microphone indicator must stay off until Start is pressed. Permission is requested at Start, not at launch.

## Physical checklist — not run

Mark each item pass, fail, or not run. Do not fill accuracy or delay until you observed it.

1. Device recognition: the phone returns a Sinhala locale (`si`, `si_LK`, or `si-LK`) and captions come from that session.
2. If Sinhala is missing, the app says so and does not show another language as Sinhala. Offline Whisper is offered only after its model is verified.
3. Settings shows the catalog size, the download is started by the user, and the model reaches the verified state. A bad or incomplete file is rejected.
4. Offline Whisper transcribes real spoken Sinhala with language `si`.
5. After the model is verified, turn off Wi-Fi and mobile data. Offline transcription still runs. Device recognition may fail without a network; record which one happened.
6. Stop keeps the confirmed caption and the microphone indicator turns off. A system recording indicator, if the phone shows one, also clears.
7. Switching between device and offline stops the first session before the other can listen. Confirmed text remains until Clear.
8. Leave the app while it is listening. The session stops. Opening the app again does not start the microphone.
9. Set the largest font. Captions stay readable and the screen can scroll. Check a narrow screen if one is available.
10. Deny the microphone, or remove Sinhala from the speech service. The app shows an error and does not keep a listening indicator. It does not crash.

## Known-phrase retest — not run

Use a quiet room and Samsung SM-A346E. Install the debug APK from this tree. Test device recognition and offline Whisper separately. Do not write a transcript until you heard the phrase and read the caption.

For each mode:

1. Open Settings and select that mode. For Whisper, select `tiny` first. Download it only if it is not already verified. Do not download `base` until tiny has been recorded on the three phrases.
2. Open live captions and press Start.
3. Allow the microphone if asked. Confirm the status says the microphone is active. In a debug build, also read the diagnostics line: device locale and `listening=true`, or Whisper `language=si`, `detectLanguage=false`, `translate=false`, a chunk count above zero, and a peak that is not stuck at zero while you speak.
4. Say one phrase, wait for the caption, then press Stop. Confirm the microphone indicator turns off.
5. Write the reference and the exact caption. Repeat for the next phrase with a new Start.

Phrases:

1. `මගේ නම යසස්.`
2. `මට වතුර වීදුරුවක් දෙන්න.`
3. `මම අද ගෙදර යනවා.`

If device recognition lists no `si` locale, record the diagnostics locale list and stop. Do not treat another language as Sinhala.

If tiny captions are still unrelated, download multilingual `base` from Settings, select it, and repeat the same three phrases. Record both model ids. Do not treat base as better until those rows are filled.

## Observation sheet

Say a known sentence, then write what the app showed. Approximate delay is the time from the start of speech until the caption changes. Leave a cell empty when it was not measured.

| Clip | Mode | Reference text | Caption shown | Errors (wrong, missing, or duplicated words) | Approximate delay | Notes |
| --- | --- | --- | --- | --- | --- | --- |
| Quiet room | device |  |  |  |  |  |
| Quiet room | whisper |  |  |  |  |  |
| Conversation | device |  |  |  |  |  |
| Conversation | whisper |  |  |  |  |  |
| Faster speech | whisper |  |  |  |  |  |
| Sinhala with English words | whisper |  |  |  |  |  |
| Second speaker | whisper |  |  |  |  |  |
| Short pause, then more speech | device |  |  |  |  |  |
| Longer session | device |  |  |  |  |  |
| Network off after model download | whisper |  |  |  |  |  |

Also note, without inventing a number: whether the session stopped by itself, whether Stop released the microphone, whether mode switching overlapped sessions, CPU or heat if it was obvious, and any crash.

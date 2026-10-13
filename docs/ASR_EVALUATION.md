# Speech evaluation

No speech-recognition accuracy, latency, or battery figure has been measured. A later debug build does not mean the Samsung SM-A346E transcription bug is fixed.

The device adapter and the offline Whisper adapter are implemented. Automated tests use fakes. They do not listen to a microphone, download a model, or recognize Sinhala.

## Whisper language path in 0.5.1

Inspected package source: `whisper_cpp_flutter_plus` 0.5.1.

`TranscribeOptions` defaults to `language: 'auto'`, `detectLanguage: false`, and `translate: false`. `withPerformanceMode(WhisperPerformanceMode.responsive)` copies threads, greedy decoding, and timestamp flags. It does not replace `language`, `detectLanguage`, or `translate`.

The live path is `WhisperEngine.transcribeStream`, not a second microphone task with default options. `_transcribeInternal` writes `s('language', options.language)`, `detect_language` from `options.detectLanguage`, and `translate` from `options.translate`. When streaming is true it forces `token_timestamps` on, `single_segment` off, `no_context` on, and `no_timestamps` off. That override does not set the language to `auto`.

Native `wf_job_set_string` stores the language string, and `wf_run` passes it to whisper.cpp. Auto-detection runs when the language is null, empty, `"auto"`, or `detect_language` is true. The language table includes `{ "si", { 63, "sinhala" } }`. Extra vocabulary tokens print like `[_LANG_es]`, not `[Spanish]`.

The previous app already passed `TranscribeOptions(language: 'si').withPerformanceMode(responsive)` into `transcribeMicrophone`. The Spanish-looking text is therefore not explained by a missing language argument or by responsive mode clearing `si`. The leading hypothesis is tiny-model hallucination on short, quiet, or non-speech windows. Default streaming confirms text after a 4-second lag, so a bad window can become confirmed text. `suppressNonSpeechTokens` was previously left false. The new session sets it true and sets `logProbabilityThreshold` to `-0.8`. Those are configuration changes, not a measured accuracy fix.

Each new offline session now rejects any config that is not `language: 'si'`, `detectLanguage: false`, and `translate: false`. The selected file is reloaded when the model path changes. Debug builds show the model id, file name, those three flags, audio chunk count, and a peak/RMS level. They do not log raw audio.

## Models

`WhisperModelCatalog.tiny` is multilingual `ggml-tiny.bin`, SHA-256 `be07e048e1e599ad46341c8d2a135645097a538221678b7acdd1b1919c6e1b21`, catalog size 77691713 bytes. `WhisperModelCatalog.base` is multilingual `ggml-base.bin`, catalog size 147951465 bytes. Settings can select either id. Base is not downloaded until the user starts that download. English-only `tinyEnglish` and `baseEnglish` are not offered. A checksum match means the file matches the catalog. It does not mean the transcription is accurate. Base has not been compared with tiny on the same spoken phrases.

## Device recognition

This uses the Android speech service through `speech_to_text` 7.5.0. It is not Google Cloud Speech-to-Text. `listen` is called only with a discovered locale whose language subtag is `si`. English is not substituted.

A previous session could show listening while the microphone was not active: the controller treated a still-initializing real engine as listening, and the status stayed on the idle “microphone not active” text when `listen` never reported `listening`. Real engines are no longer promoted that way. If no listening status arrives, the app reports that the service did not start. A missing Sinhala locale stays unavailable and does not start `listen`. Debug builds list initialization, permission, discovered locale ids, the selected locale, and whether listening was reported.

## Phone

On 14 October 2026 an earlier debug APK was installed on Samsung SM-A346E (`RRCW506P5CV`). The home screen opened with microphone permission denied. No spoken Sinhala was tested. The user later reported `[Spanish]` and unrelated phonetic text from offline Whisper, and a device-mode screen that said the microphone was not active. Those reports were not reproduced in this session. The three reference phrases in `TEST_PLAN.md` still need a quiet-room retest.

## How to record a phone result

Use the sheet in `TEST_PLAN.md`. For each clip, write the reference sentence, the caption the app showed, words that were wrong or missing, and the approximate time from the start of speech until the caption changed. Leave a cell blank when it was not observed. Do not copy a number into this file unless that phone test was actually run.

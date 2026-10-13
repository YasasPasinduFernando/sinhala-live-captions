import 'package:whisper_cpp_flutter_plus/whisper_cpp_flutter_plus.dart';

import 'whisper_ports.dart';

/// Builds the options passed to `transcribeStream` / `transcribeMicrophone`.
///
/// `withPerformanceMode` changes threads and timestamps only. Language,
/// detection, and translation are copied through. The package's streaming
/// path still forces `no_timestamps` off and `no_context` on inside
/// `_transcribeInternal`; that override does not replace [language].
TranscribeOptions sinhalaTranscribeOptions(WhisperSessionConfig config) {
  return TranscribeOptions(
    language: config.language,
    detectLanguage: config.detectLanguage,
    translate: config.translate,
    suppressNonSpeechTokens: true,
    logProbabilityThreshold: -0.8,
  ).withPerformanceMode(WhisperPerformanceMode.responsive);
}

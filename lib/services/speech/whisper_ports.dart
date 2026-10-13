/// Download progress. [fraction] is null when the total size is unknown.
class DownloadTick {
  const DownloadTick(this.fraction);

  final double? fraction;
}

enum WhisperModelLookupKind { missing, ready, invalid }

class WhisperModelLookup {
  const WhisperModelLookup._(this.kind, this.path);

  const WhisperModelLookup.missing()
    : this._(WhisperModelLookupKind.missing, null);

  const WhisperModelLookup.ready(String path)
    : this._(WhisperModelLookupKind.ready, path);

  const WhisperModelLookup.invalid()
    : this._(WhisperModelLookupKind.invalid, null);

  final WhisperModelLookupKind kind;
  final String? path;
}

/// One multilingual catalog model the user can choose.
class WhisperModelSpec {
  const WhisperModelSpec({
    required this.id,
    required this.fileName,
    required this.approximateBytes,
  });

  final String id;
  final String fileName;
  final int approximateBytes;

  String get sizeLabel {
    final megabytes = approximateBytes / (1024 * 1024);
    return megabytes.toStringAsFixed(1);
  }
}

/// Options for one Sinhala transcription session.
///
/// [language] must stay `si`. Detection and translation stay off.
class WhisperSessionConfig {
  const WhisperSessionConfig({
    required this.modelPath,
    required this.modelId,
    this.language = 'si',
    this.detectLanguage = false,
    this.translate = false,
  });

  final String modelPath;
  final String modelId;
  final String language;
  final bool detectLanguage;
  final bool translate;
}

/// Model file operations. The production store uses the package catalog.
abstract class WhisperModelStore {
  List<WhisperModelSpec> get availableModels;

  String get modelId;

  Future<void> select(String id);

  int get approximateBytes;

  String get fileName;

  Future<WhisperModelLookup> lookup();

  Stream<DownloadTick> download();

  Future<void> delete();

  void close();
}

/// Microphone counters. No samples are retained.
class AudioCaptureStats {
  const AudioCaptureStats({
    this.chunks = 0,
    this.samples = 0,
    this.sampleRate = 0,
    this.silentChunks = 0,
    this.peak = 0,
    this.rms = 0,
    this.lastBufferAt,
  });

  final int chunks;
  final int samples;
  final int sampleRate;
  final int silentChunks;
  final double peak;
  final double rms;
  final DateTime? lastBufferAt;

  Duration get captured {
    if (sampleRate <= 0 || samples <= 0) {
      return Duration.zero;
    }
    return Duration(microseconds: samples * 1000000 ~/ sampleRate);
  }

  Duration? ageOfLastBuffer(DateTime now) {
    final at = lastBufferAt;
    if (at == null) {
      return null;
    }
    return now.difference(at);
  }
}

/// One completed record-then-transcribe pass. PCM is not kept.
class WhisperProbeResult {
  const WhisperProbeResult({
    required this.language,
    required this.modelId,
    required this.modelFile,
    required this.detectLanguage,
    required this.translate,
    required this.capture,
    required this.transcript,
    required this.elapsed,
    this.failure,
  });

  final String language;
  final String modelId;
  final String modelFile;
  final bool detectLanguage;
  final bool translate;
  final AudioCaptureStats capture;
  final String transcript;
  final Duration elapsed;
  final String? failure;
}

/// One live transcription snapshot, independent of the plugin types.
class WhisperCaptionUpdate {
  const WhisperCaptionUpdate({
    required this.confirmedText,
    required this.partialText,
    required this.isFinal,
    this.audioChunks = 0,
    this.audioPeak = 0,
  });

  final String confirmedText;
  final String partialText;
  final bool isFinal;
  final int audioChunks;
  final double audioPeak;
}

abstract class WhisperLiveTask {
  Stream<WhisperCaptionUpdate> get updates;

  Future<WhisperCaptionUpdate> stop();

  Future<void> cancel();
}

abstract class WhisperRuntime {
  Future<WhisperLiveTask> startMicrophone(WhisperSessionConfig config);

  Future<void> release();
}

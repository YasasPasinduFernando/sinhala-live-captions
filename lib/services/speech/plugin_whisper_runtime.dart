import 'dart:math' as math;
import 'dart:typed_data';

import 'package:whisper_cpp_flutter_plus/whisper_cpp_flutter_plus.dart';

import 'sinhala_transcribe_options.dart';
import 'whisper_ports.dart';

/// Loads the verified model and starts one 16 kHz microphone stream.
///
/// A different model path disposes the previous native engine before load.
/// The recorder is stopped on stop, cancel, and release.
class PluginWhisperRuntime implements WhisperRuntime {
  WhisperEngine? _engine;
  String? _loadedPath;
  var _busy = false;

  @override
  Future<WhisperLiveTask> startMicrophone(WhisperSessionConfig config) async {
    if (_busy) {
      throw StateError('A microphone session is already active');
    }
    if (config.language != 'si' || config.detectLanguage || config.translate) {
      throw ArgumentError.value(
        config.language,
        'language',
        'Sinhala sessions require language si with detection and translation off',
      );
    }
    _busy = true;
    final recorder = WhisperRecorder();
    try {
      if (!await recorder.requestPermission()) {
        throw const WhisperException('Microphone permission was not granted');
      }
      if (_loadedPath != config.modelPath) {
        _engine?.dispose();
        _engine = null;
        _loadedPath = null;
      }
      _engine ??= await WhisperEngine.load(config.modelPath);
      _loadedPath = config.modelPath;
      final meter = _AudioMeter();
      final audio = (await recorder.start(
        sampleRate: 16000,
        chunkMilliseconds: 100,
      )).map((chunk) {
        meter.add(chunk.samples);
        return chunk;
      });
      final task = _engine!.transcribeStream(
        audio,
        options: sinhalaTranscribeOptions(config),
      );
      return _OwnedWhisperTask(
        task: task,
        recorder: recorder,
        meter: meter,
        onDone: () => _busy = false,
      );
    } catch (_) {
      _busy = false;
      await recorder.stop();
      rethrow;
    }
  }

  @override
  Future<void> release() async {
    if (_busy) {
      return;
    }
    _engine?.dispose();
    _engine = null;
    _loadedPath = null;
  }
}

class _AudioMeter {
  var chunks = 0;
  var peak = 0.0;

  void add(Float32List samples) {
    if (samples.isEmpty) {
      return;
    }
    chunks += 1;
    var sum = 0.0;
    var localPeak = 0.0;
    for (final sample in samples) {
      final value = sample.abs();
      if (value > localPeak) {
        localPeak = value;
      }
      sum += sample * sample;
    }
    final rms = math.sqrt(sum / samples.length);
    peak = math.max(peak, math.max(localPeak, rms));
  }
}

class _OwnedWhisperTask implements WhisperLiveTask {
  _OwnedWhisperTask({
    required this._task,
    required this._recorder,
    required this._meter,
    required this._onDone,
  });

  final WhisperStreamTask _task;
  final WhisperRecorder _recorder;
  final _AudioMeter _meter;
  final void Function() _onDone;
  var _ended = false;

  void _finish() {
    if (_ended) {
      return;
    }
    _ended = true;
    _onDone();
  }

  WhisperCaptionUpdate _map(WhisperStreamUpdate update) {
    return WhisperCaptionUpdate(
      confirmedText: update.confirmedText,
      partialText: update.partialText,
      isFinal: update.isFinal,
      audioChunks: _meter.chunks,
      audioPeak: _meter.peak,
    );
  }

  @override
  Stream<WhisperCaptionUpdate> get updates => _task.updates.map(_map);

  @override
  Future<WhisperCaptionUpdate> stop() async {
    try {
      await _recorder.stop();
      return _map(await _task.stop());
    } finally {
      _finish();
    }
  }

  @override
  Future<void> cancel() async {
    try {
      await _recorder.stop();
      await _task.cancel();
    } finally {
      _finish();
    }
  }
}

import 'dart:async';

import 'package:sinhala_live_captions/core/app_strings.dart';
import 'package:sinhala_live_captions/core/recognition_mode.dart';
import 'package:sinhala_live_captions/services/speech/speech_engine.dart';

/// Test double that emits only the events a test sends.
class ScriptedSpeechEngine implements SpeechEngine {
  ScriptedSpeechEngine(this.mode, {this.startGate});

  @override
  final RecognitionMode mode;

  final Completer<void>? startGate;
  final StreamController<SpeechEngineEvent> _events =
      StreamController<SpeechEngineEvent>.broadcast(sync: true);

  var started = 0;
  var stopped = 0;
  var cancelled = 0;
  var disposed = 0;

  @override
  String get diagnostics => '';

  @override
  EngineCapabilities get capabilities => EngineCapabilities(
    displayName: mode.name,
    isDemonstration: true,
    usesMicrophone: false,
    supportsProvisionalText: true,
    supportsPause: false,
    requiresLocalModel: mode == RecognitionMode.whisper,
    maySendAudioOffDevice: false,
  );

  @override
  Stream<SpeechEngineEvent> get events => _events.stream;

  @override
  Future<EngineAvailability> checkAvailability() async {
    return const EngineAvailability(
      isAvailable: true,
      message: AppStrings.demoBanner,
    );
  }

  void emit(SpeechEngineEvent event) {
    if (!_events.isClosed) {
      _events.add(event);
    }
  }

  @override
  Future<void> start() async {
    started += 1;
    await startGate?.future;
  }

  @override
  Future<void> stop() async {
    stopped += 1;
  }

  @override
  Future<void> cancel() async {
    cancelled += 1;
  }

  @override
  Future<void> dispose() async {
    disposed += 1;
    if (!_events.isClosed) {
      await _events.close();
    }
  }
}

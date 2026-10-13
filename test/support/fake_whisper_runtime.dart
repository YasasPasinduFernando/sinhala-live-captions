import 'dart:async';

import 'package:sinhala_live_captions/services/speech/whisper_ports.dart';

class FakeWhisperTask implements WhisperLiveTask {
  final StreamController<WhisperCaptionUpdate> updatesController =
      StreamController<WhisperCaptionUpdate>.broadcast(sync: true);

  var stopCount = 0;
  var cancelCount = 0;
  WhisperCaptionUpdate stopResult = const WhisperCaptionUpdate(
    confirmedText: '',
    partialText: '',
    isFinal: true,
  );

  @override
  Stream<WhisperCaptionUpdate> get updates => updatesController.stream;

  void add(WhisperCaptionUpdate update) {
    if (!updatesController.isClosed) {
      updatesController.add(update);
    }
  }

  @override
  Future<WhisperCaptionUpdate> stop() async {
    stopCount += 1;
    return stopResult;
  }

  @override
  Future<void> cancel() async {
    cancelCount += 1;
  }
}

class FakeWhisperRuntime implements WhisperRuntime {
  FakeWhisperRuntime(this.task);

  final FakeWhisperTask task;
  var starts = 0;
  var releases = 0;
  var failLoad = false;
  var denyPermission = false;
  WhisperSessionConfig? lastConfig;

  @override
  Future<WhisperLiveTask> startMicrophone(WhisperSessionConfig config) async {
    lastConfig = config;
    if (starts > 0 && releases == 0) {
      throw StateError('A microphone session is already active');
    }
    starts += 1;
    if (denyPermission) {
      throw StateError('Microphone permission was not granted');
    }
    if (failLoad) {
      throw StateError('model load failed');
    }
    return task;
  }

  @override
  Future<void> release() async {
    releases += 1;
  }
}

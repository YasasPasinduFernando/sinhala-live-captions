import 'dart:async';

import 'package:sinhala_live_captions/services/speech/device_speech_client.dart';

class FakeDeviceSpeechClient implements DeviceSpeechClient {
  var initializeResult = true;
  var permission = true;
  var locales = <String>['en_US', 'si_LK'];
  var listening = false;
  @override
  String trace = '';
  var listenCount = 0;
  var stopCount = 0;
  var cancelCount = 0;
  var failListen = false;
  var errorOnListen = false;
  var silentListen = false;
  String? stopFinal;
  final requestedLocales = <String>[];
  Duration? lastListenFor;
  String? scriptedResult;
  var scriptedFinal = true;
  String? scriptedError;
  var scriptedPermanent = false;
  Completer<void>? listenGate;

  void Function(String status)? onStatus;
  void Function(String message, bool permanent)? onError;
  void Function(String words, bool isFinal)? onResult;

  @override
  Future<bool> initialize() async => initializeResult;

  @override
  Future<bool> hasPermission() async => permission;

  @override
  Future<List<String>> localeIds() async => locales;

  @override
  bool get isListening => listening;

  @override
  void setHandlers({
    required void Function(String status) onStatus,
    required void Function(String message, bool permanent) onError,
    required void Function(String words, bool isFinal) onResult,
  }) {
    this.onStatus = onStatus;
    this.onError = onError;
    this.onResult = onResult;
  }

  @override
  Future<void> listen({
    required String localeId,
    Duration listenFor = const Duration(seconds: 30),
    Duration pauseFor = const Duration(seconds: 3),
  }) async {
    listenCount += 1;
    requestedLocales.add(localeId);
    lastListenFor = listenFor;
    final gate = listenGate;
    if (gate != null) {
      await gate.future;
    }
    if (failListen) {
      throw StateError('listen failed');
    }
    if (silentListen) {
      return;
    }
    listening = true;
    if (errorOnListen) {
      onError?.call('error_network', false);
      listening = false;
      onStatus?.call('done');
      return;
    }
    onStatus?.call('listening');
    if (scriptedError != null) {
      onError?.call(scriptedError!, scriptedPermanent);
    }
    if (scriptedResult != null) {
      onResult?.call(scriptedResult!, scriptedFinal);
    }
  }

  @override
  Future<void> stop() async {
    stopCount += 1;
    listening = false;
    final finalText = stopFinal;
    if (finalText != null) {
      onResult?.call(finalText, true);
    }
  }

  @override
  Future<void> cancel() async {
    cancelCount += 1;
    listening = false;
  }

  void emitPartial(String words) => onResult?.call(words, false);

  void emitFinal(String words) => onResult?.call(words, true);

  void emitError(String message, {bool permanent = false}) {
    onError?.call(message, permanent);
  }

  void emitDone() {
    listening = false;
    onStatus?.call('done');
  }
}

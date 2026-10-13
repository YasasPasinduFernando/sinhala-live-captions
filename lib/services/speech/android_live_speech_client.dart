import 'dart:async';

import 'package:flutter/services.dart';

import 'device_speech_client.dart';

/// Android `SpeechRecognizer` client that requests `si-LK` directly.
///
/// The plugin locale list can omit Sinhala on phones where Google's
/// recognizer still accepts it. This client does not substitute English.
class AndroidLiveSpeechClient implements DeviceSpeechClient {
  AndroidLiveSpeechClient({
    MethodChannel? methods,
    EventChannel? events,
  }) : _methods = methods ?? const MethodChannel(_methodName),
       _events = events ?? const EventChannel(_eventName);

  static const _methodName = 'com.sinhalacaptions/live_speech';
  static const _eventName = 'com.sinhalacaptions/live_speech_events';

  final MethodChannel _methods;
  final EventChannel _events;

  StreamSubscription<dynamic>? _subscription;
  void Function(String status)? _onStatus;
  void Function(String message, bool permanent)? _onError;
  void Function(String words, bool isFinal)? _onResult;

  var _available = false;
  var _permission = false;
  var _listening = false;
  String _servicePackage = '';

  String get servicePackage => _servicePackage;

  @override
  String get trace => 'service=$_servicePackage';

  void _ensureEvents() {
    _subscription ??= _events.receiveBroadcastStream().listen(_onEvent);
  }

  void _onEvent(Object? raw) {
    if (raw is! Map) {
      return;
    }
    final type = raw['type'];
    if (type == 'status') {
      final status = raw['status'] as String? ?? '';
      _listening = status == 'listening';
      _onStatus?.call(status);
      return;
    }
    if (type == 'result') {
      _onResult?.call(
        raw['words'] as String? ?? '',
        raw['final'] == true,
      );
      return;
    }
    if (type == 'error') {
      _listening = false;
      _onError?.call(
        raw['message'] as String? ?? 'error_client',
        raw['permanent'] == true,
      );
    }
  }

  @override
  Future<bool> initialize() async {
    _ensureEvents();
    try {
      final raw = await _methods.invokeMethod<Object?>('prepare');
      if (raw is Map) {
        _permission = raw['permission'] == true;
        _available = raw['available'] == true;
        _servicePackage = raw['service'] as String? ?? '';
      }
    } on PlatformException {
      _permission = false;
      _available = false;
    } on MissingPluginException {
      _permission = false;
      _available = false;
    }
    return _available && _permission;
  }

  @override
  Future<bool> hasPermission() async => _permission;

  @override
  Future<List<String>> localeIds() async {
    if (!_available) {
      return const [];
    }
    return const ['si-LK'];
  }

  @override
  bool get isListening => _listening;

  @override
  void setHandlers({
    required void Function(String status) onStatus,
    required void Function(String message, bool permanent) onError,
    required void Function(String words, bool isFinal) onResult,
  }) {
    _onStatus = onStatus;
    _onError = onError;
    _onResult = onResult;
  }

  @override
  Future<void> listen({
    required String localeId,
    Duration listenFor = const Duration(seconds: 30),
    Duration pauseFor = const Duration(seconds: 3),
  }) async {
    _listening = false;
    await _methods.invokeMethod<void>('start');
  }

  @override
  Future<void> stop() async {
    _listening = false;
    await _methods.invokeMethod<void>('stop');
  }

  @override
  Future<void> cancel() async {
    _listening = false;
    await _methods.invokeMethod<void>('cancel');
  }
}

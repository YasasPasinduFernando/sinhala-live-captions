import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Whether the phone currently has a network that can use the internet.
class NetworkStatus extends ChangeNotifier {
  NetworkStatus({MethodChannel? methods, EventChannel? events})
    : _methods = methods ?? const MethodChannel(_methodName),
      _events = events ?? const EventChannel(_eventName);

  static const _methodName = 'com.sinhalacaptions/network';
  static const _eventName = 'com.sinhalacaptions/network_events';

  final MethodChannel _methods;
  final EventChannel _events;

  StreamSubscription<dynamic>? _subscription;
  bool? _online;

  /// Null until the first status arrives, or when the platform is unavailable.
  bool? get online => _online;

  Future<void> start() async {
    _subscription ??= _events.receiveBroadcastStream().listen((raw) {
      if (raw is bool) {
        _set(raw);
      }
    }, onError: (Object _) {});
    try {
      final raw = await _methods.invokeMethod<Object?>('status');
      if (raw is bool) {
        _set(raw);
      }
    } on PlatformException {
      // The usage explanation still shows without a live connection state.
    } on MissingPluginException {
      // Widget tests and non-Android hosts do not implement this channel.
    }
  }

  void _set(bool value) {
    if (_online == value) {
      return;
    }
    _online = value;
    notifyListeners();
  }

  @override
  void dispose() {
    unawaited(_subscription?.cancel());
    _subscription = null;
    super.dispose();
  }
}

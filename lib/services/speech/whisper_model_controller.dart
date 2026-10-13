import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../core/app_strings.dart';
import 'whisper_ports.dart';

enum WhisperModelPhase {
  missing,
  downloading,
  ready,
  failed,
  invalid,
  removing,
}

/// Shared model status for settings and the offline engine.
///
/// Nothing is downloaded until [download] is called.
class WhisperModelController extends ChangeNotifier {
  WhisperModelController(this._store);

  final WhisperModelStore _store;

  WhisperModelPhase _phase = WhisperModelPhase.missing;
  double? _progress;
  String? _error;
  String? _path;
  var _users = 0;
  var _disposed = false;
  StreamSubscription<DownloadTick>? _download;
  Completer<void>? _downloadDone;

  WhisperModelPhase get phase => _phase;
  double? get progress => _progress;
  String? get errorMessage => _error;
  String? get verifiedPath => _phase == WhisperModelPhase.ready ? _path : null;
  bool get isVerified => verifiedPath != null;
  bool get inUse => _users > 0;
  int get approximateBytes => _store.approximateBytes;
  String get fileName => _store.fileName;
  String get modelId => _store.modelId;
  List<WhisperModelSpec> get availableModels => _store.availableModels;

  String get expectedSizeLabel {
    final megabytes = approximateBytes / (1024 * 1024);
    return AppStrings.expectedModelSize(megabytes.toStringAsFixed(1));
  }

  String get statusLabel {
    return switch (_phase) {
      WhisperModelPhase.missing => AppStrings.modelStatus,
      WhisperModelPhase.downloading => AppStrings.modelDownloading,
      WhisperModelPhase.ready => AppStrings.modelReady,
      WhisperModelPhase.failed => _error ?? AppStrings.downloadFailed,
      WhisperModelPhase.invalid => AppStrings.modelInvalid,
      WhisperModelPhase.removing => AppStrings.modelRemoving,
    };
  }

  bool beginUse() {
    if (_disposed || !isVerified) {
      return false;
    }
    _users += 1;
    _notify();
    return true;
  }

  void endUse() {
    if (_users == 0) {
      return;
    }
    _users -= 1;
    _notify();
  }

  /// Switches the selected catalog model without downloading it.
  ///
  /// Returns false while a session or download is using the current file.
  Future<bool> select(String id) async {
    if (_disposed || _users > 0 || _phase == WhisperModelPhase.downloading) {
      return false;
    }
    if (!_store.availableModels.any((model) => model.id == id)) {
      return false;
    }
    await _store.select(id);
    await refresh();
    return modelId == id;
  }

  Future<void> refresh({bool allowDuringDownload = false}) async {
    if (_disposed) {
      return;
    }
    if (_phase == WhisperModelPhase.downloading && !allowDuringDownload) {
      return;
    }
    final lookup = await _store.lookup();
    if (_disposed) {
      return;
    }
    switch (lookup.kind) {
      case WhisperModelLookupKind.missing:
        _phase = WhisperModelPhase.missing;
        _path = null;
        _error = null;
      case WhisperModelLookupKind.ready:
        _phase = WhisperModelPhase.ready;
        _path = lookup.path;
        _error = null;
      case WhisperModelLookupKind.invalid:
        _phase = WhisperModelPhase.invalid;
        _path = null;
        _error = AppStrings.modelInvalid;
    }
    _notify();
  }

  Future<void> download() async {
    if (_disposed ||
        _phase == WhisperModelPhase.downloading ||
        _phase == WhisperModelPhase.removing ||
        _users > 0) {
      return;
    }
    if (_phase == WhisperModelPhase.invalid) {
      await _store.delete();
    }
    _phase = WhisperModelPhase.downloading;
    _progress = null;
    _error = null;
    _notify();
    final completer = Completer<void>();
    _downloadDone = completer;
    _download = _store.download().listen(
      (tick) {
        _progress = tick.fraction;
        _notify();
      },
      onError: (Object error) {
        _download = null;
        _phase = error is FormatException
            ? WhisperModelPhase.invalid
            : WhisperModelPhase.failed;
        _error = _phase == WhisperModelPhase.invalid
            ? AppStrings.modelInvalid
            : AppStrings.downloadFailed;
        _progress = null;
        _notify();
        if (!completer.isCompleted) {
          completer.complete();
        }
      },
      onDone: () {
        _download = null;
        if (!completer.isCompleted) {
          completer.complete();
        }
      },
      cancelOnError: true,
    );
    await completer.future;
    _downloadDone = null;
    if (_disposed || _phase != WhisperModelPhase.downloading) {
      return;
    }
    await refresh(allowDuringDownload: true);
  }

  /// Cancels the download stream. A partial file may remain for a later resume.
  Future<void> cancelDownload() async {
    final subscription = _download;
    if (subscription == null) {
      return;
    }
    _download = null;
    _phase = WhisperModelPhase.missing;
    _progress = null;
    _error = AppStrings.downloadCancelled;
    if (!(_downloadDone?.isCompleted ?? true)) {
      _downloadDone!.complete();
    }
    await subscription.cancel();
    if (_disposed) {
      return;
    }
    _notify();
    await refresh();
    if (_phase == WhisperModelPhase.missing) {
      _error = AppStrings.downloadCancelled;
      _notify();
    }
  }

  Future<bool> remove() async {
    if (_disposed || _users > 0 || _phase == WhisperModelPhase.downloading) {
      return false;
    }
    if (_phase != WhisperModelPhase.ready &&
        _phase != WhisperModelPhase.invalid) {
      return false;
    }
    _phase = WhisperModelPhase.removing;
    _notify();
    await _store.delete();
    await refresh();
    return _phase != WhisperModelPhase.ready;
  }

  @override
  void dispose() {
    _disposed = true;
    if (!(_downloadDone?.isCompleted ?? true)) {
      _downloadDone!.complete();
    }
    unawaited(_download?.cancel());
    _download = null;
    _store.close();
    super.dispose();
  }

  void _notify() {
    if (_disposed) {
      return;
    }
    notifyListeners();
  }
}

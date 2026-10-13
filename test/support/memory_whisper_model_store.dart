import 'dart:async';

import 'package:sinhala_live_captions/services/speech/whisper_ports.dart';

class MemoryWhisperModelStore implements WhisperModelStore {
  var invalid = false;
  var fail = false;
  var downloads = 0;
  var deletes = 0;
  var closed = false;
  var holdDownload = false;
  String _modelId = 'tiny';
  final Map<String, bool> _present = {'tiny': false, 'base': false};
  final List<double?> progress = [0.5, 1];
  final StreamController<DownloadTick> held = StreamController<DownloadTick>();

  bool get present => _present[_modelId] ?? false;

  set present(bool value) => _present[_modelId] = value;

  @override
  List<WhisperModelSpec> get availableModels => const [
    WhisperModelSpec(
      id: 'tiny',
      fileName: 'ggml-tiny.bin',
      approximateBytes: 77691713,
    ),
    WhisperModelSpec(
      id: 'base',
      fileName: 'ggml-base.bin',
      approximateBytes: 147951465,
    ),
  ];

  @override
  String get modelId => _modelId;

  @override
  Future<void> select(String id) async {
    if (id == 'tiny' || id == 'base') {
      _modelId = id;
    }
  }

  @override
  int get approximateBytes =>
      availableModels.firstWhere((model) => model.id == _modelId).approximateBytes;

  @override
  String get fileName =>
      availableModels.firstWhere((model) => model.id == _modelId).fileName;

  @override
  Future<WhisperModelLookup> lookup() async {
    if (invalid) {
      return const WhisperModelLookup.invalid();
    }
    if (!present) {
      return const WhisperModelLookup.missing();
    }
    return WhisperModelLookup.ready('/tmp/$fileName');
  }

  @override
  Stream<DownloadTick> download() async* {
    downloads += 1;
    if (fail) {
      throw StateError('download failed');
    }
    if (holdDownload) {
      yield* held.stream;
      return;
    }
    for (final value in progress) {
      yield DownloadTick(value);
    }
    _present[_modelId] = true;
    invalid = false;
  }

  @override
  Future<void> delete() async {
    deletes += 1;
    _present[_modelId] = false;
    invalid = false;
  }

  @override
  void close() {
    closed = true;
    if (!held.isClosed) {
      held.close();
    }
  }
}

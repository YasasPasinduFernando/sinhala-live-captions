import 'dart:io';

import 'package:whisper_cpp_flutter_plus/whisper_cpp_flutter_plus.dart';

import 'whisper_ports.dart';

/// Catalog store for the multilingual tiny and base models.
///
/// English-only catalog entries are not offered. Download runs only for the
/// selected model, and only when [download] is called.
class CatalogWhisperModelStore implements WhisperModelStore {
  CatalogWhisperModelStore(this._manager);

  final WhisperModelManager _manager;
  String _modelId = 'tiny';

  static final List<WhisperModelSpec> _models = [
    WhisperModelSpec(
      id: WhisperModelCatalog.tiny.id,
      fileName: WhisperModelCatalog.tiny.fileName,
      approximateBytes: WhisperModelCatalog.tiny.approximateBytes,
    ),
    WhisperModelSpec(
      id: WhisperModelCatalog.base.id,
      fileName: WhisperModelCatalog.base.fileName,
      approximateBytes: WhisperModelCatalog.base.approximateBytes,
    ),
  ];

  WhisperModelDescriptor get _descriptor {
    return _modelId == WhisperModelCatalog.base.id
        ? WhisperModelCatalog.base
        : WhisperModelCatalog.tiny;
  }

  @override
  List<WhisperModelSpec> get availableModels => List.unmodifiable(_models);

  @override
  String get modelId => _modelId;

  @override
  Future<void> select(String id) async {
    if (id != WhisperModelCatalog.tiny.id &&
        id != WhisperModelCatalog.base.id) {
      return;
    }
    _modelId = id;
  }

  @override
  int get approximateBytes => _descriptor.approximateBytes;

  @override
  String get fileName => _descriptor.fileName;

  @override
  Future<WhisperModelLookup> lookup() async {
    try {
      final file = await _manager.findCatalogModel(_descriptor);
      if (file == null) {
        return const WhisperModelLookup.missing();
      }
      return WhisperModelLookup.ready(file.path);
    } on FormatException {
      return const WhisperModelLookup.invalid();
    }
  }

  @override
  Stream<DownloadTick> download() {
    return _manager
        .downloadCatalogModel(_descriptor)
        .map((progress) => DownloadTick(progress.fraction));
  }

  @override
  Future<void> delete() async {
    final directory = await _manager.directory;
    final partial = File('${directory.path}/$fileName.part');
    if (partial.existsSync()) {
      await partial.delete();
    }
    try {
      await _manager.delete(fileName);
    } on FileSystemException {
      // Already absent.
    }
  }

  @override
  void close() {
    _manager.close();
  }
}

import 'package:flutter_test/flutter_test.dart';
import 'package:sinhala_live_captions/core/app_strings.dart';
import 'package:sinhala_live_captions/core/recognition_mode.dart';
import 'package:sinhala_live_captions/core/session_phase.dart';
import 'package:sinhala_live_captions/services/speech/caption_session_controller.dart';
import 'package:sinhala_live_captions/services/speech/confirmed_snapshot.dart';
import 'package:sinhala_live_captions/services/speech/speech_engine.dart';
import 'package:sinhala_live_captions/services/speech/whisper_model_controller.dart';
import 'package:sinhala_live_captions/services/speech/whisper_ports.dart';
import 'package:sinhala_live_captions/services/speech/catalog_whisper_model_store.dart';
import 'package:sinhala_live_captions/services/speech/sinhala_transcribe_options.dart';
import 'package:sinhala_live_captions/services/speech/whisper_speech_engine.dart';
import 'package:whisper_cpp_flutter_plus/whisper_cpp_flutter_plus.dart';

import 'support/fake_whisper_runtime.dart';
import 'support/memory_whisper_model_store.dart';
import 'support/scripted_speech_engine.dart';

void main() {
  test('catalog tiny is the multilingual model', () {
    expect(
      WhisperModelCatalog.tiny.languageScope,
      WhisperModelLanguageScope.multilingual,
    );
    expect(WhisperModelCatalog.tiny.fileName, 'ggml-tiny.bin');
    expect(WhisperModelCatalog.tiny.id, 'tiny');
    expect(WhisperModelCatalog.tiny.approximateBytes, greaterThan(0));
    expect(WhisperModelCatalog.tiny.sha256, hasLength(64));
    expect(
      WhisperModelCatalog.tinyEnglish.languageScope,
      WhisperModelLanguageScope.english,
    );
    expect(
      WhisperModelCatalog.baseEnglish.languageScope,
      WhisperModelLanguageScope.english,
    );
  });

  test('sinhala options keep si when responsive mode is applied', () {
    const config = WhisperSessionConfig(
      modelPath: '/tmp/ggml-tiny.bin',
      modelId: 'tiny',
    );
    final options = sinhalaTranscribeOptions(config);
    expect(options.language, 'si');
    expect(options.language, isNot('auto'));
    expect(options.detectLanguage, isFalse);
    expect(options.translate, isFalse);
    expect(options.suppressNonSpeechTokens, isTrue);
    final responsive = options.withPerformanceMode(
      WhisperPerformanceMode.responsive,
    );
    expect(responsive.language, 'si');
    expect(responsive.detectLanguage, isFalse);
    expect(responsive.translate, isFalse);
  });

  test('catalog store offers multilingual tiny and base only', () {
    final store = CatalogWhisperModelStore(WhisperModelManager());
    addTearDown(store.close);
    expect(store.availableModels.map((model) => model.id), ['tiny', 'base']);
    expect(store.fileName, WhisperModelCatalog.tiny.fileName);
    expect(
      WhisperModelCatalog.base.languageScope,
      WhisperModelLanguageScope.multilingual,
    );
    expect(store.availableModels.map((model) => model.fileName), isNot(contains('ggml-tiny.en.bin')));
  });

  test('confirmed snapshots emit only the new suffix', () {
    final snapshot = ConfirmedSnapshot();
    expect(snapshot.takeAddition('ආයුබෝවන්'), 'ආයුබෝවන්');
    expect(snapshot.takeAddition('ආයුබෝවන්'), isNull);
    expect(snapshot.takeAddition('ආයුබෝවන් ඔබට'), 'ඔබට');
    expect(snapshot.takeAddition('වෙනස්'), isNull);
    expect(snapshot.takeAddition(''), isNull);
  });

  test('a missing model is not ready and a verified model is', () async {
    final store = MemoryWhisperModelStore();
    final models = WhisperModelController(store);
    addTearDown(models.dispose);

    await models.refresh();
    expect(models.phase, WhisperModelPhase.missing);
    expect(models.isVerified, isFalse);
    expect(models.statusLabel, AppStrings.modelStatus);
    expect(models.expectedSizeLabel, contains('74.1'));

    store.present = true;
    await models.refresh();
    expect(models.phase, WhisperModelPhase.ready);
    expect(models.statusLabel, AppStrings.modelReady);
    expect(models.verifiedPath, '/tmp/ggml-tiny.bin');
  });

  test('download reports progress and can fail then retry', () async {
    final store = MemoryWhisperModelStore()..fail = true;
    final models = WhisperModelController(store);
    addTearDown(models.dispose);
    final progress = <double?>[];
    models.addListener(() => progress.add(models.progress));

    await models.download();
    expect(models.phase, WhisperModelPhase.failed);
    expect(models.statusLabel, AppStrings.downloadFailed);

    store.fail = false;
    await models.download();
    expect(progress, contains(0.5));
    expect(models.phase, WhisperModelPhase.ready);
    expect(store.downloads, 2);
  });

  test('an invalid model can be downloaded again', () async {
    final store = MemoryWhisperModelStore()..invalid = true;
    final models = WhisperModelController(store);
    addTearDown(models.dispose);

    await models.refresh();
    expect(models.phase, WhisperModelPhase.invalid);
    await models.download();
    expect(store.deletes, greaterThan(0));
    expect(models.phase, WhisperModelPhase.ready);
  });

  test('download can be cancelled and removal waits until the model is idle', () async {
    final store = MemoryWhisperModelStore()..holdDownload = true;
    final models = WhisperModelController(store);
    addTearDown(models.dispose);

    final pending = models.download();
    await Future<void>.delayed(Duration.zero);
    expect(models.phase, WhisperModelPhase.downloading);
    await models.cancelDownload();
    await pending;
    expect(models.phase, WhisperModelPhase.missing);
    expect(models.errorMessage, AppStrings.downloadCancelled);

    store.present = true;
    await models.refresh();
    expect(models.beginUse(), isTrue);
    expect(await models.remove(), isFalse);
    models.endUse();
    expect(await models.remove(), isTrue);
    expect(models.phase, WhisperModelPhase.missing);
  });

  test('load failure does not leave the session initializing', () async {
    final harness = _harness()..runtime.failLoad = true;
    addTearDown(harness.session.dispose);
    addTearDown(harness.models.dispose);

    await harness.session.start();

    expect(harness.session.phase, SessionPhase.recoverableError);
    expect(harness.session.statusMessage, AppStrings.whisperLoadFailed);
    expect(harness.session.isActive, isFalse);
    expect(harness.models.inUse, isFalse);
  });

  test('permission failure is not reported as a model error', () async {
    final harness = _harness()..runtime.denyPermission = true;
    addTearDown(harness.session.dispose);
    addTearDown(harness.models.dispose);

    await harness.session.start();

    expect(harness.session.phase, SessionPhase.unavailable);
    expect(harness.session.statusMessage, AppStrings.microphoneDenied);
  });

  test('cumulative confirmed text and partial text stay distinct', () async {
    final harness = _harness();
    addTearDown(harness.session.dispose);
    addTearDown(harness.models.dispose);

    await harness.session.start();
    harness.task.add(
      const WhisperCaptionUpdate(
        confirmedText: 'ආයුබෝවන්',
        partialText: 'මම',
        isFinal: false,
      ),
    );
    harness.task.add(
      const WhisperCaptionUpdate(
        confirmedText: 'ආයුබෝවන් මම',
        partialText: 'යනවා',
        isFinal: false,
      ),
    );
    expect(harness.session.provisional, 'යනවා');
    harness.task.add(
      const WhisperCaptionUpdate(
        confirmedText: 'ආයුබෝවන් මම',
        partialText: '',
        isFinal: true,
      ),
    );

    expect(harness.session.confirmedText, 'ආයුබෝවන්\nමම');
    expect(harness.session.provisional, isEmpty);
    expect(harness.runtime.starts, 1);
    await harness.engine.start();
    expect(harness.runtime.starts, 1);

    await harness.session.start();
    expect(harness.runtime.starts, 1);
  });

  test('stop flushes the final suffix and cancel does not', () async {
    final harness = _harness();
    addTearDown(harness.session.dispose);
    addTearDown(harness.models.dispose);
    harness.task.stopResult = const WhisperCaptionUpdate(
      confirmedText: 'ආයුබෝවන් ඔබට',
      partialText: 'තාව',
      isFinal: true,
    );

    await harness.session.start();
    harness.task.add(
      const WhisperCaptionUpdate(
        confirmedText: 'ආයුබෝවන්',
        partialText: 'ඔබට',
        isFinal: false,
      ),
    );
    await harness.session.stop();

    expect(harness.session.confirmedText, 'ආයුබෝවන්\nඔබට');
    expect(harness.session.provisional, isEmpty);
    expect(harness.task.stopCount, 1);
    expect(harness.runtime.releases, greaterThan(0));

    await harness.session.start();
    harness.task.add(
      const WhisperCaptionUpdate(
        confirmedText: 'නැවත',
        partialText: 'එපා',
        isFinal: false,
      ),
    );
    await harness.session.cancel();
    expect(harness.session.confirmedText, 'ආයුබෝවන්\nඔබට\nනැවත');
    expect(harness.task.cancelCount, 1);
  });

  test('switching modes releases the whisper microphone', () async {
    final harness = _harness();
    final replacement = ScriptedSpeechEngine(RecognitionMode.device);
    final session = CaptionSessionController(
      initialMode: RecognitionMode.whisper,
      engineFactory: (mode) => mode == RecognitionMode.whisper
          ? harness.engine
          : replacement,
    );
    addTearDown(session.dispose);
    addTearDown(harness.models.dispose);

    await session.start();
    harness.task.add(
      const WhisperCaptionUpdate(
        confirmedText: 'තියෙනවා',
        partialText: '',
        isFinal: false,
      ),
    );
    await session.selectMode(RecognitionMode.device);

    expect(session.confirmedText, 'තියෙනවා');
    expect(harness.task.stopCount, 1);
    expect(harness.models.inUse, isFalse);
    expect(session.phase, SessionPhase.idle);
  });

  test('the whisper runtime is asked for si on the selected model', () async {
    final harness = _harness();
    addTearDown(harness.session.dispose);
    addTearDown(harness.models.dispose);

    await harness.session.start();
    final config = harness.runtime.lastConfig;
    expect(config?.language, 'si');
    expect(config?.detectLanguage, isFalse);
    expect(config?.translate, isFalse);
    expect(config?.modelId, 'tiny');
    expect(config?.modelPath, '/tmp/ggml-tiny.bin');

    await harness.session.stop();
    await harness.session.start();
    expect(harness.runtime.starts, 2);
    expect(harness.runtime.lastConfig?.language, 'si');
    expect(harness.models.inUse, isTrue);
    await harness.session.stop();
    expect(harness.models.inUse, isFalse);
  });

  test('selecting base does not download it', () async {
    final store = MemoryWhisperModelStore()..present = true;
    final models = WhisperModelController(store);
    addTearDown(models.dispose);
    await models.refresh();

    expect(await models.select('base'), isTrue);
    expect(models.modelId, 'base');
    expect(models.fileName, 'ggml-base.bin');
    expect(models.isVerified, isFalse);
    expect(store.downloads, 0);
    expect(models.beginUse(), isFalse);
  });

  test('a disposed whisper engine ignores a late update', () async {
    final harness = _harness();
    final seen = <SpeechEngineEvent>[];
    harness.engine.events.listen(seen.add);
    await harness.engine.start();
    await harness.engine.dispose();
    harness.task.add(
      const WhisperCaptionUpdate(
        confirmedText: 'පසු',
        partialText: 'පසු',
        isFinal: true,
      ),
    );

    expect(
      seen.whereType<SpeechConfirmedEvent>().map((event) => event.text),
      isNot(contains('පසු')),
    );
    expect(harness.models.inUse, isFalse);
  });
}

class _Harness {
  _Harness()
    : store = MemoryWhisperModelStore()..present = true,
      task = FakeWhisperTask() {
    models = WhisperModelController(store);
    runtime = FakeWhisperRuntime(task);
    engine = WhisperSpeechEngine(runtime: runtime, models: models);
    session = CaptionSessionController(engineFactory: (_) => engine);
  }

  final MemoryWhisperModelStore store;
  final FakeWhisperTask task;
  late final WhisperModelController models;
  late final FakeWhisperRuntime runtime;
  late final WhisperSpeechEngine engine;
  late final CaptionSessionController session;
}

_Harness _harness() => _Harness();

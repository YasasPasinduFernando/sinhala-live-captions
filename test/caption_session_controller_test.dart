import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:sinhala_live_captions/core/app_strings.dart';
import 'package:sinhala_live_captions/core/recognition_mode.dart';
import 'package:sinhala_live_captions/core/session_phase.dart';
import 'package:sinhala_live_captions/services/speech/caption_session_controller.dart';
import 'package:sinhala_live_captions/services/speech/demo_speech_engine.dart';
import 'package:sinhala_live_captions/services/speech/speech_engine.dart';

import 'support/scripted_speech_engine.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('confirmed text is appended and provisional text is replaced', () async {
    final engine = ScriptedSpeechEngine(RecognitionMode.device);
    final session = CaptionSessionController(
      engineFactory: (_) => engine,
    );
    addTearDown(session.dispose);

    await session.start();
    engine.emit(const SpeechProvisionalEvent('අ'));
    engine.emit(const SpeechProvisionalEvent('ආයු'));
    expect(session.provisional, 'ආයු');
    expect(session.confirmed, isEmpty);

    engine.emit(const SpeechConfirmedEvent('ආයුබෝවන්'));
    expect(session.confirmedText, 'ආයුබෝවන්');
    expect(session.provisional, isEmpty);

    engine.emit(const SpeechProvisionalEvent('මෙය'));
    engine.emit(const SpeechConfirmedEvent('මෙය උදාහරණයකි'));
    expect(session.confirmedText, 'ආයුබෝවන්\nමෙය උදාහරණයකි');
    expect(session.provisional, isEmpty);
  });

  test('duplicate confirmed text is not appended twice', () async {
    final engine = ScriptedSpeechEngine(RecognitionMode.device);
    final session = CaptionSessionController(engineFactory: (_) => engine);
    addTearDown(session.dispose);

    await session.start();
    engine.emit(const SpeechConfirmedEvent('ආයුබෝවන්'));
    engine.emit(const SpeechConfirmedEvent('ආයුබෝවන්'));
    engine.emit(const SpeechConfirmedEvent('  ආයුබෝවන්  '));
    expect(session.confirmed, hasLength(1));
  });

  test('clear removes confirmed and provisional text', () async {
    final engine = ScriptedSpeechEngine(RecognitionMode.device);
    final session = CaptionSessionController(engineFactory: (_) => engine);
    addTearDown(session.dispose);

    await session.start();
    engine.emit(const SpeechProvisionalEvent('තාවකාලික'));
    engine.emit(const SpeechConfirmedEvent('තහවුරු'));
    await session.stop();
    session.clearCaptions();
    expect(session.confirmed, isEmpty);
    expect(session.provisional, isEmpty);
    expect(session.statusMessage, AppStrings.cleared);
  });

  test('a second start does not create another engine', () async {
    final gate = Completer<void>();
    var created = 0;
    final session = CaptionSessionController(
      engineFactory: (mode) {
        created += 1;
        return ScriptedSpeechEngine(mode, startGate: gate);
      },
    );
    addTearDown(session.dispose);

    final first = session.start();
    final second = session.start();
    await Future<void>.delayed(Duration.zero);
    expect(created, 1);
    gate.complete();
    await first;
    await second;
    expect(created, 1);
    expect(session.isActive, isTrue);
  });

  test('changing mode stops and disposes the active engine', () async {
    final engine = ScriptedSpeechEngine(RecognitionMode.device);
    var created = 0;
    final session = CaptionSessionController(
      engineFactory: (mode) {
        created += 1;
        return mode == RecognitionMode.device
            ? engine
            : ScriptedSpeechEngine(mode);
      },
    );
    addTearDown(session.dispose);

    await session.start();
    engine.emit(const SpeechConfirmedEvent('පැරණි'));
    await session.selectMode(RecognitionMode.whisper);
    expect(engine.stopped, 1);
    expect(engine.disposed, 1);
    expect(session.mode, RecognitionMode.whisper);
    expect(session.isActive, isFalse);
    expect(session.confirmedText, 'පැරණි');
    expect(created, 1);

    await session.start();
    expect(created, 2);
  });

  test('stop ignores captions that arrive afterwards', () async {
    final engine = ScriptedSpeechEngine(RecognitionMode.device);
    final session = CaptionSessionController(engineFactory: (_) => engine);
    addTearDown(session.dispose);

    await session.start();
    engine.emit(const SpeechConfirmedEvent('පළමු'));
    await session.stop();
    engine.emit(const SpeechConfirmedEvent('පසු'));
    expect(session.confirmedText, 'පළමු');
    expect(session.phase, SessionPhase.completed);
    expect(session.isActive, isFalse);
  });

  test('dispose ignores later engine events', () async {
    final gate = Completer<void>();
    final engine = ScriptedSpeechEngine(RecognitionMode.device, startGate: gate);
    final session = CaptionSessionController(engineFactory: (_) => engine);
    var notifications = 0;
    session.addListener(() => notifications += 1);

    final pending = session.start();
    await Future<void>.delayed(Duration.zero);
    final beforeDispose = notifications;
    session.dispose();
    gate.complete();
    await pending;
    engine.emit(const SpeechConfirmedEvent('පසු'));
    expect(notifications, beforeDispose);
    expect(engine.disposed, 1);
  });

  test('demo engine does not keep captions after a manual stop', () async {
    final session = CaptionSessionController(
      engineFactory: (mode) => DemoSpeechEngine(
        mode: mode,
        stepDelay: const Duration(milliseconds: 30),
      ),
    );
    addTearDown(session.dispose);

    await session.start();
    await session.stop();
    await Future<void>.delayed(const Duration(milliseconds: 100));
    expect(session.confirmed, isEmpty);
    expect(session.showsDemonstration, isTrue);
    expect(session.capabilities?.usesMicrophone, isFalse);
  });
}

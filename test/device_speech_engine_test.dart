import 'package:flutter_test/flutter_test.dart';
import 'package:sinhala_live_captions/core/app_strings.dart';
import 'package:sinhala_live_captions/core/recognition_mode.dart';
import 'package:sinhala_live_captions/core/session_phase.dart';
import 'package:sinhala_live_captions/services/speech/caption_session_controller.dart';
import 'package:sinhala_live_captions/services/speech/device_speech_engine.dart';
import 'package:sinhala_live_captions/services/speech/sinhala_locale.dart';
import 'package:sinhala_live_captions/services/speech/speech_engine.dart';
import 'package:sinhala_live_captions/services/speech/voice_typing.dart';

import 'support/fake_device_speech_client.dart';
import 'support/fake_voice_typing.dart';
import 'support/scripted_speech_engine.dart';

void main() {
  test('sinhala locale ids require the si language subtag', () {
    expect(isSinhalaLocale('si'), isTrue);
    expect(isSinhalaLocale('si_LK'), isTrue);
    expect(isSinhalaLocale('si-LK'), isTrue);
    expect(isSinhalaLocale('SI_lk'), isTrue);
    expect(isSinhalaLocale('en_US'), isFalse);
    expect(isSinhalaLocale('en_SI'), isFalse);
    expect(isSinhalaLocale('sinhala'), isFalse);
    expect(selectSinhalaLocale(['en_US', 'fr_FR']), isNull);
    expect(selectSinhalaLocale(['si', 'si_LK']), 'si_LK');
    expect(selectSinhalaLocale(['en_US', 'SI-lk']), 'SI-lk');
  });

  test('missing sinhala locale tries explicit si-LK and not English', () async {
    final client = FakeDeviceSpeechClient()..locales = ['en_US'];
    final session = _session(client);
    addTearDown(session.dispose);

    await session.start();

    expect(session.phase, SessionPhase.listening);
    expect(client.requestedLocales, ['si-LK']);
    expect(client.requestedLocales, isNot(contains('en_US')));
    expect(session.diagnostics, contains('selected=si-LK'));
    expect(session.diagnostics, contains('listed=false'));
    expect(session.diagnostics, contains('mode=live'));
  });

  test('initialization failure stays out of a loading state', () async {
    final client = FakeDeviceSpeechClient()..initializeResult = false;
    final session = _session(client);
    addTearDown(session.dispose);

    await session.start();

    expect(session.phase, SessionPhase.unavailable);
    expect(session.statusMessage, AppStrings.deviceInitFailed);
    expect(session.isActive, isFalse);
  });

  test('permission failure explains how to allow the microphone', () async {
    final client = FakeDeviceSpeechClient()..permission = false;
    final session = _session(client);
    addTearDown(session.dispose);

    await session.start();

    expect(session.phase, SessionPhase.unavailable);
    expect(session.statusMessage, AppStrings.microphoneDenied);
    expect(client.listenCount, 0);
  });

  test('partial text is replaced and a final is kept once', () async {
    final client = FakeDeviceSpeechClient();
    final session = _session(client);
    addTearDown(session.dispose);

    await session.start();
    client.emitPartial('ආ');
    expect(session.provisional, 'ආ');
    client.emitPartial('ආයු');
    expect(session.provisional, 'ආයු');
    client.emitFinal('ආයුබෝවන්');
    client.emitFinal('ආයුබෝවන්');

    expect(session.confirmedText, 'ආයුබෝවන්');
    expect(session.provisional, isEmpty);
  });

  test('an empty final does not add a caption', () async {
    final client = FakeDeviceSpeechClient();
    final session = _session(client);
    addTearDown(session.dispose);

    await session.start();
    client.emitFinal('   ');

    expect(session.confirmedText, isEmpty);
  });

  test('device restarts are bounded after repeated failures', () async {
    final client = FakeDeviceSpeechClient()..errorOnListen = true;
    final session = _session(client, maxConsecutiveFailures: 5);
    addTearDown(session.dispose);

    await session.start();
    await Future<void>.delayed(const Duration(milliseconds: 40));

    expect(client.listenCount, 5);
    expect(session.phase, SessionPhase.recoverableError);
    expect(session.statusMessage, AppStrings.deviceRetriesExhausted);
  });

  test('stop prevents a later restart', () async {
    final client = FakeDeviceSpeechClient();
    final session = _session(client);
    addTearDown(session.dispose);

    await session.start();
    await session.stop();
    client.emitDone();
    await Future<void>.delayed(const Duration(milliseconds: 20));

    expect(client.listenCount, 1);
    expect(client.stopCount, 1);
    expect(session.phase, SessionPhase.completed);
  });

  test('stop keeps the flushed final and cancel does not', () async {
    final client = FakeDeviceSpeechClient()..stopFinal = 'අවසන්';
    final session = _session(client);
    addTearDown(session.dispose);

    await session.start();
    client.emitPartial('තාව');
    await session.stop();
    expect(session.confirmedText, 'අවසන්');

    await session.start();
    client.emitPartial('තාව');
    await session.cancel();
    expect(session.confirmedText, 'අවසන්');
  });

  test('switching engines stops the device microphone', () async {
    final client = FakeDeviceSpeechClient();
    final engine = DeviceSpeechEngine(
      client: client,
      whisperReady: () => false,
      restartDelay: const Duration(milliseconds: 5),
    );
    final replacement = ScriptedSpeechEngine(RecognitionMode.whisper);
    final session = CaptionSessionController(
      engineFactory: (mode) =>
          mode == RecognitionMode.device ? engine : replacement,
    );
    addTearDown(session.dispose);

    await session.start();
    client.emitFinal('එක');
    await session.selectMode(RecognitionMode.whisper);
    client.emitDone();
    await Future<void>.delayed(const Duration(milliseconds: 20));

    expect(session.confirmedText, 'එක');
    expect(client.stopCount, 1);
    expect(client.listenCount, 1);
    expect(session.phase, SessionPhase.idle);
  });

  test('a permanent permission error does not restart', () async {
    final client = FakeDeviceSpeechClient();
    final session = _session(client);
    addTearDown(session.dispose);

    await session.start();
    client.emitError('error_permission', permanent: true);
    client.emitDone();
    await Future<void>.delayed(const Duration(milliseconds: 20));

    expect(session.phase, SessionPhase.unavailable);
    expect(session.statusMessage, AppStrings.microphoneDenied);
    expect(client.listenCount, 1);
  });

  test('a listen that never starts is not shown as listening', () async {
    final client = FakeDeviceSpeechClient()..silentListen = true;
    final session = CaptionSessionController(
      engineFactory: (_) => DeviceSpeechEngine(
        client: client,
        whisperReady: () => false,
        startTimeout: Duration.zero,
      ),
    );
    addTearDown(session.dispose);

    await session.start();

    expect(session.phase, SessionPhase.recoverableError);
    expect(session.statusMessage, AppStrings.deviceDidNotStart);
    expect(session.capabilities?.usesMicrophone, isFalse);
    expect(session.diagnostics, contains('selected=si_LK'));
    expect(session.diagnostics, contains('listening=false'));
  });

  test('a rejected live locale opens voice typing once', () async {
    final client = FakeDeviceSpeechClient()
      ..locales = ['en_US', 'si_LK']
      ..scriptedError = 'error_language_unavailable'
      ..scriptedPermanent = true;
    final typing = FakeVoiceTyping()
      ..outcome = const VoiceTypingOutcome(
        VoiceTypingStatus.text,
        text: 'මගේ නම යසස්',
      );
    final session = _session(client, voiceTyping: typing);
    addTearDown(session.dispose);

    await session.start();
    await Future<void>.delayed(Duration.zero);

    expect(client.requestedLocales, ['si_LK']);
    expect(typing.calls, 1);
    expect(session.confirmedText, 'මගේ නම යසස්');
    expect(session.statusMessage, AppStrings.voiceTypingFinished);
    expect(session.diagnostics, contains('mode=voice-typing'));
    expect(client.listenCount, 1);
  });

  test('a cancelled voice typing dialog adds no caption and does not retry', () async {
    final client = FakeDeviceSpeechClient()
      ..locales = ['en_US']
      ..silentListen = true;
    final typing = FakeVoiceTyping()
      ..outcome = const VoiceTypingOutcome(VoiceTypingStatus.cancelled);
    final session = CaptionSessionController(
      engineFactory: (_) => DeviceSpeechEngine(
        client: client,
        whisperReady: () => false,
        voiceTyping: typing,
        startTimeout: Duration.zero,
      ),
    );
    addTearDown(session.dispose);

    await session.start();
    await Future<void>.delayed(Duration.zero);

    expect(client.requestedLocales, ['si-LK']);
    expect(typing.calls, 1);
    expect(session.confirmedText, isEmpty);
    expect(session.statusMessage, AppStrings.voiceTypingEmpty);
    expect(session.phase, isNot(SessionPhase.listening));

    client.emitDone();
    await Future<void>.delayed(const Duration(milliseconds: 20));
    expect(typing.calls, 1);
    expect(client.listenCount, 1);
  });

  test('an empty voice typing result is not treated as Sinhala text', () async {
    final client = FakeDeviceSpeechClient()
      ..locales = ['en_US']
      ..silentListen = true;
    final typing = FakeVoiceTyping()
      ..outcome = const VoiceTypingOutcome(VoiceTypingStatus.empty);
    final session = CaptionSessionController(
      engineFactory: (_) => DeviceSpeechEngine(
        client: client,
        whisperReady: () => false,
        voiceTyping: typing,
        startTimeout: Duration.zero,
      ),
    );
    addTearDown(session.dispose);

    await session.start();
    await Future<void>.delayed(Duration.zero);

    expect(session.confirmedText, isEmpty);
    expect(session.statusMessage, AppStrings.voiceTypingEmpty);
    expect(typing.calls, 1);
  });

  test('events after dispose are ignored', () async {
    final client = FakeDeviceSpeechClient();
    final engine = DeviceSpeechEngine(
      client: client,
      whisperReady: () => false,
    );
    final seen = <SpeechEngineEvent>[];
    engine.events.listen(seen.add);
    await engine.start();
    await engine.dispose();
    client.emitPartial('පසු');
    client.emitFinal('පසු');

    expect(
      seen.whereType<SpeechConfirmedEvent>().map((event) => event.text),
      isNot(contains('පසු')),
    );
  });
}

CaptionSessionController _session(
  FakeDeviceSpeechClient client, {
  int maxConsecutiveFailures = 5,
  bool whisperReady = false,
  VoiceTypingClient? voiceTyping,
}) {
  return CaptionSessionController(
    engineFactory: (_) => DeviceSpeechEngine(
      client: client,
      whisperReady: () => whisperReady,
      voiceTyping: voiceTyping,
      restartDelay: const Duration(milliseconds: 5),
      maxConsecutiveFailures: maxConsecutiveFailures,
    ),
  );
}

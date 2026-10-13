import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:sinhala_live_captions/core/session_phase.dart';
import 'package:sinhala_live_captions/services/speech/caption_session_controller.dart';
import 'package:sinhala_live_captions/services/speech/device_speech_engine.dart';
import 'package:sinhala_live_captions/services/speech/sinhala_locale.dart';
import 'package:sinhala_live_captions/services/speech/sinhala_locale_probe.dart';

import 'support/fake_device_speech_client.dart';

void main() {
  SinhalaLocaleProbe probe(
    FakeDeviceSpeechClient client, {
    Duration attemptTimeout = const Duration(milliseconds: 20),
  }) {
    return SinhalaLocaleProbe(
      client,
      attemptTimeout: attemptTimeout,
      pollInterval: const Duration(milliseconds: 1),
    );
  }

  test('explicit locale requests are not treated as discovered support', () async {
    final client = FakeDeviceSpeechClient()
      ..locales = ['en_US']
      ..scriptedResult = 'මගේ නම යසස්';
    final report = await probe(client).run();

    expect(report.initialized, isTrue);
    expect(report.permitted, isTrue);
    expect(report.discoveredSinhala, isFalse);
    expect(selectSinhalaLocale(report.discoveredLocales), isNull);
    expect(client.requestedLocales, ['si-LK', 'si_LK']);
    expect(client.lastListenFor, const Duration(milliseconds: 20));
    expect(report.attempts, hasLength(2));
    expect(report.attempts.every((attempt) => attempt.listeningStarted), isTrue);
    expect(
      report.attempts.every((attempt) => attempt.transcript == 'මගේ නම යසස්'),
      isTrue,
    );
    expect(report.attempts.every((attempt) => attempt.finalResult), isTrue);
    expect(
      report.attempts.map((attempt) => attempt.outcome),
      everyElement('transcript received'),
    );
    expect(client.listening, isFalse);
    expect(client.stopCount, 3);
    expect(report.summary, contains('discoveredSinhala=false'));
    expect(report.summary, contains('does not mark Sinhala as supported'));
  });

  test('a rejected explicit locale keeps the error and empty transcript', () async {
    final client = FakeDeviceSpeechClient()
      ..locales = ['en_US']
      ..scriptedError = 'error_language_unavailable'
      ..scriptedPermanent = true;
    final report = await probe(client).run();

    expect(client.requestedLocales, ['si-LK', 'si_LK']);
    expect(
      report.attempts.map((attempt) => attempt.error),
      everyElement('error_language_unavailable'),
    );
    expect(report.attempts.every((attempt) => attempt.permanentError), isTrue);
    expect(report.attempts.every((attempt) => attempt.transcript.isEmpty), isTrue);
    expect(
      report.attempts.map((attempt) => attempt.outcome),
      everyElement('locale unsupported'),
    );
    expect(report.discoveredSinhala, isFalse);
    expect(client.listening, isFalse);
  });

  test('no listening start is recorded when the service stays silent', () async {
    final client = FakeDeviceSpeechClient()
      ..locales = ['en_US']
      ..silentListen = true;
    final report = await probe(client).run();

    expect(client.requestedLocales, ['si-LK', 'si_LK']);
    expect(report.attempts.every((attempt) => !attempt.listeningStarted), isTrue);
    expect(report.attempts.every((attempt) => attempt.transcript.isEmpty), isTrue);
    expect(
      report.attempts.map((attempt) => attempt.outcome),
      everyElement('timeout'),
    );
    expect(client.stopCount, 3);
    expect(client.listening, isFalse);
  });

  test('failed initialization does not request a locale', () async {
    final client = FakeDeviceSpeechClient()..initializeResult = false;
    final report = await probe(client).run();

    expect(report.initialized, isFalse);
    expect(client.listenCount, 0);
    expect(report.attempts, isEmpty);
  });

  test('missing permission does not request a locale', () async {
    final client = FakeDeviceSpeechClient()..permission = false;
    final report = await probe(client).run();

    expect(report.initialized, isTrue);
    expect(report.permitted, isFalse);
    expect(client.listenCount, 0);
  });

  test('a second diagnostic does not start while the first is listening', () async {
    final client = FakeDeviceSpeechClient()
      ..locales = ['en_US']
      ..listenGate = Completer<void>();
    final diagnostic = probe(client);
    final first = diagnostic.run();
    await Future<void>.delayed(Duration.zero);
    final second = await diagnostic.run();

    expect(second.blocked, 'diagnostic already running');
    expect(client.listenCount, 1);
    client.listenGate!.complete();
    final firstReport = await first;
    expect(firstReport.attempts, isNotEmpty);
    expect(client.listening, isFalse);
  });

  test('an active microphone blocks a second diagnostic listen', () async {
    final client = FakeDeviceSpeechClient()..listening = true;
    final report = await probe(client).run();

    expect(report.blocked, 'microphone already active');
    expect(client.listenCount, 0);
  });

  test('normal start requests explicit si-LK when discovery has no Sinhala', () async {
    final client = FakeDeviceSpeechClient()..locales = ['en_US'];
    await probe(client).run();
    final session = _session(client);
    addTearDown(session.dispose);

    await session.start();

    expect(session.phase, SessionPhase.listening);
    expect(client.requestedLocales, ['si-LK', 'si_LK', 'si-LK']);
    expect(client.requestedLocales, isNot(contains('en_US')));
    expect(session.diagnostics, contains('selected=si-LK'));
    expect(session.diagnostics, contains('listed=false'));
  });
}

CaptionSessionController _session(FakeDeviceSpeechClient client) {
  return CaptionSessionController(
    engineFactory: (_) => DeviceSpeechEngine(
      client: client,
      whisperReady: () => false,
    ),
  );
}

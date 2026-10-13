import 'dart:async';

import 'device_speech_client.dart';
import 'sinhala_locale.dart';

/// One explicit locale request. This does not mean the locale is supported.
class ExplicitLocaleAttempt {
  const ExplicitLocaleAttempt({
    required this.localeId,
    required this.listeningStarted,
    required this.statuses,
    required this.error,
    required this.permanentError,
    required this.transcript,
    required this.finalResult,
    required this.timedOut,
    this.listenFailure,
  });

  final String localeId;
  final bool listeningStarted;
  final List<String> statuses;
  final String? error;
  final bool permanentError;
  final String transcript;
  final bool finalResult;
  final bool timedOut;
  final String? listenFailure;

  /// One of: listening started, locale unsupported, recognition error,
  /// timeout, transcript received.
  String get outcome {
    final errorText = (error ?? '').toLowerCase();
    if (errorText.contains('language_not_supported') ||
        errorText.contains('language_unavailable')) {
      return 'locale unsupported';
    }
    if (transcript.isNotEmpty) {
      return 'transcript received';
    }
    final failure = listenFailure ?? '';
    if (error != null ||
        (failure.isNotEmpty && !failure.toLowerCase().contains('timeout'))) {
      return 'recognition error';
    }
    if (timedOut || failure.isNotEmpty || !listeningStarted) {
      return 'timeout';
    }
    return 'listening started';
  }

  String get summary {
    final status = statuses.isEmpty ? 'none' : statuses.join('>');
    final failure = listenFailure ?? 'none';
    final errorText = error ?? 'none';
    return '$localeId: $outcome. listening=$listeningStarted '
        'statuses=$status error=$errorText permanent=$permanentError '
        'final=$finalResult transcript=$transcript listenFailure=$failure';
  }
}

/// Debug report for explicit `si-LK` and `si_LK` requests.
///
/// [discoveredSinhala] stays false when the locale query did not return `si`.
/// Sending a locale id does not add it to the supported list.
class ExplicitLocaleReport {
  const ExplicitLocaleReport({
    required this.initialized,
    required this.permitted,
    required this.discoveredLocales,
    required this.attempts,
    this.blocked,
  });

  final bool initialized;
  final bool permitted;
  final List<String> discoveredLocales;
  final List<ExplicitLocaleAttempt> attempts;
  final String? blocked;

  bool get discoveredSinhala => discoveredLocales.any(isSinhalaLocale);

  String get summary {
    final discovered = discoveredLocales.isEmpty
        ? 'none'
        : discoveredLocales.join(',');
    final lines = <String>[
      if (blocked != null) 'blocked=$blocked',
      'init=$initialized permission=$permitted',
      'discoveredCount=${discoveredLocales.length} '
          'discoveredSinhala=$discoveredSinhala',
      'Sending si-LK or si_LK does not mark Sinhala as supported.',
      for (final attempt in attempts) attempt.summary,
      'discovered=$discovered',
    ];
    return lines.join('\n');
  }
}

/// Asks the Android speech service for Sinhala locales that were not listed.
///
/// Normal recognition still refuses a session when discovery returns no `si`
/// locale. This probe is a separate, explicit request.
class SinhalaLocaleProbe {
  SinhalaLocaleProbe(
    this._client, {
    this.attemptTimeout = const Duration(seconds: 8),
    this.pollInterval = const Duration(milliseconds: 200),
    this.locales = const ['si-LK', 'si_LK'],
  });

  final DeviceSpeechClient _client;
  final Duration attemptTimeout;
  final Duration pollInterval;
  final List<String> locales;

  var _running = false;

  bool get isRunning => _running;

  Future<ExplicitLocaleReport> run({
    void Function(String status)? onProgress,
  }) async {
    if (_running || _client.isListening) {
      return ExplicitLocaleReport(
        initialized: false,
        permitted: false,
        discoveredLocales: const [],
        attempts: const [],
        blocked: _client.isListening
            ? 'microphone already active'
            : 'diagnostic already running',
      );
    }
    _running = true;
    try {
      onProgress?.call('Requesting ${locales.first}. Speak now.');
      final initialized = await _client.initialize().timeout(attemptTimeout);
      if (!initialized) {
        return const ExplicitLocaleReport(
          initialized: false,
          permitted: false,
          discoveredLocales: [],
          attempts: [],
          blocked: 'initialization failed',
        );
      }
      final permitted = await _client.hasPermission().timeout(attemptTimeout);
      if (!permitted) {
        return const ExplicitLocaleReport(
          initialized: true,
          permitted: false,
          discoveredLocales: [],
          attempts: [],
          blocked: 'microphone permission denied',
        );
      }
      final discovered = await _client.localeIds().timeout(attemptTimeout);
      final attempts = <ExplicitLocaleAttempt>[];
      for (final localeId in locales) {
        onProgress?.call('Requesting $localeId. Speak now.');
        final attempt = await _attempt(localeId);
        attempts.add(attempt);
        onProgress?.call(attempt.summary);
        await _releaseMicrophone();
      }
      onProgress?.call('Diagnostic finished. Microphone released.');
      return ExplicitLocaleReport(
        initialized: true,
        permitted: true,
        discoveredLocales: discovered,
        attempts: attempts,
      );
    } on TimeoutException catch (error) {
      return ExplicitLocaleReport(
        initialized: false,
        permitted: false,
        discoveredLocales: const [],
        attempts: const [],
        blocked: 'timeout: ${error.message ?? 'no response'}',
      );
    } catch (error) {
      return ExplicitLocaleReport(
        initialized: false,
        permitted: false,
        discoveredLocales: const [],
        attempts: const [],
        blocked: 'diagnostic failure: $error',
      );
    } finally {
      await _releaseMicrophone();
      _running = false;
    }
  }

  Future<ExplicitLocaleAttempt> _attempt(String localeId) async {
    final statuses = <String>[];
    String? error;
    var permanent = false;
    var transcript = '';
    var finalResult = false;
    var listeningStarted = false;
    var timedOut = false;
    String? listenFailure;

    _client.setHandlers(
      onStatus: (status) {
        statuses.add(status);
        if (status == 'listening') {
          listeningStarted = true;
        }
      },
      onError: (message, isPermanent) {
        error = message;
        permanent = isPermanent;
      },
      onResult: (words, isFinal) {
        final trimmed = words.trim();
        if (trimmed.isEmpty) {
          return;
        }
        transcript = trimmed;
        finalResult = isFinal;
      },
    );

    try {
      await _client
          .listen(
            localeId: localeId,
            listenFor: attemptTimeout,
            pauseFor: const Duration(seconds: 3),
          )
          .timeout(attemptTimeout);
    } on TimeoutException {
      listenFailure = 'timeout: listen returned no response';
      timedOut = true;
    } catch (caught) {
      listenFailure = caught.toString();
    }

    final deadline = DateTime.now().add(attemptTimeout);
    while (DateTime.now().isBefore(deadline)) {
      final finished =
          listenFailure != null ||
          error != null ||
          finalResult ||
          statuses.contains('done');
      if (finished) {
        break;
      }
      await Future<void>.delayed(pollInterval);
    }
    final finished =
        listenFailure != null ||
        error != null ||
        finalResult ||
        statuses.contains('done');
    if (!finished) {
      timedOut = true;
      listenFailure ??= 'timeout: no recognition callback';
    }
    listeningStarted =
        listeningStarted ||
        statuses.contains('listening') ||
        _client.isListening;

    return ExplicitLocaleAttempt(
      localeId: localeId,
      listeningStarted: listeningStarted,
      statuses: List.unmodifiable(statuses),
      error: error,
      permanentError: permanent,
      transcript: transcript,
      finalResult: finalResult,
      timedOut: timedOut,
      listenFailure: listenFailure,
    );
  }

  Future<void> _releaseMicrophone() async {
    try {
      await _client.stop();
    } catch (_) {
      // stop is also used when the service never reported listening.
    }
    if (!_client.isListening) {
      return;
    }
    try {
      await _client.cancel();
    } catch (_) {
      // The diagnostic must not leave a listen running.
    }
  }
}

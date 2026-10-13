import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../core/app_strings.dart';
import '../../core/recognition_mode.dart';
import '../../core/session_phase.dart';
import '../../features/settings/app_settings_controller.dart';
import '../../services/network/network_status.dart';
import '../../services/speech/caption_session_controller.dart';
import '../../services/speech/sinhala_locale_probe.dart';
import '../home/network_usage_card.dart';
import 'caption_view.dart';

class LiveCaptionsScreen extends StatefulWidget {
  const LiveCaptionsScreen({
    required this.settings,
    required this.session,
    this.localeProbe,
    this.network,
    super.key,
  });

  final AppSettingsController settings;
  final CaptionSessionController session;
  final SinhalaLocaleProbe? localeProbe;
  final NetworkStatus? network;

  static const localeProbeKey = Key('sinhala-locale-probe');
  static const localeProbeReportKey = Key('sinhala-locale-probe-report');
  static const detailScrollKey = Key('caption-detail-scroll');

  static const startKey = Key('caption-start');
  static const stopKey = Key('caption-stop');
  static const clearKey = Key('caption-clear');
  static const statusKey = Key('caption-status');

  @override
  State<LiveCaptionsScreen> createState() => _LiveCaptionsScreenState();
}

class _LiveCaptionsScreenState extends State<LiveCaptionsScreen> {
  var _allowPop = false;
  var _probing = false;
  String _probeStatus = '';

  void _showProbeStatus(String status) {
    if (!mounted || status.isEmpty) {
      return;
    }
    setState(() {
      final lines = _probeStatus.split('\n');
      if (lines.isNotEmpty && lines.last == status) {
        return;
      }
      _probeStatus = _probeStatus.isEmpty ? status : '$_probeStatus\n$status';
    });
  }

  Future<void> _runLocaleProbe() async {
    final probe = widget.localeProbe;
    if (probe == null || _probing || probe.isRunning || widget.session.isActive) {
      return;
    }
    setState(() {
      _probing = true;
      _probeStatus = 'Requesting si-LK. Speak now.';
    });
    try {
      final report = await probe.run(onProgress: _showProbeStatus);
      if (!mounted) {
        return;
      }
      setState(() => _probeStatus = report.summary);
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() => _probeStatus = 'diagnostic failure: $error');
    } finally {
      if (mounted) {
        setState(() => _probing = false);
      }
    }
  }

  @override
  void dispose() {
    if (!_allowPop) {
      unawaited(widget.session.stop());
    }
    super.dispose();
  }

  Future<void> _leave() async {
    if (_allowPop) {
      return;
    }
    await widget.session.stop();
    if (!mounted) {
      return;
    }
    setState(() => _allowPop = true);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final settings = widget.settings;
    final session = widget.session;
    return PopScope(
      canPop: _allowPop,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) {
          _leave();
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text(AppStrings.title),
          leading: IconButton(
            tooltip: AppStrings.back,
            icon: const Icon(Icons.arrow_back),
            onPressed: _leave,
          ),
        ),
        body: ListenableBuilder(
          listenable: Listenable.merge([
            settings,
            session,
            ?widget.network,
          ]),
          builder: (context, _) {
            final theme = Theme.of(context);
            final whisper = settings.mode == RecognitionMode.whisper;
            return Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Flexible(
                    child: SingleChildScrollView(
                      child: Semantics(
                    liveRegion: true,
                    label: session.statusMessage,
                    child: _StatusBanner(
                      key: LiveCaptionsScreen.statusKey,
                      message: session.statusMessage,
                      modeLabel: AppStrings.modeName(whisper),
                      phase: session.phase,
                      showDemonstration: session.showsDemonstration,
                      microphoneActive:
                          session.phase == SessionPhase.listening &&
                          (session.capabilities?.usesMicrophone ?? false) &&
                          !session.showsDemonstration,
                    ),
                  ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: CaptionView(
                      confirmedText: session.confirmedText,
                      provisional: session.provisional,
                      fontSize: settings.fontSize,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _Controls(session: session, startEnabled: !_probing),
                  if (kDebugMode &&
                      widget.localeProbe != null &&
                      !whisper) ...[
                    const SizedBox(height: 8),
                    OutlinedButton(
                      key: LiveCaptionsScreen.localeProbeKey,
                      onPressed: _probing ||
                              (widget.localeProbe?.isRunning ?? false) ||
                              session.isActive
                          ? null
                          : _runLocaleProbe,
                      child: const Text(AppStrings.testSinhalaLocale),
                    ),
                  ],
                  const SizedBox(height: 8),
                  Expanded(
                    child: Scrollbar(
                      child: SingleChildScrollView(
                        key: LiveCaptionsScreen.detailScrollKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            NetworkUsageCard(
                              mode: settings.mode,
                              network: widget.network,
                            ),
                            const SizedBox(height: 8),
                            if (_probeStatus.isNotEmpty) ...[
                              Text(
                                _probeStatus,
                                key: LiveCaptionsScreen.localeProbeReportKey,
                                style: theme.textTheme.bodyMedium,
                              ),
                              const SizedBox(height: 8),
                            ],
                            Text(
                              session.showsDemonstration
                                  ? AppStrings.demoBanner
                                  : session.phase == SessionPhase.listening
                                  ? (whisper
                                        ? AppStrings.whisperOnDevice
                                        : AppStrings.deviceNotContinuous)
                                  : AppStrings.captionsIdleNote,
                              style: theme.textTheme.titleMedium,
                            ),
                            if (kDebugMode &&
                                session.diagnostics.isNotEmpty) ...[
                              const SizedBox(height: 8),
                              Text(
                                session.diagnostics,
                                key: const Key('session-diagnostics'),
                                style: theme.textTheme.bodyMedium,
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _StatusBanner extends StatelessWidget {
  const _StatusBanner({
    required this.message,
    required this.modeLabel,
    required this.phase,
    required this.showDemonstration,
    required this.microphoneActive,
    super.key,
  });

  final String message;
  final String modeLabel;
  final SessionPhase phase;
  final bool showDemonstration;
  final bool microphoneActive;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isError =
        phase == SessionPhase.recoverableError ||
        phase == SessionPhase.unavailable;
    final icon = microphoneActive
        ? Icons.mic
        : isError
        ? Icons.error_outline
        : Icons.info_outline;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: theme.colorScheme.onSurface,
          width: isError ? 3 : 1,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: theme.colorScheme.onSurface),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  showDemonstration
                      ? '${AppStrings.demoBadge} · $modeLabel'
                      : modeLabel,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(message, style: theme.textTheme.titleMedium),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Controls extends StatelessWidget {
  const _Controls({required this.session, required this.startEnabled});

  final CaptionSessionController session;
  final bool startEnabled;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        FilledButton(
          key: LiveCaptionsScreen.startKey,
          onPressed: session.isActive || !startEnabled
              ? null
              : () => session.start(),
          child: const Text(AppStrings.start),
        ),
        OutlinedButton(
          key: LiveCaptionsScreen.stopKey,
          onPressed: session.isActive ? () => session.stop() : null,
          child: const Text(AppStrings.stop),
        ),
        OutlinedButton(
          key: LiveCaptionsScreen.clearKey,
          onPressed: () => session.clearCaptions(),
          child: const Text(AppStrings.clear),
        ),
      ],
    );
  }
}

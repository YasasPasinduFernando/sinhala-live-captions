import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/app_strings.dart';
import '../../core/session_phase.dart';
import '../../features/settings/app_settings_controller.dart';
import '../../services/speech/caption_session_controller.dart';
import 'caption_view.dart';

class LiveCaptionsScreen extends StatefulWidget {
  const LiveCaptionsScreen({
    required this.settings,
    required this.session,
    super.key,
  });

  final AppSettingsController settings;
  final CaptionSessionController session;

  static const startKey = Key('caption-start');
  static const stopKey = Key('caption-stop');
  static const clearKey = Key('caption-clear');
  static const statusKey = Key('caption-status');

  @override
  State<LiveCaptionsScreen> createState() => _LiveCaptionsScreenState();
}

class _LiveCaptionsScreenState extends State<LiveCaptionsScreen> {
  var _allowPop = false;

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
          toolbarHeight: 48,
          title: const Text(AppStrings.sinhalaTitle),
          titleTextStyle: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w700,
            color: Theme.of(context).colorScheme.onSurface,
          ),
          leading: IconButton(
            tooltip: AppStrings.back,
            icon: const Icon(Icons.arrow_back),
            onPressed: _leave,
          ),
          actions: [
            IconButton(
              key: LiveCaptionsScreen.clearKey,
              tooltip: AppStrings.clear,
              onPressed: () => session.clearCaptions(),
              icon: const Icon(Icons.delete_outline),
            ),
          ],
        ),
        body: ListenableBuilder(
          listenable: Listenable.merge([settings, session]),
          builder: (context, _) {
            final theme = Theme.of(context);
            final isError =
                session.phase == SessionPhase.recoverableError ||
                session.phase == SessionPhase.unavailable;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (isError)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 4, 24, 0),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.error_outline,
                          color: theme.colorScheme.error,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            session.statusMessage,
                            key: LiveCaptionsScreen.statusKey,
                            style: theme.textTheme.titleMedium?.copyWith(
                              color: theme.colorScheme.error,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                Expanded(
                  child: CaptionView(
                    confirmedText: session.confirmedText,
                    provisional: session.provisional,
                    fontSize: settings.fontSize,
                  ),
                ),
                SafeArea(
                  top: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
                    child: session.isActive
                        ? FilledButton(
                            key: LiveCaptionsScreen.stopKey,
                            style: FilledButton.styleFrom(
                              minimumSize: const Size.fromHeight(52),
                            ),
                            onPressed: () => session.stop(),
                            child: const Text(AppStrings.stop),
                          )
                        : FilledButton(
                            key: LiveCaptionsScreen.startKey,
                            style: FilledButton.styleFrom(
                              minimumSize: const Size.fromHeight(52),
                            ),
                            onPressed: () => session.start(),
                            child: const Text(AppStrings.start),
                          ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

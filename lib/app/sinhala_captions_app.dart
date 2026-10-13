import 'package:flutter/material.dart';

import '../core/app_strings.dart';
import '../core/session_phase.dart';
import '../features/home/home_screen.dart';
import '../features/settings/app_settings_controller.dart';
import '../services/network/network_status.dart';
import '../services/speech/caption_session_controller.dart';
import '../services/speech/sinhala_locale_probe.dart';
import '../services/speech/whisper_model_controller.dart';
import 'app_theme.dart';

class SinhalaCaptionsApp extends StatefulWidget {
  const SinhalaCaptionsApp({
    required this.settings,
    required this.session,
    required this.models,
    this.localeProbe,
    this.network,
    super.key,
  });

  final AppSettingsController settings;
  final CaptionSessionController session;
  final WhisperModelController models;
  final SinhalaLocaleProbe? localeProbe;
  final NetworkStatus? network;

  @override
  State<SinhalaCaptionsApp> createState() => _SinhalaCaptionsAppState();
}

class _SinhalaCaptionsAppState extends State<SinhalaCaptionsApp>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    widget.network?.start();
    widget.session.selectMode(widget.settings.mode);
    widget.settings.addListener(_syncMode);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    widget.settings.removeListener(_syncMode);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final background =
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden ||
        state == AppLifecycleState.detached;
    if (background && widget.session.phase == SessionPhase.listening) {
      widget.session.stop();
    }
  }

  void _syncMode() {
    widget.session.selectMode(widget.settings.mode);
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.settings,
      builder: (context, _) {
        final settings = widget.settings;
        final theme = buildAppTheme(
          brightness: settings.theme == ThemePreference.dark
              ? Brightness.dark
              : Brightness.light,
          highContrast: settings.highContrast,
        );
        return MaterialApp(
          title: AppStrings.title,
          theme: theme,
          themeAnimationStyle: AnimationStyle.noAnimation,
          home: HomeScreen(
            settings: settings,
            session: widget.session,
            models: widget.models,
            localeProbe: widget.localeProbe,
            network: widget.network,
          ),
        );
      },
    );
  }
}

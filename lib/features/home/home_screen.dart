import 'package:flutter/material.dart';

import '../../core/app_strings.dart';
import '../../core/recognition_mode.dart';
import '../../features/captions/live_captions_screen.dart';
import '../../features/settings/app_settings_controller.dart';
import '../../features/settings/settings_screen.dart';
import '../../services/network/network_status.dart';
import '../../services/speech/caption_session_controller.dart';
import '../../services/speech/whisper_model_controller.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({
    required this.settings,
    required this.session,
    required this.models,
    this.network,
    super.key,
  });

  final AppSettingsController settings;
  final CaptionSessionController session;
  final WhisperModelController models;
  final NetworkStatus? network;

  static const startKey = Key('start-captions');
  static const settingsKey = Key('open-settings');

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text(AppStrings.sinhalaTitle),
      ),
      body: ListenableBuilder(
        listenable: Listenable.merge([
          settings,
          models,
          ?network,
        ]),
        builder: (context, _) {
          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
            children: [
              Text(
                AppStrings.title,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 20),
              FilledButton.icon(
                key: startKey,
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => LiveCaptionsScreen(
                        settings: settings,
                        session: session,
                      ),
                    ),
                  );
                },
                icon: const Icon(Icons.subtitles_outlined),
                label: const Text(AppStrings.startCaptions),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                key: settingsKey,
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => SettingsScreen(
                        settings: settings,
                        models: models,
                      ),
                    ),
                  );
                },
                icon: const Icon(Icons.tune),
                label: const Text(AppStrings.settings),
              ),
              const SizedBox(height: 20),
              _NetworkLine(mode: settings.mode, network: network),
              const SizedBox(height: 24),
              Text(
                AppStrings.currentMode,
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                AppStrings.modeName(settings.mode == RecognitionMode.whisper),
                style: theme.textTheme.titleMedium,
              ),
              const SizedBox(height: 12),
              _ModeChoice(
                title: AppStrings.deviceMode,
                selected: settings.mode == RecognitionMode.device,
                onPressed: () => settings.setMode(RecognitionMode.device),
              ),
              const SizedBox(height: 12),
              _ModeChoice(
                title: AppStrings.whisperMode,
                selected: settings.mode == RecognitionMode.whisper,
                onPressed: () => settings.setMode(RecognitionMode.whisper),
              ),
              const SizedBox(height: 24),
              Text(
                AppStrings.modelStatusTitle,
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              Text(models.statusLabel, style: theme.textTheme.titleMedium),
            ],
          );
        },
      ),
    );
  }
}

class _NetworkLine extends StatelessWidget {
  const _NetworkLine({required this.mode, required this.network});

  final RecognitionMode mode;
  final NetworkStatus? network;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final online = network?.online;
    final usage = mode == RecognitionMode.device
        ? AppStrings.internetShortDevice
        : AppStrings.internetShortWhisper;
    final link = switch (online) {
      true => AppStrings.networkOnline,
      false => AppStrings.networkOffline,
      null => null,
    };
    return Text(
      link == null ? usage : '$usage · $link',
      style: theme.textTheme.titleMedium,
    );
  }
}

class _ModeChoice extends StatelessWidget {
  const _ModeChoice({
    required this.title,
    required this.selected,
    required this.onPressed,
  });

  final String title;
  final bool selected;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Semantics(
      button: true,
      selected: selected,
      label: selected ? '$title. ${AppStrings.selected}' : title,
      child: Material(
        color: theme.colorScheme.surface,
        child: InkWell(
          onTap: onPressed,
          child: Container(
            constraints: const BoxConstraints(minHeight: 72),
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: selected
                  ? theme.colorScheme.primaryContainer.withValues(alpha: 0.55)
                  : theme.colorScheme.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: theme.colorScheme.onSurface,
                width: selected ? 3 : 1,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                if (selected)
                  Text(
                    AppStrings.selected,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

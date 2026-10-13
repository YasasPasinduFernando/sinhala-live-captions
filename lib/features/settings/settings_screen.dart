import 'package:flutter/material.dart';

import '../../core/app_strings.dart';
import '../../core/recognition_mode.dart';
import '../../services/speech/whisper_model_controller.dart';
import 'app_settings_controller.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({
    required this.settings,
    required this.models,
    super.key,
  });

  final AppSettingsController settings;
  final WhisperModelController models;

  static const fontSliderKey = Key('font-slider');
  static const lightKey = Key('theme-light');
  static const darkKey = Key('theme-dark');
  static const contrastKey = Key('high-contrast');
  static const deviceModeKey = Key('mode-device');
  static const whisperModeKey = Key('mode-whisper');
  static const downloadKey = Key('download-model');
  static const retryKey = Key('retry-model');
  static const removeKey = Key('remove-model');
  static const cancelDownloadKey = Key('cancel-download');

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  @override
  void initState() {
    super.initState();
    widget.models.refresh();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final settings = widget.settings;
    final models = widget.models;
    return Scaffold(
      appBar: AppBar(
        title: const Text(AppStrings.settings),
        leading: IconButton(
          tooltip: AppStrings.back,
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
      ),
      body: ListenableBuilder(
        listenable: Listenable.merge([settings, models]),
        builder: (context, _) {
          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
            children: [
              Text(
                AppStrings.fontSize,
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              Text(
                settings.fontSize.round().toString(),
                style: theme.textTheme.headlineSmall,
              ),
              Slider(
                key: SettingsScreen.fontSliderKey,
                min: AppSettingsController.minFontSize,
                max: AppSettingsController.maxFontSize,
                divisions: 24,
                value: settings.fontSize,
                label: settings.fontSize.round().toString(),
                onChanged: settings.setFontSize,
              ),
              const SizedBox(height: 8),
              Text(
                AppStrings.appearance,
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              _ChoiceTile(
                key: SettingsScreen.lightKey,
                title: AppStrings.lightTheme,
                selected: settings.theme == ThemePreference.light,
                onPressed: () => settings.setTheme(ThemePreference.light),
              ),
              const SizedBox(height: 8),
              _ChoiceTile(
                key: SettingsScreen.darkKey,
                title: AppStrings.darkTheme,
                selected: settings.theme == ThemePreference.dark,
                onPressed: () => settings.setTheme(ThemePreference.dark),
              ),
              SwitchListTile(
                key: SettingsScreen.contrastKey,
                contentPadding: EdgeInsets.zero,
                title: const Text(AppStrings.highContrast),
                value: settings.highContrast,
                onChanged: settings.setHighContrast,
              ),
              const SizedBox(height: 8),
              Text(
                AppStrings.recognitionMode,
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              _ChoiceTile(
                key: SettingsScreen.deviceModeKey,
                title: AppStrings.deviceMode,
                selected: settings.mode == RecognitionMode.device,
                onPressed: () => settings.setMode(RecognitionMode.device),
              ),
              const SizedBox(height: 8),
              _ChoiceTile(
                key: SettingsScreen.whisperModeKey,
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
              const SizedBox(height: 8),
              Text(
                models.expectedSizeLabel,
                style: theme.textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              for (final model in models.availableModels) ...[
                _ChoiceTile(
                  title:
                      '${model.id == 'base' ? AppStrings.baseModel : AppStrings.tinyModel} — ${model.sizeLabel} MB',
                  selected: models.modelId == model.id,
                  onPressed: models.inUse
                      ? () {}
                      : () {
                          models.select(model.id).then((selected) {
                            if (selected) {
                              settings.setWhisperModel(model.id);
                            }
                          });
                        },
                ),
                const SizedBox(height: 8),
              ],
              if (models.phase == WhisperModelPhase.downloading) ...[
                const SizedBox(height: 8),
                LinearProgressIndicator(value: models.progress),
              ],
              if (models.errorMessage != null &&
                  models.errorMessage != models.statusLabel &&
                  models.phase != WhisperModelPhase.ready) ...[
                const SizedBox(height: 8),
                Text(
                  models.errorMessage!,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
              const SizedBox(height: 8),
              FilledButton(
                key: SettingsScreen.downloadKey,
                onPressed: models.phase == WhisperModelPhase.missing
                    ? () => models.download()
                    : null,
                child: const Text(AppStrings.downloadModel),
              ),
              const SizedBox(height: 8),
              OutlinedButton(
                key: SettingsScreen.retryKey,
                onPressed:
                    models.phase == WhisperModelPhase.failed ||
                        models.phase == WhisperModelPhase.invalid
                    ? () => models.download()
                    : null,
                child: const Text(AppStrings.retryDownload),
              ),
              const SizedBox(height: 8),
              OutlinedButton(
                key: SettingsScreen.cancelDownloadKey,
                onPressed: models.phase == WhisperModelPhase.downloading
                    ? () => models.cancelDownload()
                    : null,
                child: const Text(AppStrings.cancelDownload),
              ),
              const SizedBox(height: 8),
              OutlinedButton(
                key: SettingsScreen.removeKey,
                onPressed:
                    (models.phase == WhisperModelPhase.ready ||
                            models.phase == WhisperModelPhase.invalid) &&
                        !models.inUse
                    ? () => models.remove()
                    : null,
                child: const Text(AppStrings.removeModel),
              ),
              if (models.inUse) ...[
                const SizedBox(height: 8),
                Text(
                  AppStrings.modelInUse,
                  style: theme.textTheme.titleMedium,
                ),
              ],
              const SizedBox(height: 24),
              Text(AppStrings.privacy, style: theme.textTheme.titleMedium),
            ],
          );
        },
      ),
    );
  }
}

class _ChoiceTile extends StatelessWidget {
  const _ChoiceTile({
    required this.title,
    required this.selected,
    required this.onPressed,
    super.key,
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
            constraints: const BoxConstraints(minHeight: 56),
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: theme.colorScheme.onSurface,
                width: selected ? 3 : 1,
              ),
            ),
            child: Text(
              selected ? '$title — ${AppStrings.selected}' : title,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

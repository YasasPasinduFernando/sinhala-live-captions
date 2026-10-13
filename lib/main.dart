import 'package:flutter/material.dart';
import 'package:whisper_cpp_flutter_plus/whisper_cpp_flutter_plus.dart';

import 'app/sinhala_captions_app.dart';
import 'core/recognition_mode.dart';
import 'features/settings/app_settings_controller.dart';
import 'services/network/network_status.dart';
import 'services/speech/android_live_speech_client.dart';
import 'services/speech/caption_session_controller.dart';
import 'services/speech/catalog_whisper_model_store.dart';
import 'services/speech/device_speech_engine.dart';
import 'services/speech/plugin_whisper_runtime.dart';
import 'services/speech/voice_typing.dart';
import 'services/speech/whisper_model_controller.dart';
import 'services/speech/whisper_speech_engine.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final settings = AppSettingsController();
  await settings.load();
  final speech = AndroidLiveSpeechClient();
  final network = NetworkStatus();
  final models = WhisperModelController(
    CatalogWhisperModelStore(WhisperModelManager()),
  );
  await models.select(settings.whisperModelId);
  final whisper = PluginWhisperRuntime();
  final session = CaptionSessionController(
    engineFactory: (RecognitionMode mode) {
      return switch (mode) {
        RecognitionMode.device => DeviceSpeechEngine(
          client: speech,
          whisperReady: () => models.isVerified,
          voiceTyping: PlatformVoiceTypingClient(),
        ),
        RecognitionMode.whisper => WhisperSpeechEngine(
          runtime: whisper,
          models: models,
        ),
      };
    },
  );
  runApp(
    SinhalaCaptionsApp(
      settings: settings,
      session: session,
      models: models,
      network: network,
    ),
  );
}

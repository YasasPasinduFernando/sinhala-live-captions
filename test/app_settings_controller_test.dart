import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sinhala_live_captions/core/recognition_mode.dart';
import 'package:sinhala_live_captions/features/settings/app_settings_controller.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('settings persist and load again', () async {
    SharedPreferences.setMockInitialValues({});
    final first = AppSettingsController();
    await first.load();
    await first.setFontSize(42);
    await first.setTheme(ThemePreference.dark);
    await first.setHighContrast(true);
    await first.setMode(RecognitionMode.whisper);

    final second = AppSettingsController();
    await second.load();
    expect(second.fontSize, 42);
    expect(second.theme, ThemePreference.dark);
    expect(second.highContrast, isTrue);
    expect(second.mode, RecognitionMode.whisper);
    first.dispose();
    second.dispose();
  });

  test('font size stays inside the supported range', () async {
    SharedPreferences.setMockInitialValues({});
    final settings = AppSettingsController();
    addTearDown(settings.dispose);
    await settings.load();
    await settings.setFontSize(8);
    expect(settings.fontSize, AppSettingsController.minFontSize);
    await settings.setFontSize(90);
    expect(settings.fontSize, AppSettingsController.maxFontSize);
  });
}

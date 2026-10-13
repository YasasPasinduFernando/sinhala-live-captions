import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/recognition_mode.dart';

/// Light or dark appearance. High contrast is stored separately.
enum ThemePreference { light, dark }

/// Persists font size, theme, contrast, and recognition mode only.
class AppSettingsController extends ChangeNotifier {
  AppSettingsController({this._preferences});

  static const fontSizeKey = 'caption_font_size';
  static const themeKey = 'theme_preference';
  static const highContrastKey = 'high_contrast';
  static const modeKey = 'recognition_mode';
  static const whisperModelKey = 'whisper_model_id';

  static const minFontSize = 24.0;
  static const maxFontSize = 72.0;
  static const defaultFontSize = 48.0;

  SharedPreferences? _preferences;
  double fontSize = defaultFontSize;
  ThemePreference theme = ThemePreference.light;
  bool highContrast = false;
  RecognitionMode mode = RecognitionMode.device;
  String whisperModelId = 'tiny';
  var _disposed = false;

  Future<void> load() async {
    _preferences ??= await SharedPreferences.getInstance();
    if (_disposed) {
      return;
    }
    final storedSize = _preferences!.getDouble(fontSizeKey);
    var size = (storedSize ?? defaultFontSize).clamp(minFontSize, maxFontSize);
    if (storedSize != null && storedSize < 40) {
      size = defaultFontSize;
      await _preferences!.setDouble(fontSizeKey, size);
    }
    fontSize = size;
    theme = _preferences!.getString(themeKey) == ThemePreference.dark.name
        ? ThemePreference.dark
        : ThemePreference.light;
    highContrast = _preferences!.getBool(highContrastKey) ?? false;
    mode = _preferences!.getString(modeKey) == RecognitionMode.whisper.name
        ? RecognitionMode.whisper
        : RecognitionMode.device;
    final storedModel = _preferences!.getString(whisperModelKey);
    whisperModelId = storedModel == 'base' ? 'base' : 'tiny';
    _notify();
  }

  Future<void> setFontSize(double value) async {
    fontSize = value.clamp(minFontSize, maxFontSize);
    _notify();
    await _preferences?.setDouble(fontSizeKey, fontSize);
  }

  Future<void> setTheme(ThemePreference value) async {
    theme = value;
    _notify();
    await _preferences?.setString(themeKey, value.name);
  }

  Future<void> setHighContrast(bool value) async {
    highContrast = value;
    _notify();
    await _preferences?.setBool(highContrastKey, value);
  }

  Future<void> setWhisperModel(String id) async {
    if (id != 'tiny' && id != 'base') {
      return;
    }
    if (whisperModelId == id) {
      return;
    }
    whisperModelId = id;
    _notify();
    await _preferences?.setString(whisperModelKey, id);
  }

  Future<void> setMode(RecognitionMode value) async {
    if (mode == value) {
      return;
    }
    mode = value;
    _notify();
    await _preferences?.setString(modeKey, value.name);
  }

  void _notify() {
    if (!_disposed) {
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}

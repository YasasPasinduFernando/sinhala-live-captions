import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sinhala_live_captions/app/sinhala_captions_app.dart';
import 'package:sinhala_live_captions/core/app_strings.dart';
import 'package:sinhala_live_captions/core/recognition_mode.dart';
import 'package:sinhala_live_captions/features/captions/caption_view.dart';
import 'package:sinhala_live_captions/features/captions/live_captions_screen.dart';
import 'package:sinhala_live_captions/features/home/home_screen.dart';
import 'package:sinhala_live_captions/features/settings/app_settings_controller.dart';
import 'package:sinhala_live_captions/features/settings/settings_screen.dart';
import 'package:sinhala_live_captions/services/speech/caption_session_controller.dart';
import 'package:sinhala_live_captions/services/speech/demo_speech_engine.dart';
import 'package:sinhala_live_captions/services/speech/sinhala_locale_probe.dart';
import 'package:sinhala_live_captions/services/speech/speech_engine.dart';
import 'package:sinhala_live_captions/services/speech/whisper_model_controller.dart';

import 'support/fake_device_speech_client.dart';
import 'support/memory_whisper_model_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<({AppSettingsController settings, CaptionSessionController session})>
  pumpApp(
    WidgetTester tester, {
    SpeechEngine Function(RecognitionMode mode)? engineFactory,
  }) async {
    SharedPreferences.setMockInitialValues({});
    final settings = AppSettingsController();
    await settings.load();
    final session = CaptionSessionController(
      engineFactory:
          engineFactory ?? (mode) => DemoSpeechEngine(mode: mode),
    );
    final models = WhisperModelController(MemoryWhisperModelStore());
    await tester.pumpWidget(
      SinhalaCaptionsApp(
        settings: settings,
        session: session,
        models: models,
      ),
    );
    await tester.pump();
    return (settings: settings, session: session);
  }

  testWidgets('home explains device and offline limits', (tester) async {
    await pumpApp(tester);
    expect(find.text(AppStrings.title), findsWidgets);
    expect(find.text(AppStrings.sinhalaTitle), findsOneWidget);
    await tester.scrollUntilVisible(find.text(AppStrings.phaseNotice), 300);
    expect(find.text(AppStrings.phaseNotice), findsOneWidget);
    expect(find.text(AppStrings.modelStatus), findsOneWidget);
    expect(find.byIcon(Icons.mic), findsNothing);
    expect(find.byIcon(Icons.mic_none), findsNothing);
  });

  testWidgets('home opens captions and settings', (tester) async {
    await pumpApp(tester);
    await tester.tap(find.byKey(HomeScreen.startKey));
    await tester.pumpAndSettle();
    expect(find.byKey(LiveCaptionsScreen.startKey), findsOneWidget);
    expect(find.text(AppStrings.captionsIdleNote), findsOneWidget);

    await tester.tap(find.byTooltip(AppStrings.back));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(HomeScreen.settingsKey));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text(AppStrings.privacy), 300);
    expect(find.text(AppStrings.privacy), findsOneWidget);
    expect(find.text(AppStrings.modelActionsUnavailable), findsNothing);
    expect(
      tester
          .widget<FilledButton>(
            find.widgetWithText(FilledButton, AppStrings.downloadModel),
          )
          .onPressed,
      isNotNull,
    );
    expect(
      tester
          .widget<OutlinedButton>(
            find.widgetWithText(OutlinedButton, AppStrings.removeModel),
          )
          .onPressed,
      isNull,
    );
  });

  testWidgets('font size, theme, contrast, and mode update the interface', (
    tester,
  ) async {
    final harness = await pumpApp(tester);
    await harness.settings.setFontSize(40);
    await harness.settings.setTheme(ThemePreference.dark);
    await harness.settings.setHighContrast(true);
    await harness.settings.setMode(RecognitionMode.whisper);
    await tester.pump();

    final home = tester.element(find.byType(HomeScreen));
    expect(Theme.of(home).brightness, Brightness.dark);
    expect(Theme.of(home).colorScheme.surface, Colors.black);
    expect(harness.session.mode, RecognitionMode.whisper);

    await tester.tap(find.byKey(HomeScreen.startKey));
    await tester.pumpAndSettle();
    final caption = tester.widget<Text>(find.byKey(CaptionView.confirmedKey));
    expect(caption.style?.fontSize, 40);
  });

  testWidgets('settings controls change saved preferences', (tester) async {
    final harness = await pumpApp(tester);
    await tester.tap(find.byKey(HomeScreen.settingsKey));
    await tester.pumpAndSettle();

    tester
        .widget<Slider>(find.byKey(SettingsScreen.fontSliderKey))
        .onChanged!
        .call(36);
    await tester.ensureVisible(find.byKey(SettingsScreen.darkKey));
    await tester.tap(find.byKey(SettingsScreen.darkKey));
    await tester.ensureVisible(find.byKey(SettingsScreen.contrastKey));
    await tester.tap(find.byKey(SettingsScreen.contrastKey));
    await tester.ensureVisible(find.byKey(SettingsScreen.whisperModeKey));
    await tester.tap(find.byKey(SettingsScreen.whisperModeKey));
    await tester.pumpAndSettle();

    expect(harness.settings.fontSize, 36);
    expect(harness.settings.theme, ThemePreference.dark);
    expect(harness.settings.highContrast, isTrue);
    expect(harness.settings.mode, RecognitionMode.whisper);
    expect(harness.session.mode, RecognitionMode.whisper);
  });

  testWidgets('demo start shows sample text and stop keeps the microphone off', (
    tester,
  ) async {
    final harness = await pumpApp(tester);
    await tester.tap(find.byKey(HomeScreen.startKey));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(LiveCaptionsScreen.startKey));
    await tester.pump();
    expect(find.text(AppStrings.demoShowing), findsOneWidget);
    expect(harness.session.capabilities?.usesMicrophone, isFalse);

    await tester.pump(const Duration(milliseconds: 120));
    expect(find.text(AppStrings.demoConfirmed), findsOneWidget);
    expect(find.textContaining('[උදාහරණය]'), findsWidgets);
    expect(find.byIcon(Icons.mic), findsNothing);
  });

  testWidgets('stop prevents the demo from adding captions', (tester) async {
    await pumpApp(tester);
    await tester.tap(find.byKey(HomeScreen.startKey));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(LiveCaptionsScreen.startKey));
    await tester.pump();
    await tester.tap(find.byKey(LiveCaptionsScreen.stopKey));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.text(AppStrings.demoConfirmed), findsNothing);
    expect(find.text(AppStrings.stopped), findsOneWidget);
  });

  testWidgets('clear removes demo captions', (tester) async {
    await pumpApp(tester);
    await tester.tap(find.byKey(HomeScreen.startKey));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(LiveCaptionsScreen.startKey));
    await tester.pump(const Duration(milliseconds: 120));
    expect(find.text(AppStrings.demoConfirmed), findsOneWidget);
    await tester.tap(find.byKey(LiveCaptionsScreen.clearKey));
    await tester.pump();
    expect(find.text(AppStrings.demoConfirmed), findsNothing);
    expect(find.text(AppStrings.emptyCaptions), findsWidgets);
  });

  testWidgets('unavailable and failed demo sessions show errors', (tester) async {
    await pumpApp(
      tester,
      engineFactory: (mode) => DemoSpeechEngine(mode: mode, available: false),
    );
    await tester.tap(find.byKey(HomeScreen.startKey));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(LiveCaptionsScreen.startKey));
    await tester.pumpAndSettle();
    expect(find.text(AppStrings.engineUnavailable), findsOneWidget);
    expect(find.byIcon(Icons.error_outline), findsOneWidget);

    await tester.tap(find.byTooltip(AppStrings.back));
    await tester.pumpAndSettle();
  });

  testWidgets('a failed start shows a recoverable error', (tester) async {
    await pumpApp(
      tester,
      engineFactory: (mode) => DemoSpeechEngine(mode: mode, failOnStart: true),
    );
    await tester.tap(find.byKey(HomeScreen.startKey));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(LiveCaptionsScreen.startKey));
    await tester.pumpAndSettle();
    expect(find.text(AppStrings.engineStartFailed), findsOneWidget);
    expect(find.byIcon(Icons.error_outline), findsOneWidget);
  });

  testWidgets('long Sinhala text wraps at the caption font size', (tester) async {
    const longText = 'සිංහල උපසිරැසි පෙළ දිගට යයි ';
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: CaptionView(
            confirmedText: '$longText$longText$longText$longText',
            provisional: 'තාවකාලික සිංහල',
            fontSize: 32,
          ),
        ),
      ),
    );
    final confirmed = tester.widget<Text>(find.byKey(CaptionView.confirmedKey));
    expect(confirmed.softWrap, isTrue);
    expect(confirmed.data, contains('සිංහල'));
    expect(confirmed.style?.fontSize, 32);
    expect(tester.takeException(), isNull);
  });

  testWidgets('home stays usable on a small screen with large text', (tester) async {
    tester.view.physicalSize = const Size(320, 480);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await pumpApp(tester);
    await tester.scrollUntilVisible(find.byKey(HomeScreen.startKey), 200);
    expect(find.byKey(HomeScreen.startKey), findsOneWidget);
    await tester.scrollUntilVisible(find.text(AppStrings.phaseNotice), 200);
    expect(find.text(AppStrings.phaseNotice), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('diagnostic button shows progress and the locale error', (
    tester,
  ) async {
    final harness = await _probeScreen(tester);
    addTearDown(harness.session.dispose);
    addTearDown(harness.settings.dispose);
    harness.client
      ..scriptedError = 'error_language_unavailable'
      ..listenGate = Completer<void>();

    await tester.tap(find.byKey(LiveCaptionsScreen.localeProbeKey));
    await tester.pump();
    expect(find.textContaining('Requesting si-LK'), findsOneWidget);
    harness.client.listenGate!.complete();

    await tester.pumpAndSettle();
    expect(find.textContaining('locale unsupported'), findsOneWidget);
    expect(harness.client.requestedLocales, ['si-LK', 'si_LK']);
    expect(harness.client.listening, isFalse);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a silent diagnostic reports timeout inside the scroll view', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 560);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final harness = await _probeScreen(
      tester,
      locales: List<String>.generate(30, (index) => 'en_$index'),
    );
    addTearDown(harness.session.dispose);
    addTearDown(harness.settings.dispose);
    harness.client.silentListen = true;

    await tester.tap(find.byKey(LiveCaptionsScreen.localeProbeKey));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    await tester.ensureVisible(find.textContaining('si_LK: timeout'));
    expect(find.textContaining('si_LK: timeout'), findsOneWidget);
    expect(harness.client.listening, isFalse);
  });
}

Future<
  ({
    AppSettingsController settings,
    CaptionSessionController session,
    FakeDeviceSpeechClient client,
  })
>
_probeScreen(WidgetTester tester, {List<String>? locales}) async {
  SharedPreferences.setMockInitialValues({});
  final settings = AppSettingsController();
  await settings.load();
  final session = CaptionSessionController(
    engineFactory: (mode) => DemoSpeechEngine(mode: mode),
  );
  final client = FakeDeviceSpeechClient()
    ..locales = locales ?? ['en_US'];
  await tester.pumpWidget(
    MaterialApp(
      home: LiveCaptionsScreen(
        settings: settings,
        session: session,
        localeProbe: SinhalaLocaleProbe(
          client,
          attemptTimeout: const Duration(milliseconds: 40),
          pollInterval: const Duration(milliseconds: 1),
        ),
      ),
    ),
  );
  await tester.pump();
  return (settings: settings, session: session, client: client);
}

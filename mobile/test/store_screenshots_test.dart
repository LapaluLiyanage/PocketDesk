// SPDX-License-Identifier: GPL-3.0-or-later
// Store screenshots (F-Droid, the website), rendered from the real screens
// with real fonts. Skipped unless asked for:
//
//   POCKETDESK_SCREENSHOTS=../fastlane/metadata/android/en-US/images/phoneScreenshots \
//     flutter test test/store_screenshots_test.dart
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pocketdesk/agent_connection.dart';
import 'package:pocketdesk/app_model.dart';
import 'package:pocketdesk/files/native_files.dart';
import 'package:pocketdesk/files/share_inbox.dart';
import 'package:pocketdesk/files/transfers.dart';
import 'package:pocketdesk/pairing/identity.dart';
import 'package:pocketdesk/pairing/laptop.dart';
import 'package:pocketdesk/screens/about_screen.dart';
import 'package:pocketdesk/screens/control_screen.dart';
import 'package:pocketdesk/screens/home_screen.dart';
import 'package:pocketdesk/screens/settings_screen.dart';
import 'package:pocketdesk/settings/app_settings.dart';
import 'package:pocketdesk/ui/pocket_style.dart';
import 'package:shared_preferences/shared_preferences.dart';

final outDir = Platform.environment['POCKETDESK_SCREENSHOTS'];

class ShowcaseConnection extends AgentConnection {
  ShowcaseConnection({required super.tempDir})
    : super(
        saveFile: (temp, name) async => SavedFile(where: 'Download/PocketDesk/$name', uri: 'content://x'),
      );

  @override
  ConnectionStatus get status => ConnectionStatus.connected;
  @override
  Set<String> get features => {'combo', 'power', 'apps', 'screen', 'clipboard', 'files'};
  @override
  Allowed get allowed =>
      const Allowed(power: true, session: true, apps: true, screen: true, clipboard: true, files: true);
  @override
  String? get agentOs => 'windows';
  @override
  String? get agentName => 'Sandun-Laptop';

  @override
  Future<AppsList> fetchApps() async => const AppsList(
    shortcuts: [
      RemoteApp(id: 's1', name: 'Lecture slides', kind: 'folder'),
      RemoteApp(id: 's2', name: 'University portal', kind: 'url'),
    ],
    apps: [
      RemoteApp(id: 'a1', name: 'Calculator', kind: 'app'),
      RemoteApp(id: 'a2', name: 'File Explorer', kind: 'app'),
      RemoteApp(id: 'a3', name: 'Firefox', kind: 'app'),
      RemoteApp(id: 'a4', name: 'LibreOffice Impress', kind: 'app'),
      RemoteApp(id: 'a5', name: 'Spotify', kind: 'app'),
      RemoteApp(id: 'a6', name: 'Visual Studio Code', kind: 'app'),
      RemoteApp(id: 'a7', name: 'VLC media player', kind: 'app'),
    ],
  );
}

Future<void> loadFonts() async {
  final dir = '${Platform.environment['FLUTTER_ROOT'] ?? '/opt/flutter'}/bin/cache/artifacts/material_fonts';
  Future<ByteData> f(String name) async => ByteData.sublistView(await File('$dir/$name').readAsBytes());
  await (FontLoader('Roboto')
        ..addFont(f('Roboto-Regular.ttf'))
        ..addFont(f('Roboto-Medium.ttf'))
        ..addFont(f('Roboto-Bold.ttf')))
      .load();
  await (FontLoader('MaterialIcons')..addFont(f('MaterialIcons-Regular.otf'))).load();
  // The app's own font (one variable font; real phones apply the weights).
  await (FontLoader(
    'Manrope',
  )..addFont(File('assets/fonts/Manrope.ttf').readAsBytes().then((b) => ByteData.sublistView(b)))).load();
  // Phones fall back to other fonts for symbols such as →; so does this.
  const dejavu = '/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf';
  if (File(dejavu).existsSync()) {
    await (FontLoader(
      'Fallback',
    )..addFont(File(dejavu).readAsBytes().then((b) => ByteData.sublistView(b)))).load();
  }
}

ThemeData theme({bool dark = false}) => pocketTheme(dark: dark);

void main() {
  final shotKey = GlobalKey();
  late Directory tmp;

  setUpAll(() async {
    if (outDir != null) await loadFonts();
  });
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    tmp = Directory.systemTemp.createTempSync('pocketdesk-shots');
  });
  tearDown(() => tmp.deleteSync(recursive: true));

  Future<void> phone(WidgetTester tester, Widget home, {bool dark = false}) async {
    // A touch screen: no keyboard focus rings; real shadows, not the test
    // framework's outlines.
    FocusManager.instance.highlightStrategy = FocusHighlightStrategy.alwaysTouch;
    debugDisableShadows = false;
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (_) async => null,
    );
    await tester.pumpWidget(
      RepaintBoundary(
        key: shotKey,
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: theme(dark: dark),
          home: home,
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> shoot(WidgetTester tester, String name) async {
    await tester.pumpAndSettle();
    final boundary = tester.renderObject<RenderRepaintBoundary>(find.byKey(shotKey));
    final bytes = await tester.runAsync(() async {
      final image = await boundary.toImage(pixelRatio: 3);
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      return data!.buffer.asUint8List();
    });
    File('$outDir/$name.png')
      ..createSync(recursive: true)
      ..writeAsBytesSync(bytes!);
  }

  Widget control(AgentConnection c) => ControlScreen(
    connection: c,
    laptopKey: 'k',
    inbox: ShareInbox(take: () async => const SharedItems()),
  );

  testWidgets('screenshots', skip: outDir == null, (tester) async {
    // 1. Paired computers.
    final model = await tester.runAsync(
      () async => AppModel(
        identity: await PhoneIdentity.fromSeed(List.filled(32, 1)),
        store: LaptopStore(),
        laptops: [
          Laptop(
            fingerprint: Uint8List(32),
            name: 'Sandun-Laptop',
            port: 47800,
            addresses: ['192.168.1.5', '100.101.102.103'],
            os: 'windows',
          ),
          Laptop(
            fingerprint: Uint8List.fromList(List.filled(32, 2)),
            name: 'ubuntu-desktop',
            port: 47800,
            addresses: ['192.168.1.9'],
            os: 'linux',
          ),
        ],
        phoneName: 'Pixel 8',
        connection: AgentConnection(),
      )..autoConnectDone = true,
    );
    await phone(tester, HomeScreen(model: model!));
    await shoot(tester, '1_computers');

    // 2. Touchpad.
    final conn = ShowcaseConnection(tempDir: tmp);
    await phone(tester, control(conn));
    await shoot(tester, '2_touchpad');

    // 3. Buttons.
    await tester.tap(find.text('Buttons'));
    await shoot(tester, '3_buttons');

    // 4. Apps.
    await tester.tap(find.text('Apps'));
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
    await shoot(tester, '4_apps');

    // 5. Clipboard and files.
    await tester.tap(find.text('Touchpad'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Clipboard and files'));
    await shoot(tester, '5_clipboard_files');
    // 6. Power.
    await phone(tester, control(conn));
    await tester.tap(find.text('Power'));
    await shoot(tester, '6_power');

    // 7. Settings and About.
    final settings = await tester.runAsync(AppSettings.load);
    await phone(tester, SettingsScreen(settings: settings!));
    await shoot(tester, '7_settings');
    await phone(tester, const AboutScreen());
    await shoot(tester, '8_about');

    // 9. Dark.
    await phone(tester, HomeScreen(model: model), dark: true);
    await shoot(tester, '9_computers_dark');
    await phone(tester, control(conn), dark: true);
    await shoot(tester, '9_touchpad_dark');
    debugDisableShadows = true; // the framework checks it is back to normal
  });
}

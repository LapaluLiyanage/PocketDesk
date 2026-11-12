// SPDX-License-Identifier: GPL-3.0-or-later
import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';

import 'app_model.dart';
import 'files/share_inbox.dart';
import 'screens/home_screen.dart';
import 'settings/app_lock.dart';
import 'update_check.dart';
import 'update_install.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final model = await AppModel.load();
  ShareInbox.instance.start();
  final updates = await _updateChecker();
  runApp(
    PocketDeskApp(
      model: model,
      updates: updates,
      installer: updates == null ? null : UpdateInstaller(cacheDir: _updateCache),
    ),
  );
  updates?.checkIfDue();
}

/// Where a downloaded APK waits until Android installs it: the app's own
/// temporary space, which Android clears by itself if the install never
/// happens. Only PocketDesk can read it.
Future<Directory> _updateCache() async {
  final dir = Directory('${Directory.systemTemp.path}/pocketdesk-updates');
  if (!dir.existsSync()) await dir.create(recursive: true);
  // One update at a time: drop anything an earlier try left behind.
  for (final old in dir.listSync()) {
    try {
      await old.delete(recursive: true);
    } catch (_) {}
  }
  return dir;
}

/// GitHub builds look for new releases; F-Droid builds leave that to F-Droid.
Future<UpdateChecker?> _updateChecker() async {
  if (updatesFrom != 'github' || !Platform.isAndroid) return null;
  try {
    final info = await PackageInfo.fromPlatform();
    final android = await DeviceInfoPlugin().androidInfo;
    return UpdateChecker(currentVersion: info.version, abis: android.supportedAbis);
  } catch (_) {
    return null;
  }
}

class PocketDeskApp extends StatelessWidget {
  const PocketDeskApp({super.key, required this.model, this.updates, this.installer});

  final AppModel model;
  final UpdateChecker? updates;

  /// Downloads and installs an update; made only when [updates] is.
  final UpdateInstaller? installer;

  @override
  Widget build(BuildContext context) {
    // The design pass: near-black ink on white, one red accent.
    const ink = Color(0xFF1C1C1D);
    const red = Color(0xFFE3352B);
    final light = ColorScheme.fromSeed(seedColor: ink).copyWith(
      primary: ink,
      onPrimary: Colors.white,
      secondary: red,
      onSecondary: Colors.white,
      surface: Colors.white,
      onSurface: ink,
    );
    final dark = ColorScheme.fromSeed(seedColor: ink, brightness: Brightness.dark).copyWith(
      primary: Colors.white,
      onPrimary: ink,
      secondary: const Color(0xFFFF4A3D),
      onSecondary: Colors.white,
      surface: const Color(0xFF0E0E0F),
      onSurface: const Color(0xFFFAFAFA),
    );
    return MaterialApp(
      title: 'PocketDesk',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: light,
        fontFamily: 'Manrope',
        scaffoldBackgroundColor: const Color(0xFFFAFAFA),
        extensions: const [PocketColors.light],
      ),
      darkTheme: ThemeData(
        colorScheme: dark,
        fontFamily: 'Manrope',
        scaffoldBackgroundColor: const Color(0xFF0E0E0F),
        extensions: const [PocketColors.dark],
      ),
      builder: (context, child) {
        final settings = model.settings;
        if (settings == null || child == null) return child ?? const SizedBox.shrink();
        return AppLockGate(settings: settings, child: child);
      },
      home: HomeScreen(model: model, updates: updates, installer: installer),
    );
  }
}

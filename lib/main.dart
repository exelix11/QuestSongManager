import 'dart:io';

import 'package:bsaberquest/download_manager/downloader.dart';
import 'package:bsaberquest/main_page.dart';
import 'package:bsaberquest/preferences.dart';
import 'package:flutter/material.dart';

import 'mod_manager/mod_manager.dart';

void main() {
  runApp(const App());
}

class App extends StatelessWidget {
  // Hardcoded path for local PC development and testing
  static final ModManager modManager = ModManager(Platform.isAndroid
      ? "/sdcard/ModData/com.beatgames.beatsaber"
      : "/home/user/bsaberquest/sd/ModData/com.beatgames.beatsaber");

  static final DownloadManager downloadManager = DownloadManager();

  static final PreferencesManager preferences = PreferencesManager();

  static final GlobalKey<ScaffoldMessengerState> _scaffoldMessengerKey =
      GlobalKey<ScaffoldMessengerState>();

  // A plain msgbox-like function, as god intended
  static void showToast(String message) {
    App._scaffoldMessengerKey.currentState?.showSnackBar(SnackBar(
      content: Text(message),
    ));
  }

  const App({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      scaffoldMessengerKey: _scaffoldMessengerKey,
      title: 'Flutter Demo',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const MainPage(),
    );
  }
}

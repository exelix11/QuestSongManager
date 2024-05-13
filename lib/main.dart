import 'dart:io';

import 'package:bsaberquest/download_manager/downloader.dart';
import 'package:bsaberquest/main_page.dart';
import 'package:bsaberquest/options/preferences.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import 'mod_manager/mod_manager.dart';

void main() {
  runApp(const App());
}

class App extends StatelessWidget {
  static const bool _devSimulateQuest = false;

  static final bool isDev = _devSimulateQuest && !Platform.isAndroid;
  static final bool isQuest = Platform.isAndroid || _devSimulateQuest;

  static late ModManager modManager;

  static final DownloadManager downloadManager = DownloadManager();

  static final PreferencesManager preferences = PreferencesManager();

  static final GlobalKey<ScaffoldMessengerState> _scaffoldMessengerKey =
      GlobalKey<ScaffoldMessengerState>();

  // A plain msgbox-like function, as god intended
  static void showToast(String message) {
    SchedulerBinding.instance.addPostFrameCallback((_) {
      App._scaffoldMessengerKey.currentState?.showSnackBar(SnackBar(
        content: Text(message),
      ));
    });
  }

  const App({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      scaffoldMessengerKey: _scaffoldMessengerKey,
      title: 'QuestSongManager',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const MainPage(),
    );
  }
}

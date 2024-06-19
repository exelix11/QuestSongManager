import 'dart:io';

import 'package:bsaberquest/download_manager/map_update_controller.dart';
import 'package:bsaberquest/download_manager/beat_saver_api.dart';
import 'package:bsaberquest/download_manager/downloader.dart';
import 'package:bsaberquest/main_page.dart';
import 'package:bsaberquest/options/preferences.dart';
import 'package:bsaberquest/rpc/rpc_manager.dart';
import 'package:bsaberquest/rpc/schema_parser.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import 'mod_manager/mod_manager.dart';

Future main(List<String> arguments) async {
  WidgetsFlutterBinding.ensureInitialized();

  await App.preferences.init();

  if (Platform.isWindows) {
    App.rpc = RpcManager();
    var res = await App.rpc!.initialize();

    for (var cmd in arguments
        .map((e) => BsSchemaParser.parse(e))
        .where((x) => x != null)) {
      await App.rpc!.sendCommand(cmd!);
    }

    if (res == InitResult.child) exit(0);
  }

  runApp(const App());
}

class App extends StatelessWidget {
  static const bool _devSimulateQuest = false;
  static const String versionName = "1.4-dev";

  static final bool isDev = _devSimulateQuest && !Platform.isAndroid;
  static final bool isQuest = Platform.isAndroid || _devSimulateQuest;

  static late ModManager modManager;

  static RpcManager? rpc;

  static final DownloadManager downloadManager = DownloadManager();

  static final PreferencesManager preferences = PreferencesManager();

  static final BeatSaverClient beatSaverClient = BeatSaverClient();

  static final MapUpdateController mapUpdates = MapUpdateController();

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
      title: 'Song manager',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const MainPage(),
    );
  }
}

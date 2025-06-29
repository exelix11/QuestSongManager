import 'dart:io';

import 'package:bsaberquest/app_initialization_page.dart';
import 'package:bsaberquest/download_manager/map_update_controller.dart';
import 'package:bsaberquest/download_manager/beat_saver_api.dart';
import 'package:bsaberquest/download_manager/downloader.dart';
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

class _AppState extends State<App> {
  ThemeMode _themeMode = ThemeMode.light;

  @override
  void initState() {
    super.initState();

    if (App.preferences.darkTheme) _themeMode = ThemeMode.dark;
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
        scaffoldMessengerKey: App._scaffoldMessengerKey,
        title: 'Song manager',
        themeMode: _themeMode,
        darkTheme: ThemeData.dark(),
        theme: ThemeData.light(),
        home: const AppInitializationPage(),
        debugShowCheckedModeBanner: false);
  }

  static _AppState of(BuildContext context) =>
      context.findAncestorStateOfType<_AppState>()!;

  void changeTheme(ThemeMode themeMode) {
    setState(() {
      _themeMode = themeMode;
    });
  }
}

class App extends StatefulWidget {
  static const String versionName = "1.5.3";

  static const bool _devSimulateQuest = false;
  static const String devQuestSimulateRoot =
      "/home/user/bsaberquest/test_sd_root/ModData/com.beatgames.beatsaber";

  static final bool isQuestSimulator = _devSimulateQuest && !Platform.isAndroid;
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

  static void changeTheme(BuildContext context, ThemeMode themeMode) {
    _AppState.of(context).changeTheme(themeMode);
  }

  const App({super.key});

  @override
  State<StatefulWidget> createState() => _AppState();
}

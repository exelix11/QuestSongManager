import 'dart:async';
import 'dart:io';

import 'package:bsaberquest/download_manager/gui/downloads_tab.dart';
import 'package:bsaberquest/download_manager/gui/util.dart';
import 'package:bsaberquest/gui_util.dart';
import 'package:bsaberquest/mod_manager/mod_manager.dart';
import 'package:bsaberquest/options/options_page.dart';
import 'package:bsaberquest/main.dart';
import 'package:bsaberquest/mod_manager/gui/playlist_list_page.dart';
import 'package:bsaberquest/mod_manager/gui/song_list_page.dart';
import 'package:flutter/material.dart';

import 'options/game_path_picker_page.dart';
import 'options/quest_install_location_options.dart';
import 'rpc/rpc_manager.dart';

class MainPageState extends State<MainPage> {
  late Future _init;
  String _hintText = "";
  StreamSubscription<RpcCommand>? _rpcSubscription;

  @override
  void initState() {
    _init = _initialize();
    super.initState();
  }

  @override
  void dispose() {
    _rpcSubscription?.cancel();
    super.dispose();
  }

  Future<String?> _getGameRootPath() async {
    // For dev when simulating a quest use this path
    if (App.isQuest && App.isDev) {
      return "/home/user/bsaberquest/test_sd_root";
    }

    // On a quest use the default path
    if (App.isQuest) {
      return "/sdcard/ModData/com.beatgames.beatsaber";
    }

    // On PC we must use the path provided by the user
    var gamePath = await App.preferences.getGameRootPath();
    if (gamePath == null) {
      if (mounted) {
        await Navigator.push(
            context,
            MaterialPageRoute(
                builder: (context) => const GamePathPickerPage(false)));
      } else {
        throw Exception("Failed to open game path picker");
      }

      gamePath = await App.preferences.getGameRootPath();
    }
    return gamePath;
  }

  Future _initialize() async {
    var gamePath = await _getGameRootPath();
    if (gamePath == null) {
      if (mounted) {
        await GuiUtil.longTextDialog(
            context, "Error", "Failed to get the game path");
      }
      exit(0);
    }

    App.modManager = ModManager(gamePath);

    var opt = await App.preferences.useHashCache();
    App.modManager.useFastHashCache = opt;

    // Redraw the UI to update in case loading opt was slow
    setState(() {
      _hintText = App.modManager.useFastHashCache
          ? "During the first start the app caches all the song hashses, future starts will be faster"
          : "Consider enabling hash caches to speed up the app start up times";
    });

    if (App.isQuest) {
      try {
        var preferred = await App.preferences.getPreferredCustomSongFolder();
        await QuestInstallLocationOptions.setLocation(preferred);
      } catch (e) {
        App.showToast('Failed to set install location: $e');
        // This is not a critical error, we can continue
      }
    }

    try {
      await App.modManager.reloadIfNeeded();
    } catch (e) {
      if (await _androidCheckErrorFilePermissions(e)) return;
      App.showToast("Initialization error: $e");
      return;
    }

    // If everything went well try to process pending messages
    if (App.rpc != null) {
      _rpcSubscription = App.rpc!.subscribeEvents(_processRpcCommand);
    }
  }

  Future<bool> _androidCheckErrorFilePermissions(dynamic e) async {
    if (!App.isQuest) return false;

    if (e is FileSystemException && e.osError?.errorCode == 13) {
      if (!await App.preferences.isFirstLaunchPermissionRequested()) {
        if (await OptionsPageState.requestFileAccess()) {
          setState(() {
            _init = _initialize();
          });
          // Ignore the error and  try again
          return true;
        }
      }
    }

    return false;
  }

  void _processRpcCommand(RpcCommand cmd) async {
    if (cmd.isSongDownload) {
      DownloadUtil.downloadById(cmd.args[0], null);
    } else if (cmd.isPlaylistDownload) {
      DownloadUtil.downloadPlaylist(context, cmd.args[0], null);
    }
  }

  Widget _buildLoader() {
    return Scaffold(
      appBar: AppBar(title: const Text('Loading')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('Loading song list...', style: TextStyle(fontSize: 20)),
            const SizedBox(height: 20),
            const SizedBox(
                height: 100, width: 100, child: CircularProgressIndicator()),
            const SizedBox(height: 50),
            Text(_hintText),
          ],
        ),
      ),
    );
  }

  Widget _buildMainView() {
    return DefaultTabController(
      length: 4,
      child: Scaffold(
        appBar: AppBar(
          title: const TabBar(tabs: [
            Tab(icon: Icon(Icons.music_note)),
            Tab(icon: Icon(Icons.list)),
            Tab(icon: Icon(Icons.wifi)),
            Tab(icon: Icon(Icons.settings)),
          ]),
        ),
        body: const TabBarView(
          children: [
            SongsListPage(),
            PlaylistListPage(),
            DownloadsTab(),
            OptionsPage()
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
        future: _init,
        builder: (ctx, state) {
          if (state.connectionState == ConnectionState.done) {
            return _buildMainView();
          } else {
            return _buildLoader();
          }
        });
  }
}

class MainPage extends StatefulWidget {
  const MainPage({super.key});

  @override
  State<MainPage> createState() => MainPageState();
}

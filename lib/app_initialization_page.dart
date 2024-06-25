import 'dart:io';

import 'package:bsaberquest/main.dart';
import 'package:bsaberquest/main_page.dart';
import 'package:bsaberquest/mod_manager/mod_manager.dart';
import 'package:bsaberquest/mod_manager/version_detector.dart';
import 'package:bsaberquest/options/game_path_picker_page.dart';
import 'package:bsaberquest/options/options_page.dart';
import 'package:bsaberquest/options/quest_install_location_options.dart';
import 'package:bsaberquest/util/gui_util.dart';
import 'package:flutter/material.dart';

class AppInitializationPageState extends State<AppInitializationPage> {
  String _hintText = "";

  AppInitializationPageState() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initApplication();
    });
  }

  Future<String?> _getGameRootPath() async {
    // For dev when simulating a quest use this path
    if (App.isQuest && App.isDev) {
      return "/home/user/bsaberquest/test_sd_root/ModData/com.beatgames.beatsaber";
    }

    // On a quest use the default path
    if (App.isQuest) {
      return "/sdcard/ModData/com.beatgames.beatsaber";
    }

    // On PC we must use the path provided by the user
    var gamePath = App.preferences.gameRootPath;
    if (gamePath == null) {
      await Navigator.push(
          context,
          MaterialPageRoute(
              builder: (context) => const GamePathPickerPage(false)));

      gamePath = App.preferences.gameRootPath;
    }
    return gamePath;
  }

  Future<bool> _androidCheckErrorFilePermissions(dynamic e) async {
    if (!App.isQuest) return false;

    if (e is FileSystemException && e.osError?.errorCode == 13) {
      if (!App.preferences.isFirstLaunchPermissionRequested()) {
        if (await OptionsPageState.requestFileAccess()) {
          // Ignore the error and  try again
          return true;
        }
      }
    }

    return false;
  }

  void _initApplication() async {
    var gamePath = await _getGameRootPath();
    if (gamePath == null) {
      if (mounted) {
        await GuiUtil.longTextDialog(
            context, "Error", "Failed to get the game path");
      }
      exit(0);
    }

    App.modManager = ModManager(gamePath);
    App.modManager.useFastHashCache = App.preferences.useHashCache;

    // Redraw the UI to update in case loading opt was slow
    setState(() {
      _hintText = App.modManager.useFastHashCache
          ? "During the first start the app caches all the song hashses, future starts will be faster"
          : "Consider enabling hash caches to speed up the app start up times";
    });

    if (App.isQuest) {
      try {
        await BeatSaberVersionDetector.initializeBeatSaberVersion();
        var preferred = App.preferences.preferredCustomSongFolder;
        await QuestInstallLocationOptions.setLocation(preferred);
      } catch (e) {
        App.showToast('Failed to set install location: $e');
        // This is not a critical error, we can continue
      }
    }

    try {
      await App.modManager.reloadIfNeeded();
    } catch (e) {
      if (await _androidCheckErrorFilePermissions(e)) {
        // Try again
        try {
          await App.modManager.reloadIfNeeded();
        } catch (e) {
          App.showToast("Initialization error: $e");
          return;
        }
      } else {
        App.showToast("Initialization error: $e");
        return;
      }
    }

    // Try to apply preferences
    {
      var autoDownload = App.preferences.autoDownloadPlaylist;
      if (autoDownload != null) {
        var playlist = App.modManager.playlists[autoDownload];
        if (playlist != null) {
          App.downloadManager.downloadToPlaylist = playlist;
        }
      }
    }

    await App.beatSaverClient.tryLoginFromStoredCredentials();

    App.mapUpdates.doAutoUpdateCheckIfNeeded();
    //App.downloadManager.addTestElements();

    // Finally, replace this page with the main page
    if (!mounted) {
      App.showToast("Failed to launch the main page");
      return;
    }

    Navigator.pushReplacement(
        context, MaterialPageRoute(builder: (_) => const MainPage()));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('Loading ...', style: TextStyle(fontSize: 20)),
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
}

class AppInitializationPage extends StatefulWidget {
  const AppInitializationPage({super.key});

  @override
  State<StatefulWidget> createState() => AppInitializationPageState();
}

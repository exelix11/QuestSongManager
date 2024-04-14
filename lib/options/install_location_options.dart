import 'package:bsaberquest/main.dart';
import 'package:bsaberquest/mod_manager/mod_manager.dart';
import 'package:bsaberquest/mod_manager/version_detector.dart';
import 'package:bsaberquest/options/preferences.dart';
import 'package:flutter/material.dart';

class InstallLocationOptions {
  InstallLocationOptions._();

  static Future setLocation(PreferredCustomSongFolder folder) async {
    if (folder == PreferredCustomSongFolder.auto) {
      var version = await BeatSaberVersionDetector.getBeatSaberVersion();

      switch (version) {
        // In case detection fails, default to the most compatible location
        case BeatSaberVersion.unknown:
        case BeatSaberVersion.olderThan_v_1_35:
          App.modManager.preferredInstallLocation =
              CustomLevelLocation.songLoader;
          break;
        case BeatSaberVersion.v_1_35_OrNewer:
          App.modManager.preferredInstallLocation =
              CustomLevelLocation.songCore;
          break;
        default:
          throw Exception('Unsupported Beat Saber version: $version');
      }
    } else {
      App.modManager.preferredInstallLocation =
          folder == PreferredCustomSongFolder.songLoader
              ? CustomLevelLocation.songLoader
              : CustomLevelLocation.songCore;
    }
  }
}

// ignore: must_be_immutable
class InstallLocationPage extends StatelessWidget {
  // Location change is really fast but prevent race conditions due to async and user spamming
  bool _applying = false;
  final PreferredCustomSongFolder currentOption;

  InstallLocationPage(this.currentOption, {super.key});

  void _applyMode(BuildContext ctx, PreferredCustomSongFolder folder) async {
    if (_applying) return;
    _applying = true;

    try {
      await InstallLocationOptions.setLocation(folder);
      await App.preferences.setPreferredCustomSongFolder(folder);
      App.showToast('Default install location modified.');

      if (ctx.mounted) {
        Navigator.pop(ctx);
      }
    } catch (e) {
      App.showToast('Failed to set install location: $e');
    }

    _applying = false;
  }

  Widget _labelFor(PreferredCustomSongFolder mode) {
    var name = "";
    switch (mode) {
      case PreferredCustomSongFolder.songLoader:
        name = "Song Loader";
        break;
      case PreferredCustomSongFolder.songCore:
        name = "Song Core";
        break;
      case PreferredCustomSongFolder.auto:
        name = "Auto-detect";
        break;
    }

    if (mode == currentOption) {
      name += " (current)";
    }

    return Text(name);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
          title: const Text('Select song install location'),
        ),
        body: Column(children: [
          Expanded(
              child: ListView(
            children: [
              ListTile(
                title: _labelFor(PreferredCustomSongFolder.songLoader),
                subtitle: const Text(
                    "This is the install location for Beat Saber versions prior to 1.35. This is the most compatible option as it will work with all versions."),
                onTap: () =>
                    _applyMode(context, PreferredCustomSongFolder.songLoader),
              ),
              ListTile(
                title: _labelFor(PreferredCustomSongFolder.songCore),
                subtitle: const Text(
                    "This is the new install location for Beat Saber versions 1.35 and newer. If you install songs in this location, older versions will not be able to find them."),
                onTap: () =>
                    _applyMode(context, PreferredCustomSongFolder.songCore),
              ),
              ListTile(
                title: _labelFor(PreferredCustomSongFolder.auto),
                subtitle: const Text(
                    "Automatically detect the current Beat Saber version and pick the optimal option. If you downgrade Beat Saber after installing 1.35, older versions may not be able to detect all the songs."),
                onTap: () =>
                    _applyMode(context, PreferredCustomSongFolder.auto),
              ),
            ],
          )),
          BeatSaberVersionDetector.detectedVersion == null
              ? const SizedBox()
              : Padding(
                  padding: const EdgeInsets.all(20),
                  child: Text(
                      'Detected Beat Saber version: ${BeatSaberVersionDetector.detectedVersion}'))
        ]));
  }
}

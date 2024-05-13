// ignore_for_file: constant_identifier_names, non_constant_identifier_names

import 'dart:async';

import 'package:bsaberquest/main.dart';
import 'package:installed_apps/installed_apps.dart';

class BeatSaberVersionDetector {
  // https://oculusdb.rui2015.me/id/2448060205267927
  static const int V_1_35_versionCode = 1129;
  static const bool dev_simulate_v_1_35 = true;

  static BeatSaberVersion? cachedResult;
  static String? detectedVersion;

  BeatSaberVersionDetector._();

  static Future<BeatSaberVersion> getBeatSaberVersion() async {
    if (cachedResult != null) {
      return cachedResult!;
    }

    cachedResult = await _getBeatSaberVersion();
    return cachedResult!;
  }

  static Future<BeatSaberVersion> _getBeatSaberVersion() async {
    // On PC we don't care
    if (!App.isQuest) {
      throw Exception("Beat saber version detection is only for quest");
    }

    // If we are simulating the quest on PC
    if (App.isDev) {
      detectedVersion = "fake for development";

      return dev_simulate_v_1_35
          ? BeatSaberVersion.v_1_35_OrNewer
          : BeatSaberVersion.olderThan_v_1_35;
    }

    // On android try to detect the version
    try {
      var apps = await InstalledApps.getInstalledApps(
          true, false, "com.beatgames.beatsaber");

      if (apps.isEmpty) {
        return BeatSaberVersion.unknown;
      }

      var app = apps.first;
      detectedVersion = app.versionName;

      if (app.versionCode >= V_1_35_versionCode) {
        return BeatSaberVersion.v_1_35_OrNewer;
      }

      return BeatSaberVersion.olderThan_v_1_35;
    } catch (e) {
      return BeatSaberVersion.unknown;
    }
  }
}

enum BeatSaberVersion {
  unknown,
  olderThan_v_1_35,
  v_1_35_OrNewer,
}

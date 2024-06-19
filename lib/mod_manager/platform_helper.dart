import 'dart:io';

import 'package:bsaberquest/mod_manager/model/song.dart';
import 'package:flutter/services.dart';

class PlatformHelper {
  static MethodChannel? _platform;

  static MethodChannel getPlatform() {
    if (_platform != null) return _platform!;
    _platform = const MethodChannel('songmanager/native_helper');
    return _platform!;
  }

  static void openSongPath(Song song) {
    if (Platform.isWindows) {
      Process.run('explorer', [song.folderPath.replaceAll('/', '\\')]);
    } else if (Platform.isLinux) {
      Process.run('xdg-open', [song.folderPath]);
    } else {
      throw Exception('Unsupported platform');
    }
  }

  static void openUrl(Uri link) {
    if (Platform.isWindows) {
      // Process.run arg escaping is broken on windows
      getPlatform().invokeMethod("openUrl", [link.toString()]);
    } else if (Platform.isLinux) {
      Process.run('xdg-open', [link.toString()]);
    } else {
      throw Exception('Unsupported platform');
    }
  }
}

import 'dart:io';

import 'package:bsaberquest/mod_manager/model/song.dart';

class PlatformHelper {
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
      Process.run('cmd', ["/c", "start", link.toString()]);
    } else if (Platform.isLinux) {
      Process.run('xdg-open', [link.toString()]);
    } else {
      throw Exception('Unsupported platform');
    }
  }
}

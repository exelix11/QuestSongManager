import 'package:bsaberquest/rpc/rpc_manager.dart';

class BsSchemaParser {
  static final RegExp _playlistUrlRegex =
      RegExp(r'^https://api.beatsaver.com/playlists/id/(\d+)/download$');

  static RpcCommand? parse(String url) {
    if (url.endsWith("/")) url = url.substring(0, url.length - 1);

    if (url.startsWith('beatsaver://')) {
      return RpcCommand.downloadSong(url.split('beatsaver://').last);
    } else if (url.startsWith('bsplaylist://playlist/')) {
      return RpcCommand.downloadPlaylist(
          url.split('bsplaylist://playlist/').last);
    } else if (_playlistUrlRegex.hasMatch(url)) {
      return RpcCommand.downloadPlaylist(url);
    }

    return null;
  }
}

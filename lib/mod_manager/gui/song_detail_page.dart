import 'package:bsaberquest/mod_manager/gui/playlist_detail_page.dart';
import 'package:bsaberquest/mod_manager/gui/simple_widgets.dart';
import 'package:bsaberquest/util/gui_util.dart';
import 'package:bsaberquest/main.dart';
import 'package:bsaberquest/mod_manager/mod_manager.dart';
import 'package:bsaberquest/mod_manager/model/song.dart';
import 'package:bsaberquest/mod_manager/platform_helper.dart';
import 'package:bsaberquest/mod_manager/version_detector.dart';
import 'package:flutter/material.dart';

import '../model/playlist.dart';
import 'playlist_picker_page.dart';

class SongDetailPage extends StatelessWidget {
  final Song song;
  final List<Playlist> playlists;

  SongDetailPage({super.key, required this.song})
      : playlists = App.modManager.findPlaylistsBySong(song);

  Future _addToPlaylist(BuildContext context) async {
    // Pick a playlist
    var result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const PlaylistPickerPage(),
      ),
    );

    var playlist = result as Playlist?;

    if (playlist != null) {
      // Add to playlist
      playlist.add(song);
      // save playlist
      await App.modManager.applyPlaylistChanges(playlist);
    }

    // Leave the song detail page
    if (context.mounted) Navigator.pop(context);
  }

  Future _deleteSong(BuildContext context) async {
    var result = await GuiUtil.confirmChoice(
        context,
        "Do you want to delete this song ?",
        "${song.meta.songName} will be deleted");

    if (result == null || !result) return;

    await App.modManager.deleteSong(song);
    if (context.mounted) Navigator.pop(context);
  }

  Future _recheckSongHash() async {
    var valid = await App.modManager.checkSongHash(song);

    var message = valid
        ? "Song hash is valid"
        : "Song hash was invalid, it has been corrected";

    App.showToast(message);
  }

  String _nameOrUnknown(String? name) {
    if (name == null || name.isEmpty) {
      return "unknown";
    }
    return name;
  }

  void _openFolder() {
    PlatformHelper.openSongPath(song);
  }

  Widget _beatSaberVersionWarn() {
    // On PC this warning is not needed
    if (!App.isQuest) return const SizedBox(height: 30);

    // For new beat saber versions no need to show a warning
    if (BeatSaberVersionDetector.cachedResult ==
        BeatSaberVersion.v_1_35_OrNewer) {
      return const SizedBox(height: 30);
    }

    // No warning for the old location or if we failed to get it
    var location = App.modManager.getLocationForSong(song);
    if (location != CustomLevelLocation.songCore) {
      return const SizedBox(height: 30);
    }

    return const Padding(
        padding: EdgeInsets.all(20),
        child: Text(
            "This song is installed in the 'SongCore' folder, Beat Saber versions older than 1.35 will not be able to load it."));
  }

  void _openPlaylistDetails(BuildContext context, Playlist playlist) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PlaylistDetailPage(playlist: playlist),
      ),
    );
  }

  List<Widget> _buildPlaylistList(BuildContext context) {
    if (playlists.isEmpty) {
      return [];
    }

    return [
      const Center(child: Text("This song is in the following playlists")),
      ...playlists.map((e) => PlaylistWidget(
          playlist: e, onTap: (p) => _openPlaylistDetails(context, p)))
    ];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
          title: Text("${song.meta.songName} ${song.meta.songSubName ?? ""}"),
        ),
        body: ListView(
          padding: GuiUtil.defaultViewPadding(context),
          children: [
            // Limit the image size so it doesn't take up the whole screen
            SizedBox(
                width: 200, height: 200, child: SongWidget.iconForSong(song)),
            const SizedBox(height: 20),
            Center(
              child: Column(
                children: [
                  Text("Author: ${_nameOrUnknown(song.meta.songSubName)}"),
                  Text("Mapper: ${_nameOrUnknown(song.meta.levelAuthorName)}"),
                  _beatSaberVersionWarn(),
                  Text("Path on disk: ${song.folderPath}"),
                  Text("Song hash: ${_nameOrUnknown(song.hash)}"),
                ],
              ),
            ),
            const SizedBox(height: 40),
            ListTile(
              title: const Text("Add to playlist"),
              leading: const Icon(Icons.add),
              onTap: () => _addToPlaylist(context),
            ),
            ListTile(
              title: const Text("Delete song"),
              leading: const Icon(Icons.delete),
              onTap: () => _deleteSong(context),
            ),
            if (!App.isQuest)
              ListTile(
                title: const Text("Open folder"),
                leading: const Icon(Icons.folder),
                onTap: () => _openFolder(),
              ),
            ListTile(
              title: const Text("Recheck hash"),
              leading: const Icon(Icons.warning),
              onTap: () => _recheckSongHash(),
            ),
            ..._buildPlaylistList(context),
            const SizedBox(height: 40),
          ],
        ));
  }
}

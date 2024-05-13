import 'dart:io';

import 'package:bsaberquest/gui_util.dart';
import 'package:bsaberquest/main.dart';
import 'package:bsaberquest/mod_manager/mod_manager.dart';
import 'package:bsaberquest/mod_manager/model/song.dart';
import 'package:bsaberquest/mod_manager/version_detector.dart';
import 'package:flutter/material.dart';

import 'playlist_picker_page.dart';

class SongDetailPage extends StatelessWidget {
  final Song song;

  const SongDetailPage({super.key, required this.song});

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("${song.meta.songName} ${song.meta.songSubName ?? ""}"),
      ),
      body: Center(
        child: Column(
          children: [
            // Limit the image size so it doesn't take up the whole screen
            SizedBox(
                width: 200,
                height: 200,
                child: Image.file(File(
                    "${song.folderPath}/${song.meta.coverImageFilename}"))),
            const SizedBox(height: 20),
            Text("Author: ${_nameOrUnknown(song.meta.songSubName)}"),
            Text("Mapper: ${_nameOrUnknown(song.meta.levelAuthorName)}"),
            _beatSaberVersionWarn(),
            Text("Path on disk: ${song.folderPath}"),
            Text("Song hash: ${_nameOrUnknown(song.hash)}"),
            const SizedBox(height: 40),
            // Add a group of buttons to add to playlist or delete
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton(
                  onPressed: () => _addToPlaylist(context),
                  child: const Text('Add to playlist'),
                ),
                ElevatedButton(
                  onPressed: () => _recheckSongHash(),
                  child: const Text('Recheck hash'),
                ),
                ElevatedButton(
                  onPressed: () => _deleteSong(context),
                  child: const Text('Delete'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

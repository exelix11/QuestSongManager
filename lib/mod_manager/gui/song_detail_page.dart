import 'dart:io';

import 'package:bsaberquest/main.dart';
import 'package:bsaberquest/mod_manager/model/song.dart';
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
    Navigator.pop(context);
  }

  Future _deleteSong(BuildContext context) async {
    await App.modManager.deleteSong(song);
    Navigator.pop(context);
  }

  Future _recheckSongHash() async {
    var valid = await App.modManager.checkSongHash(song);

    var message = valid
        ? "Song hash is valid"
        : "Song hash was invalid, it has been corrected";

    App.showToast(message);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(song.meta.songName),
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
            Text(song.shortFolderName),
            Text(song.folderPath),
            Text(song.hash ?? "No hash"),
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

import 'dart:async';

import 'package:bsaberquest/gui_util.dart';
import 'package:bsaberquest/main.dart';
import 'package:bsaberquest/mod_manager/gui/simple_widgets.dart';
import 'package:bsaberquest/mod_manager/gui/song_detail_page.dart';
import 'package:bsaberquest/mod_manager/model/song.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart';

import '../model/playlist.dart';

class PlaylistDetailPageState extends State<PlaylistDetailPage> {
  late StreamSubscription _playlistSubscription;
  late StreamSubscription _songListSubscription;
  bool _stateChanged = false;

  @override
  void initState() {
    _playlistSubscription =
        App.modManager.playlistObservable.stream.listen((_) {
      setState(() {});
    });

    _songListSubscription =
        App.modManager.songListObservable.stream.listen((_) {
      setState(() {});
    });

    super.initState();
  }

  @override
  void dispose() {
    _playlistSubscription.cancel();
    _songListSubscription.cancel();

    if (_stateChanged) {
      // Apply the changes to the playlist only when we are finished with our changes
      App.modManager.applyPlaylistChanges(widget.playlist);
    }

    super.dispose();
  }

  Future _removeSongByHash(String hash) async {
    List<PlayListSong> remove = [];

    for (var song in widget.playlist.songs) {
      if (song.hash == hash) {
        remove.add(song);
      }
    }

    for (var song in remove) {
      widget.playlist.songs.remove(song);
    }

    _stateChanged = true;
    setState(() {});
  }

  Future _deletePlaylist() async {
    var confirm = await GuiUtil.confirmChoice(this.context, 'Delete Playlist',
        'Are you sure you want to delete this playlist? The songs will not be deleted.');

    if (confirm == null || !confirm) {
      return;
    }

    await App.modManager.deletePlaylist(widget.playlist);

    if (mounted) Navigator.pop(this.context);
  }

  void _songDetails(BuildContext context, Song song) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => SongDetailPage(song: song),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(mainAxisAlignment: MainAxisAlignment.center, children: [
      // Limit the image size so it doesn't take up the whole screen
      SizedBox(
          width: 150,
          height: 150,
          child: PlaylistWidget.playlistIcon(widget.playlist)),
      Column(
        children: [
          Text(widget.playlist.fileName),
          Text("${widget.playlist.songs.length} songs"),
          // Add a group of buttons to add to playlist or delete
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              ElevatedButton(
                onPressed: _deletePlaylist,
                child: const Text('Delete this playlist'),
              ),
            ],
          ),
        ],
      )
    ]);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.playlist.playlistTitle),
      ),
      body: Center(
        child: Column(
          children: [
            _buildHeader(),
            Expanded(
              child: ListView.builder(
                itemCount: widget.playlist.songs.length,
                itemBuilder: (context, index) {
                  var song = widget.playlist.songs[index];
                  var delete = IconButton(
                      onPressed: () => _removeSongByHash(song.hash),
                      icon: const Icon(Icons.delete));
                  if (App.modManager.songs.containsKey(song.hash)) {
                    return SongWidget(
                      song: App.modManager.songs[song.hash]!,
                      extraIcon: delete,
                      onTap: (song) => _songDetails(context, song),
                    );
                  } else {
                    return ListTile(
                      leading: const Icon(Icons.music_note),
                      title: Text(song.songName),
                      subtitle: Text("Unknown song (${basename(song.hash)})"),
                      trailing: delete,
                    );
                  }
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class PlaylistDetailPage extends StatefulWidget {
  const PlaylistDetailPage({super.key, required this.playlist});

  final Playlist playlist;

  @override
  PlaylistDetailPageState createState() => PlaylistDetailPageState();
}

import 'dart:async';

import 'package:bsaberquest/main.dart';
import 'package:bsaberquest/mod_manager/gui/song_list_widget.dart';
import 'package:bsaberquest/mod_manager/model/song.dart';
import 'package:flutter/material.dart';

class SongsInNoPlaylistState extends State<SongsInNoPlaylistPage> {
  late StreamSubscription _songListSubscription;
  late StreamSubscription _playlistSubscription;

  final SongListWidgetController _controller = SongListWidgetController(
      null, GenericSongControllerActions.deleteSelected);

  final Set<String> _songsInNoPlaylist = {};

  @override
  void initState() {
    _songListSubscription =
        App.modManager.songListObservable.stream.listen((_) {
      _songListChanged();
    });

    _playlistSubscription =
        App.modManager.playlistObservable.stream.listen((_) {
      _playlistChanged();
    });

    _playlistChanged();

    super.initState();
  }

  @override
  void dispose() {
    _songListSubscription.cancel();
    _playlistSubscription.cancel();
    super.dispose();
  }

  void _playlistChanged() {
    _songsInNoPlaylist.clear();
    for (var playlist in App.modManager.playlists.values) {
      _songsInNoPlaylist.addAll(playlist.songs.map((e) => e.hash));
    }

    _songListChanged();
  }

  void _songListChanged() {
    Map<String, Song> songs = {};
    for (var songHash in App.modManager.songs.keys) {
      if (!_songsInNoPlaylist.contains(songHash)) {
        songs[songHash] = App.modManager.songs[songHash]!;
      }
    }

    _controller.trySetItems(songs);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Songs that are not in any playlist"),
      ),
      body: SongListWidget(_controller),
    );
  }
}

class SongsInNoPlaylistPage extends StatefulWidget {
  const SongsInNoPlaylistPage({super.key});

  @override
  State<SongsInNoPlaylistPage> createState() => SongsInNoPlaylistState();
}

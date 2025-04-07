import 'dart:async';

import 'package:bsaberquest/main.dart';
import 'package:bsaberquest/mod_manager/gui/simple_widgets.dart';
import 'package:bsaberquest/mod_manager/model/playlist.dart';
import 'package:bsaberquest/util/gui_util.dart';
import 'package:flutter/material.dart';

class PlaylistReorderPageState extends State<PlaylistReorderPage> {
  StreamSubscription? _playlistSubscription;
  bool _isDirty = false;

  @override
  void initState() {
    super.initState();
    _playlistSubscription =
        App.modManager.playlistObservable.stream.listen((_) {
      if (mounted) {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _playlistSubscription?.cancel();

    if (_isDirty) {
      App.modManager.applyPlaylistChanges(widget.playlist);
    }

    super.dispose();
  }

  void _reorder(int oldIndex, int newIndex) {
    if (oldIndex == newIndex) return;
    if (newIndex >= widget.playlist.songs.length) return;
    if (newIndex > oldIndex) {
      newIndex -= 1;
    }

    _isDirty = true;

    setState(() {
      var song = widget.playlist.songs.removeAt(oldIndex);
      widget.playlist.songs.insert(newIndex, song);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Reorder playlist"),
      ),
      body: ReorderableListView.builder(
        onReorder: _reorder,
        padding: GuiUtil.defaultViewPadding(context),
        itemCount: widget.playlist.songs.length,
        itemBuilder: (context, index) {
          var song = widget.playlist.songs[index];

          var grabHandle = const [
            SizedBox(width: 10, height: 70, child: Icon(Icons.drag_handle))
          ];

          if (App.modManager.songs.containsKey(song.hash)) {
            var appSong = App.modManager.songs[song.hash]!;
            return SongWidget(
              key: ValueKey(index),
              song: appSong,
              extraIcons: grabHandle,
            );
          } else {
            return UnknownSongWidget(
                key: ValueKey(index),
                hash: song.hash,
                songName: song.songName,
                extraIcons: grabHandle);
          }
        },
      ),
    );
  }
}

class PlaylistReorderPage extends StatefulWidget {
  final Playlist playlist;

  const PlaylistReorderPage(this.playlist, {super.key});

  @override
  State<StatefulWidget> createState() => PlaylistReorderPageState();
}

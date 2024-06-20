import 'dart:async';

import 'package:bsaberquest/main.dart';
import 'package:bsaberquest/mod_manager/gui/song_list_widget.dart';
import 'package:flutter/material.dart';

class SongsListState extends State<SongsListPage> {
  late StreamSubscription _songListSubscription;
  final SongListWidgetController _controller = SongListWidgetController(
      App.modManager.songs, GenericSongControllerActions.deleteSelected);

  @override
  void initState() {
    _songListSubscription =
        App.modManager.songListObservable.stream.listen((_) {
      _songListChanged();
    });

    super.initState();
  }

  @override
  void dispose() {
    _songListSubscription.cancel();
    super.dispose();
  }

  void _songListChanged() {
    _controller.trySetItems(App.modManager.songs);
  }

  @override
  Widget build(BuildContext context) {
    return SongListWidget(_controller);
  }
}

class SongsListPage extends StatefulWidget {
  const SongsListPage({super.key});

  @override
  SongsListState createState() => SongsListState();
}

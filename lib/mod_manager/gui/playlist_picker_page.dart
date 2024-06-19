import 'package:bsaberquest/util/gui_util.dart';
import 'package:bsaberquest/main.dart';
import 'package:bsaberquest/mod_manager/gui/simple_widgets.dart';
import 'package:flutter/material.dart';

import '../model/playlist.dart';

class PlaylistPickerPage extends StatefulWidget {
  const PlaylistPickerPage({super.key});

  @override
  PlaylistPickerPageState createState() => PlaylistPickerPageState();
}

class PlaylistPickerPageState extends State<PlaylistPickerPage> {
  void _confirmSelection(Playlist song) {
    Navigator.pop(context, song);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
          title: const Text('Select a playlist'),
        ),
        body: ListView.builder(
          padding: GuiUtil.defaultViewPadding(context),
          itemCount: App.modManager.playlists.length,
          itemBuilder: (context, index) {
            var playlist = App.modManager.playlists.values.elementAt(index);
            return PlaylistWidget(playlist: playlist, onTap: _confirmSelection);
          },
        ));
  }
}

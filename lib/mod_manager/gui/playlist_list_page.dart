import 'dart:async';

import 'package:bsaberquest/gui_util.dart';
import 'package:bsaberquest/main.dart';
import 'package:bsaberquest/mod_manager/gui/playlist_detail_page.dart';
import 'package:bsaberquest/mod_manager/gui/simple_widgets.dart';
import 'package:bsaberquest/mod_manager/gui/songs_in_no_playlist_page.dart';
import 'package:flutter/material.dart';

import '../model/playlist.dart';

class PlaylistListPageState extends State<PlaylistListPage> {
  late StreamSubscription _playlistSubscription;
  late StreamSubscription _songListSubscription;
  bool showPlaylistIconFormatWarning = false;
  bool ignorePlaylistIconFormatWarning = false;

  void _checkPlaylistIconFormatWarningStae() {
    if (ignorePlaylistIconFormatWarning) {
      showPlaylistIconFormatWarning = false;
      return;
    }

    showPlaylistIconFormatWarning =
        App.modManager.playlists.values.any((x) => x.imageCompatibilityIssue);
  }

  @override
  void initState() {
    _playlistSubscription =
        App.modManager.playlistObservable.stream.listen((_) {
      setState(() {
        _checkPlaylistIconFormatWarningStae();
      });
    });

    _songListSubscription =
        App.modManager.songListObservable.stream.listen((_) {
      setState(() {});
    });

    _checkPlaylistIconFormatWarningStae();
    super.initState();
  }

  @override
  void dispose() {
    _playlistSubscription.cancel();
    _songListSubscription.cancel();
    super.dispose();
  }

  void _onPlaylistTap(Playlist song) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PlaylistDetailPage(playlist: song),
      ),
    );
  }

  void _onNewplaylistTap() async {
    var name = await GuiUtil.textInputDialog(
        context, 'Enter the name for the new playlist');

    if (name != null) {
      try {
        await App.modManager.createPlaylist(name);
      } catch (e) {
        App.showToast('Failed to create playlist: $e');
      }
    }
  }

  void _onSongsInNoPlaylistTap() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const SongsInNoPlaylistPage(),
      ),
    );
  }

  Widget _songsListView() => ListView.builder(
        itemCount: App.modManager.playlists.length,
        itemBuilder: (context, index) {
          var playlist = App.modManager.playlists.values.elementAt(index);
          return PlaylistWidget(playlist: playlist, onTap: _onPlaylistTap);
        },
      );

  String playlistIconWarningText() => App.isQuest
      ? "(for example they were taken from the PC version of the game)"
      : "(for example they were taken from the Quest version of the game)";

  void _fixPlaylistIcons() async {
    var list = App.modManager.playlists.values
        .where((x) => x.imageCompatibilityIssue)
        .toList();

    await App.modManager.applyMultiplePlaylistChanges(list);
  }

  void _ignorePlaylistIcons() {
    setState(() {
      showPlaylistIconFormatWarning = false;
      ignorePlaylistIconFormatWarning = true;
    });
  }

  Widget _bodyContent() => showPlaylistIconFormatWarning
      ? Column(children: [
          Text(
              'Some playlists have wrong icon data which will prevent the game from displaying them ${playlistIconWarningText()}.'),
          Row(children: [
            ElevatedButton(
                onPressed: _fixPlaylistIcons, child: const Text('Fix now')),
            ElevatedButton(
                onPressed: _ignorePlaylistIcons, child: const Text('Ignore')),
          ]),
          Expanded(child: _songsListView())
        ])
      : _songsListView();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
          title: Row(children: [
            const Text('Playlists'),
            Expanded(child: Container()),
            PopupMenuButton(
              itemBuilder: (BuildContext context) {
                return [
                  PopupMenuItem(
                    onTap: _onNewplaylistTap,
                    child: const Text('New playlist'),
                  ),
                  PopupMenuItem(
                    onTap: _onSongsInNoPlaylistTap,
                    child:
                        const Text('Find songs that are not in any playlist'),
                  ),
                ];
              },
            )
          ]),
        ),
        body: _bodyContent());
  }
}

class PlaylistListPage extends StatefulWidget {
  const PlaylistListPage({super.key});

  @override
  State<PlaylistListPage> createState() => PlaylistListPageState();
}

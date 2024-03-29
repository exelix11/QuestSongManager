import 'dart:async';

import 'package:bsaberquest/gui_util.dart';
import 'package:bsaberquest/main.dart';
import 'package:bsaberquest/mod_manager/gui/playlist_detail_page.dart';
import 'package:bsaberquest/mod_manager/gui/simple_widgets.dart';
import 'package:bsaberquest/mod_manager/gui/songs_in_no_playlist_page.dart';
import 'package:bsaberquest/mod_manager/model/song.dart';
import 'package:flutter/material.dart';

class PlaylistListPageState extends State<PlaylistListPage> {
  late StreamSubscription _playlistSubscription;
  late StreamSubscription _songListSubscription;

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
        body: ListView.builder(
          itemCount: App.modManager.playlists.length,
          itemBuilder: (context, index) {
            var playlist = App.modManager.playlists.values.elementAt(index);
            return PlaylistWidget(playlist: playlist, onTap: _onPlaylistTap);
          },
        ));
  }
}

class PlaylistListPage extends StatefulWidget {
  const PlaylistListPage({super.key});

  @override
  State<PlaylistListPage> createState() => PlaylistListPageState();
}

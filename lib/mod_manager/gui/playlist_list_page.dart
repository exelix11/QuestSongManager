import 'dart:async';

import 'package:bsaberquest/main.dart';
import 'package:bsaberquest/mod_manager/gui/playlist_detail_page.dart';
import 'package:bsaberquest/mod_manager/gui/simple_widgets.dart';
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

  String? _pickedName;

  Future<void> _playlistNameInput() async {
    final TextEditingController controller = TextEditingController();
    return showDialog<void>(
      context: context,
      barrierDismissible: false, // user must tap button!
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Enter the name for the new playlist'),
          content: TextField(
            controller: controller,
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('OK'),
              onPressed: () {
                _pickedName = controller.text;
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  void _onNewplaylistTap() async {
    await _playlistNameInput();

    if (_pickedName != null) {
      try {
        await App.modManager.createPlaylist(_pickedName!);
      } catch (e) {
        App.showToast('Failed to create playlist: $e');
      }
      _pickedName = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
          title: Row(children: [
            const Text('Playlists'),
            const SizedBox(width: 8),
            IconButton(
              icon: const Icon(Icons.add),
              onPressed: () => _onNewplaylistTap(),
            ),
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

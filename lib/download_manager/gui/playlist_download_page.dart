import 'dart:async';

import 'package:bsaberquest/util/gui_util.dart';
import 'package:bsaberquest/main.dart';
import 'package:bsaberquest/mod_manager/model/playlist.dart';
import 'package:flutter/material.dart';

class PlaylistDownloadPageState extends State<PlaylistDownloadPage> {
  late Future _pendingAction;
  late Playlist _playlist;
  final Map<String, bool> _songsToDownload = {};

  bool _playlistNameValid = false;

  @override
  void initState() {
    super.initState();

    _pendingAction = _downloadPlaylistMetadata();
  }

  Future _downloadPlaylistMetadata() async {
    _playlist =
        await App.downloadManager.downloadPlaylistMetadata(widget.jsonUrl);

    for (var song in _playlist.songs) {
      if (App.modManager.hasSong(song.hash)) {
        _songsToDownload[song.hash] = false;
      } else {
        _songsToDownload[song.hash] = true;
      }
    }

    if (await App.modManager.isPlaylistNameFree(_playlist.playlistTitle)) {
      _playlistNameValid = true;
    }
  }

  void _downloadPlaylist() async {
    setState(() {
      _pendingAction = _doDownloadPlaylist();
    });
  }

  Future _downloadNew() async {
    if (!_playlistNameValid) {
      var res = await GuiUtil.confirmChoice(
          context,
          "Playlist name already exists",
          "A playlist with the same name already exists, do you want to overwrite it?");

      if (res == null || !res) {
        return;
      }
    }

    var sameName =
        await App.modManager.getPlaylistByName(_playlist.playlistTitle);

    if (sameName != null) await App.modManager.deletePlaylist(sameName);

    App.downloadManager
        .startPlaylistDownload(
            _playlist,
            _songsToDownload.entries
                .where((x) => x.value)
                .map((e) => e.key)
                .toSet(),
            widget.webSource)
        .future
        // Do not wait here
        .then((value) => App.showToast(value.message))
        .onError((error, stackTrace) => App.showToast("Error: $error"));
  }

  Future _doDownloadPlaylist() async {
    await _downloadNew();
    if (mounted) Navigator.pop(context);
  }

  void _renamePlaylist() async {
    var name = await GuiUtil.textInputDialog(
        context, "Enter the new playlist name",
        defaultValue: _playlist.playlistTitle);

    if (name == null || name.isEmpty) {
      return;
    }

    _playlist.playlistTitle = name;
    var valid =
        await App.modManager.isPlaylistNameFree(_playlist.playlistTitle);

    setState(() {
      _playlistNameValid = valid;
    });
  }

  void _setSelection(bool value) {
    setState(() {
      for (var song in _playlist.songs) {
        _songsToDownload[song.hash] = value;
      }
    });
  }

  void _selectAll() {
    _setSelection(true);
  }

  void _selectNone() {
    _setSelection(false);
  }

  Widget _playlistMetadata() {
    return Row(children: [
      SizedBox.square(
          dimension: 140,
          child: _playlist.imageBytes == null
              ? const Icon(Icons.image)
              : Image.memory(_playlist.imageBytes!)),
      Flexible(
          child: Padding(
        padding: const EdgeInsets.fromLTRB(10, 0, 10, 0),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Text("Playlist name: ${_playlist.playlistTitle}"),
          if (!_playlistNameValid)
            Column(children: [
              const SizedBox(height: 10),
              const Text(
                "A playlist with the same name already exists",
                style: TextStyle(color: Colors.red),
              ),
              const Text("If you proceed it will be overwritten"),
              ElevatedButton(
                  onPressed: _renamePlaylist,
                  child: const Text("Rename playlist")),
              const SizedBox(height: 10)
            ]),
          Text("Author: ${_playlist.playlistAuthor}"),
          if (_playlist.playlistDescription != null)
            Text(_playlist.playlistDescription!),
        ]),
      ))
    ]);
  }

  Widget _buildMainBody() {
    return CustomScrollView(slivers: [
      SliverAppBar(
          actions: [
            IconButton(
                onPressed: _downloadPlaylist,
                icon: const Row(
                  children: [
                    Icon(Icons.download),
                    SizedBox(width: 5),
                    Text("Download"),
                    SizedBox(width: 5),
                  ],
                )),
            PopupMenuButton(
                itemBuilder: (context) => [
                      PopupMenuItem(
                          onTap: _selectAll, child: const Text("Select all")),
                      PopupMenuItem(
                          onTap: _selectNone, child: const Text("Select none"))
                    ])
          ],
          expandedHeight: 300,
          stretch: true,
          pinned: true,
          title: const Text("Download playlist"),
          flexibleSpace: FlexibleSpaceBar(
              collapseMode: CollapseMode.pin,
              background: Padding(
                  padding: const EdgeInsets.only(top: 60),
                  child: _playlistMetadata()))),
      SliverList(
          delegate: SliverChildBuilderDelegate(
        (context, index) {
          var song = _playlist.songs[index];
          return CheckboxListTile(
              title: Text(song.songName),
              value: _songsToDownload[song.hash],
              onChanged: (value) {
                setState(() {
                  _songsToDownload[song.hash] = value ?? false;
                });
              });
        },
        childCount: _playlist.songs.length,
      )),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        body: Padding(
      padding: GuiUtil.defaultViewPadding(context),
      child: FutureBuilder(
        future: _pendingAction,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          if (snapshot.hasError) {
            return Center(
              child: Text("Error: ${snapshot.error}"),
            );
          }

          return _buildMainBody();
        },
      ),
    ));
  }
}

class PlaylistDownloadPage extends StatefulWidget {
  final String jsonUrl;
  final String? webSource;

  const PlaylistDownloadPage(this.jsonUrl, {this.webSource, super.key});

  @override
  State<StatefulWidget> createState() => PlaylistDownloadPageState();
}

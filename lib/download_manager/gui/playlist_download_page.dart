import 'dart:async';

import 'package:bsaberquest/gui_util.dart';
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
    _playlist = await App.downloadManager.downloadPlaylist(widget.jsonUrl);
    bool atLeastOne = false;

    for (var song in _playlist.songs) {
      if (App.modManager.hasSong(song.hash)) {
        _songsToDownload[song.hash] = false;
      } else {
        _songsToDownload[song.hash] = true;
        atLeastOne = true;
      }
    }

    // If we are updating an existing playlist, copy the metadata now
    if (widget.updateExisting != null) {
      _playlistNameValid = true;
      // Sync metadata first
      widget.updateExisting!.fromAnotherInstance(_playlist);
      _playlist = widget.updateExisting!;
      await App.modManager.applyPlaylistChanges(_playlist);

      if (!atLeastOne) {
        App.showToast("No new songs to download");
        if (!mounted) throw Exception("Failed to leave the page");
        Navigator.pop(context);
        return;
      }
    }
    // Otherwise, check if the playlist name is free
    else {
      if (await App.modManager.isPlaylistNameFree(_playlist.playlistTitle)) {
        _playlistNameValid = true;
      }
    }
  }

  void _downloadPlaylist() async {
    setState(() {
      _pendingAction = _doDownloadPlaylist();
    });
  }

  // In this case we just schedule the download and do not do any other playlist management
  Future _downloadUpdate() async {
    var futures = _songsToDownload.entries
        .where((x) => x.value)
        .map((e) => App.downloadManager.downloadMapByID(e.key, null, null))
        .map((e) => e.future)
        .toList();

    App.showToast("Downloading new songs...");

    Future.wait(futures)
        // Do not wait here
        .then((value) => App.showToast("Playlist updated successfully"))
        .onError((error, stackTrace) =>
            App.showToast("Some songs could not be downloaded: $error"));
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
  }

  Future _doDownloadPlaylist() async {
    if (widget.updateExisting == null) {
      await _downloadNew();
    } else {
      await _downloadUpdate();
    }

    if (!mounted) throw Exception("Failed to leave the page");
    Navigator.pop(context);
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
        child: Column(children: [
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

  Widget _getContent() {
    return Column(children: [
      Padding(
          padding: const EdgeInsets.fromLTRB(40, 0, 40, 0),
          child: _playlistMetadata()),
      const SizedBox(
        height: 10,
      ),
      Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          ElevatedButton(
              onPressed: _selectAll, child: const Text("Select all")),
          ElevatedButton(
              onPressed: _selectNone, child: const Text("Select none"))
        ],
      ),
      Expanded(
          child: ListView.builder(
              itemCount: _playlist.songs.length,
              itemBuilder: (x, i) {
                var song = _playlist.songs[i];
                return CheckboxListTile(
                    title: Text(song.songName),
                    value: _songsToDownload[song.hash],
                    onChanged: (value) {
                      setState(() {
                        _songsToDownload[song.hash] = value!;
                      });
                    });
              })),
      const SizedBox(
        height: 4,
      ),
      Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        ElevatedButton(
            onPressed: _downloadPlaylist,
            child: const Text("Download playlist"))
      ]),
      const SizedBox(
        height: 4,
      ),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Download playlist"),
      ),
      body: FutureBuilder(
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

          return _getContent();
        },
      ),
    );
  }
}

class PlaylistDownloadPage extends StatefulWidget {
  final String jsonUrl;
  final String? webSource;
  final Playlist? updateExisting;

  const PlaylistDownloadPage(this.jsonUrl,
      {this.webSource, this.updateExisting, super.key});

  @override
  State<StatefulWidget> createState() => PlaylistDownloadPageState();
}

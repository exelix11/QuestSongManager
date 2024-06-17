import 'dart:async';
import 'dart:collection';

import 'package:bsaberquest/download_manager/beat_saver_api.dart';
import 'package:bsaberquest/gui_util.dart';
import 'package:bsaberquest/main.dart';
import 'package:bsaberquest/mod_manager/gui/simple_widgets.dart';
import 'package:bsaberquest/mod_manager/gui/song_detail_page.dart';
import 'package:bsaberquest/mod_manager/model/song.dart';
import 'package:flutter/material.dart';

import '../model/playlist.dart';

class PlaylistDetailPageState extends State<PlaylistDetailPage> {
  late StreamSubscription _playlistSubscription;
  late StreamSubscription _songListSubscription;
  final HashSet<String> _downloadingSongs = HashSet();

  bool _savePlaylistOnLeave = false;
  bool _hasMissingSongs = false;
  bool _isDownloadingAll = false;

  @override
  void initState() {
    _playlistSubscription =
        App.modManager.playlistObservable.stream.listen((_) {
      _updateState();
    });

    _songListSubscription =
        App.modManager.songListObservable.stream.listen((_) {
      _updateState();
    });

    super.initState();

    _updateState();
  }

  void _updateState() {
    setState(() {
      _hasMissingSongs = widget.playlist.songs
          .any((song) => !App.modManager.songs.containsKey(song.hash));
    });
  }

  @override
  void dispose() {
    _playlistSubscription.cancel();
    _songListSubscription.cancel();

    if (_savePlaylistOnLeave) {
      // Apply the changes to the playlist only when we are finished with our changes
      App.modManager.applyPlaylistChanges(widget.playlist);
    }

    super.dispose();
  }

  void _setIsDownloadingAll(bool isDownloading) {
    setState(() {
      _isDownloadingAll = isDownloading;
    });
  }

  Future _downlaodAllMissingSongs() async {
    _setIsDownloadingAll(true);
    var hashes = widget.playlist.songs
        .where((song) => !App.modManager.songs.containsKey(song.hash))
        .map((e) => e.hash)
        .toList();

    List<BeatSaverMapInfo> info = [];
    try {
      info = await App.beatSaverClient.getMapsByHashes(hashes);
    } catch (e) {
      App.showToast("Failed to download songs: $e");
      _setIsDownloadingAll(false);
      return;
    }

    var pending = info
        .map((e) => App.downloadManager.downloadMapByMetadata(e, null, null))
        .map((e) => e.future)
        .toList();

    var res = await Future.wait(pending);

    if (res.any((e) => e.error)) {
      App.showToast("Failed to download some songs");
    } else {
      App.showToast("Download completed");
    }

    _setIsDownloadingAll(false);
  }

  void _tryDownloadMissingSong(String hash) async {
    if (_downloadingSongs.contains(hash)) return;

    setState(() {
      _downloadingSongs.add(hash);
    });

    var download = App.downloadManager.downloadMapByHash(hash, null, null);
    var res = await download.future;

    setState(() {
      _downloadingSongs.remove(hash);
    });

    App.showToast(res.message);
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

    _savePlaylistOnLeave = true;
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
              if (_hasMissingSongs)
                if (_isDownloadingAll)
                  const CircularProgressIndicator()
                else
                  ElevatedButton(
                    onPressed: _downlaodAllMissingSongs,
                    child: const Text('Download missing songs'),
                  ),
            ],
          ),
        ],
      )
    ]);
  }

  IconButton _songDeleteButton(PlayListSong song) => IconButton(
      onPressed: () => _removeSongByHash(song.hash),
      icon: const Icon(Icons.delete));

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
                  if (App.modManager.songs.containsKey(song.hash)) {
                    return SongWidget(
                      song: App.modManager.songs[song.hash]!,
                      extraIcon: _songDeleteButton(song),
                      onTap: (song) => _songDetails(context, song),
                    );
                  } else {
                    return UnknownSongWidget(
                      hash: song.hash,
                      songName: song.songName,
                      onDelete: _removeSongByHash,
                      onDownload:
                          _isDownloadingAll ? null : _tryDownloadMissingSong,
                      isDownloading: _downloadingSongs.contains(song.hash),
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

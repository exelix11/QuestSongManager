import 'dart:async';
import 'dart:collection';

import 'package:bsaberquest/download_manager/beat_saver_api.dart';
import 'package:bsaberquest/util/gui_util.dart';
import 'package:bsaberquest/main.dart';
import 'package:bsaberquest/mod_manager/gui/playlist_sync_page.dart';
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

  void _downlaodAllMissingSongs() async {
    _setIsDownloadingAll(true);
    App.showToast("Download started");

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

  void _deletePlaylist() async {
    var confirm = await GuiUtil.confirmChoice(context, 'Delete Playlist',
        'Are you sure you want to delete this playlist? The songs will not be deleted.');

    if (confirm == null || !confirm) {
      return;
    }

    await App.modManager.deletePlaylist(widget.playlist);

    if (mounted) Navigator.pop(context);
  }

  void _songDetails(BuildContext context, Song song) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => SongDetailPage(song: song),
      ),
    );
  }

  Future<Playlist> downloadLatestVersion() async {
    var playlist = await App.downloadManager
        .downloadPlaylistMetadata(widget.playlist.syncUrl!);
    return playlist;
  }

  Future<bool> doGuiMerge(
      String fromName, String toName, PlaylistSyncState state) async {
    var res = await Navigator.push(
        context,
        MaterialPageRoute(
            builder: (context) => PlaylistSyncPage(
                fromName: fromName, toName: toName, state: state))) as bool?;

    if (res == true) {
      PlaylistSyncHelper.performCustomMerge(state);
      return true;
    } else {
      App.showToast("Operation cancelled");
      return false;
    }
  }

  Future _doDownloadPlaylist() async {
    var remote = await downloadLatestVersion();

    // merge from remote to local
    var sync = PlaylistSyncState(remote, widget.playlist);

    if (PlaylistSyncHelper.isNoChanges(sync)) {
      App.showToast("No updates found");
      return;
    }

    if (PlaylistSyncHelper.isSimpleMerge(sync)) {
      PlaylistSyncHelper.performSimpleMerge(sync);
    } else {
      if (!await doGuiMerge("cloud", "this device", sync)) {
        return;
      }
    }

    App.modManager.applyPlaylistChanges(widget.playlist);
    setState(() {});
  }

  Future _doUploadPlaylist() async {
    var remote = await downloadLatestVersion();

    // merge from local to remote
    var sync = PlaylistSyncState(widget.playlist, remote);

    if (PlaylistSyncHelper.isNoChanges(sync)) {
      App.showToast("No updates found");
      return;
    }

    if (PlaylistSyncHelper.isSimpleMerge(sync)) {
      PlaylistSyncHelper.performSimpleMerge(sync);
    } else {
      if (!await doGuiMerge("this device", "cloud", sync)) {
        return;
      }
    }

    try {
      await App.beatSaverClient.pushPlaylistChanges(remote);
    } catch (e) {
      App.showToast("Failed to upload playlist: $e");
    }

    // If everything went well, also update the local playlist
    widget.playlist.songs.clear();
    widget.playlist.songs.addAll(remote.songs);
    App.modManager.applyPlaylistChanges(widget.playlist);
    setState(() {});
  }

  void _downloadPlaylist() async {
    await GuiUtil.loadingDialog(
        context, "Downloading playlist information", _doDownloadPlaylist());
  }

  void _uploadPlaylist() async {
    await GuiUtil.loadingDialog(
        context, "Downloading playlist information", _doUploadPlaylist());
  }

  List<Widget> _buildMetadata() {
    return [
      Text(widget.playlist.fileName),
      Text(widget.playlist.playlistAuthor),
      Text("${widget.playlist.songs.length} songs"),
      if (widget.playlist.syncUrl != null)
        const Text("This playlist is linked to the cloud"),
      if (widget.playlist.playlistDescription != null)
        Text(widget.playlist.playlistDescription!),
    ];
  }

  IconButton _songDeleteButton(PlayListSong song) => IconButton(
      onPressed: () => _removeSongByHash(song.hash),
      icon: const Icon(Icons.delete));

  Widget _buildSong(PlayListSong song) {
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
        onDownload: _isDownloadingAll ? null : _tryDownloadMissingSong,
        isDownloading: _downloadingSongs.contains(song.hash),
      );
    }
  }

  Widget _buildPopupMenu() {
    return PopupMenuButton<Function()>(
      onSelected: (Function() selection) {
        selection();
      },
      itemBuilder: (BuildContext context) => [
        if (_hasMissingSongs)
          PopupMenuItem<Function()>(
            value: _downlaodAllMissingSongs,
            child: const Text('Download all missing songs'),
          ),
        if (widget.playlist.syncUrl != null)
          PopupMenuItem<Function()>(
            value: _downloadPlaylist,
            child: const Text('Download playlist updates'),
          ),

        // Only allow this when the user is logged in and the playlist is a BeatSaver playlist
        if (App.beatSaverClient.userState.state == LoginState.authenticated &&
            App.beatSaverClient.isValidPlaylistForPush(widget.playlist))
          PopupMenuItem<Function()>(
            value: _uploadPlaylist,
            child: const Text('Upload playlist changes'),
          ),

        PopupMenuItem<Function()>(
          value: _deletePlaylist,
          child: const Text('Delete this playlist'),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
              actions: [_buildPopupMenu()],
              expandedHeight: 300.0,
              pinned: true,
              flexibleSpace: FlexibleSpaceBar(
                background: PlaylistWidget.playlistIcon(widget.playlist),
              )),
          SliverList(
              delegate: SliverChildListDelegate(
            [
              Center(
                child: Padding(
                  padding: const EdgeInsets.only(left: 10, right: 10),
                  child: Column(children: [
                    ..._buildMetadata(),
                    const Divider(),
                  ]),
                ),
              )
            ],
          )),
          SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                var song = widget.playlist.songs[index];
                return _buildSong(song);
              },
              childCount: widget.playlist.songs.length,
            ),
          ),
        ],
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

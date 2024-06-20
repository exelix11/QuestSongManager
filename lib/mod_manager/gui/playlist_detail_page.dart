import 'dart:async';
import 'dart:collection';
import 'dart:io';

import 'package:bsaberquest/download_manager/beat_saver_api.dart';
import 'package:bsaberquest/util/generic_list_widget.dart';
import 'package:bsaberquest/util/gui_util.dart';
import 'package:bsaberquest/main.dart';
import 'package:bsaberquest/mod_manager/gui/playlist_sync_page.dart';
import 'package:bsaberquest/mod_manager/gui/simple_widgets.dart';
import 'package:bsaberquest/mod_manager/gui/song_detail_page.dart';
import 'package:bsaberquest/mod_manager/model/song.dart';
import 'package:bsaberquest/util/list_item_picker_page.dart';
import 'package:flutter/material.dart';

import '../model/playlist.dart';

class PlaylistDetailPageState extends State<PlaylistDetailPage> {
  late StreamSubscription _playlistSubscription;
  late StreamSubscription _songListSubscription;
  final HashSet<String> _downloadingSongs = HashSet();
  late GenericListController<PlayListSong> _listController;

  bool _savePlaylistOnLeave = false;
  bool _hasMissingSongs = false;
  bool _isDownloadingAll = false;

  @override
  void initState() {
    _listController = GenericListController(
        items: {},
        getItemUniqueKey: (x) => x.hash,
        queryItem: (x, query) => x.songName.toLowerCase().contains(query),
        renderItem: _buildSong,
        configureAppButtons: _buildExtraActions,
        canSelect: true);

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
    _listController.trySetList(widget.playlist.songs);

    setState(() {
      _hasMissingSongs = widget.playlist.songs
          .any((song) => !App.modManager.songs.containsKey(song.hash));
    });
  }

  void _buildExtraActions(BuildContext context, List<Widget> actions) {
    if (_isDownloadingAll) {
      return;
    }

    if (!_listController.anySelected) {
      return;
    }

    actions.add(IconButton(
        tooltip: "Remove selected songs",
        icon: const Icon(Icons.delete),
        onPressed: _deleteSelected));
  }

  void _deleteSelected() {
    for (var song in _listController.selectedItems) {
      widget.playlist.songs.remove(song);
    }

    _savePlaylistOnLeave = true;
    _listController.clearSelection();
    _updateState();
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
    _updateState();
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
      App.showToast("No map updates found");
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

    App.showToast("Download completed");
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

    App.showToast("Upload completed");
  }

  void _downloadPlaylist() async {
    await GuiUtil.loadingDialog(
        context, "Checking playlist information", _doDownloadPlaylist());
  }

  void _uploadPlaylist() async {
    await GuiUtil.loadingDialog(
        context, "Checking playlist information", _doUploadPlaylist());
  }

  void _linkPlaylist() async {
    try {
      var userPlaylists = await App.beatSaverClient.getUserPlaylists();

      if (!mounted) return;

      var picked = await CommonPickers.pick(
          context,
          ListItemPickerPage(
            title: "Select a playlist from your account",
            items: userPlaylists,
            filter: (text, playlist) => playlist.query(text),
            itemBuilder: (context, confirm, playlist) {
              return ListTile(
                onTap: () => confirm(playlist),
                title: Text(playlist.name),
                subtitle: Text(playlist.private ? "Private" : "Public"),
                leading: playlist.image == null
                    ? const Icon(Icons.music_note)
                    : Image.network(playlist.image!),
              );
            },
          ));

      if (picked == null) return;

      var url = BeatSaverClient.makePlaylistLinkUrl(picked);
      widget.playlist.syncUrl = url;
      App.modManager.applyPlaylistChanges(widget.playlist);
    } catch (e) {
      App.showToast("$e");
      return;
    }

    App.showToast(
        "The playlist is now linked, perform a download or upload to sync it");
    setState(() {});
  }

  void _unlinkPlaylist() async {
    var conf = await GuiUtil.confirmChoice(context, "Confirm unlink",
        "This will unlink this playlist from the cloud version, making it impossible to synchronize it again without linking it first.\nDo you want to continue ?");

    if (conf ?? false) {
      widget.playlist.syncUrl = null;
      setState(() {
        _savePlaylistOnLeave = true;
      });
    }
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
      if (widget.playlist.syncUrl != null)
        Text("Update url ${widget.playlist.syncUrl}"),
    ];
  }

  IconButton _songDeleteButton(PlayListSong song) => IconButton(
      tooltip: "Remove from this playlist",
      onPressed: () => _removeSongByHash(song.hash),
      icon: const Icon(Icons.delete));

  Widget _buildSong(
      BuildContext context,
      GenericListController<PlayListSong> controller,
      PlayListSong song,
      bool isSelected) {
    selectCall() => controller.toggleItemSelection(song);

    if (App.modManager.songs.containsKey(song.hash)) {
      var appSong = App.modManager.songs[song.hash]!;
      return SongWidget(
        song: appSong,
        extraIcon: _songDeleteButton(song),
        onTap: controller.anySelected
            ? () => selectCall
            : () => _songDetails(context, appSong),
        onLongPress: controller.anySelected ? null : selectCall,
        highlight: isSelected,
      );
    } else {
      return UnknownSongWidget(
        hash: song.hash,
        songName: song.songName,
        onDelete: _removeSongByHash,
        onDownload: _isDownloadingAll ? null : _tryDownloadMissingSong,
        isDownloading: _downloadingSongs.contains(song.hash),
        highlight: isSelected,
        onTap: controller.anySelected ? selectCall : null,
        onLongTap: controller.anySelected ? null : selectCall,
      );
    }
  }

  Widget _buildPopupMenu() {
    return PopupMenuButton(
      itemBuilder: (BuildContext context) => [
        if (_hasMissingSongs)
          PopupMenuItem(
            onTap: _downlaodAllMissingSongs,
            child: const Text('Download all missing songs'),
          ),

        if (widget.playlist.syncUrl != null)
          PopupMenuItem(
            onTap: _downloadPlaylist,
            child: const Text('Download playlist updates'),
          ),

        // Only allow this when the user is logged in and the playlist is a BeatSaver playlist
        if (App.beatSaverClient.userState.state == LoginState.authenticated &&
            App.beatSaverClient.isValidPlaylistForPush(widget.playlist))
          PopupMenuItem(
            onTap: _uploadPlaylist,
            child: const Text('Upload playlist changes'),
          ),

        // If the user is logged in and the playlist is not a BeatSaver playlist, allow the user to upload it
        if (App.beatSaverClient.userState.state == LoginState.authenticated &&
            widget.playlist.syncUrl == null)
          PopupMenuItem(
            onTap: _linkPlaylist,
            child: const Text('Link to BeatSaver'),
          ),

        if (widget.playlist.syncUrl != null)
          PopupMenuItem(
            onTap: _unlinkPlaylist,
            child: const Text('Unlink from cloud'),
          ),

        PopupMenuItem(
          onTap: _deletePlaylist,
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
              pinned: !Platform
                  .isAndroid, // On android we can click back at any time, on pc having the button on the top is better
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
          SliverToBoxAdapter(
              child: GenericList<PlayListSong>(
                  controller: _listController, fixedList: true)),
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

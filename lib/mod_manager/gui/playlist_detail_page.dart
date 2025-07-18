import 'dart:async';
import 'dart:collection';

import 'package:bsaberquest/download_manager/beat_saver_api.dart';
import 'package:bsaberquest/mod_manager/gui/playlist_reorder_page.dart';
import 'package:bsaberquest/util/account_playlist_picker.dart';
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
        itemName: "song",
        itemsName: "songs",
        items: {},
        getItemUniqueKey: (x) => x.hash,
        queryItem: (x, query) => x.query(query),
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

    if (!mounted) return;

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

    if (mounted) {
      setState(() {
        _downloadingSongs.remove(hash);
      });
    }

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
      var picked = await AccountPlaylistPicker.pick(context);
      if (picked == null) return;

      widget.playlist.syncUrl = picked.makeLinkUrl();
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

  void _reorderPlaylist(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PlaylistReorderPage(widget.playlist),
      ),
    );
  }

  List<Widget> _buildMetadata() {
    return [
      Text(widget.playlist.playlistTitle, style: const TextStyle(fontSize: 24)),
      Text(widget.playlist.playlistAuthor),
      Text(widget.playlist.fileName),
      if (_hasMissingSongs) const WarningLabel("Some songs are missing"),
      if (widget.playlist.syncUrl != null)
        Text("This playlist is linked to ${widget.playlist.syncUrl}"),
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

    if (!song.isBuiltinSong && App.modManager.songs.containsKey(song.hash)) {
      var appSong = App.modManager.songs[song.hash]!;
      return SongWidget(
        song: appSong,
        extraIcons: [_songDeleteButton(song)],
        onTap: controller.anySelected
            ? () => selectCall
            : () => _songDetails(context, appSong),
        onLongPress: controller.anySelected ? null : selectCall,
        highlight: isSelected,
      );
    } else {
      return UnknownSongWidget(
        hash: song.isBuiltinSong ? "Built-in song" : song.hash,
        songName: song.songName,
        extraIcons: [
          IconButton(
              tooltip: "Remove song",
              onPressed: () => _removeSongByHash(song.hash),
              icon: const Icon(Icons.delete)),
          if (!_isDownloadingAll &&
              !_downloadingSongs.contains(song.hash) &&
              !song.isBuiltinSong)
            IconButton(
                tooltip: "Download song",
                onPressed: () => _tryDownloadMissingSong(song.hash),
                icon: const Icon(Icons.download)),
          if (_downloadingSongs.contains(song.hash))
            const CircularProgressIndicator(),
        ],
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

        PopupMenuItem(
          onTap: () => _reorderPlaylist(context),
          child: const Text('Change song order'),
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
              title: GenericListHead<PlayListSong>(_listController),
              flexibleSpace: FlexibleSpaceBar(
                background: Padding(
                    padding: const EdgeInsets.only(top: 40),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        SizedBox(
                            height: 220,
                            child:
                                PlaylistWidget.playlistIcon(widget.playlist)),
                        SizedBox(
                            width: MediaQuery.of(context).size.width * 0.5,
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: _buildMetadata(),
                            ))
                      ],
                    )),
                collapseMode: CollapseMode.pin,
              )),
          if (widget.playlist.playlistDescription != null)
            SliverList(
                delegate: SliverChildListDelegate(
              [
                Center(
                  child: Padding(
                    padding: GuiUtil.defaultViewPadding(context),
                    child: Column(children: [
                      const Divider(),
                      Text(widget.playlist.playlistDescription!),
                      const Divider(),
                    ]),
                  ),
                )
              ],
            )),
          SliverToBoxAdapter(
              child: Padding(
            padding: GuiUtil.defaultViewPadding(context),
            child: GenericListBody<PlayListSong>(
                controller: _listController, fixedList: true),
          )),
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

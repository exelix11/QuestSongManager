import 'package:bsaberquest/util/gui_util.dart';
import 'package:bsaberquest/main.dart';
import 'package:bsaberquest/mod_manager/gui/playlist_picker_page.dart';
import 'package:bsaberquest/mod_manager/gui/simple_widgets.dart';
import 'package:bsaberquest/mod_manager/gui/song_detail_page.dart';
import 'package:bsaberquest/mod_manager/model/song.dart';
import 'package:flutter/material.dart';

import '../model/playlist.dart';

class SongListWidgetController {
  Map<String, Song>? _initialSongs;
  SongListWidgetController(this._initialSongs);
  SongListWidgetState? _state;

  void _subscribe(SongListWidgetState state) {
    state.songListChanged(_initialSongs ?? {});
    _initialSongs = null;
    _state = state;
  }

  void songListChanged(Map<String, Song> songs) {
    if (_state != null) {
      _state!.songListChanged(songs);
    } else {
      _initialSongs = songs;
    }
  }
}

class SongListWidgetState extends State<SongListWidget> {
  final Set<String> _selection = <String>{};
  final Set<String> _searchHits = <String>{};
  final TextEditingController _searchController = TextEditingController();

  List<Song> _allSongs = [];
  Map<String, Song> _songMap = {};

  bool _showSearch = false;

  @override
  void initState() {
    var controller = widget.controller;
    controller._subscribe(this);
    super.initState();
  }

  @override
  void dispose() {
    super.dispose();
  }

  void _addOrRemoveSongFromSelection(Song song) {
    var hash = song.hash;

    setState(() {
      if (_selection.contains(hash)) {
        _selection.remove(hash);
      } else {
        _selection.add(hash);
      }
    });
  }

  void _openSongPage(Song song) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => SongDetailPage(song: song),
      ),
    );
  }

  void _onSearchTextChanged(String text) {
    setState(() {
      _searchHits.clear();
      _searchHits.addAll(_allSongs
          .where((element) => element.isValid && element.meta.query(text))
          .map((e) => e.hash));
    });
  }

  Widget? _buildItem(BuildContext context, int index) {
    var song = _allSongs[index];

    if (_searchController.text.isNotEmpty) {
      if (!_searchHits.contains(song.hash)) return Container();
    }

    if (_isAnySelected()) {
      return SongWidget(
        song: song,
        onTap: _addOrRemoveSongFromSelection,
        highlight: _selection.contains(song.hash),
      );
    } else {
      return SongWidget(
        song: song,
        onTap: _openSongPage,
        onLongPress: _addOrRemoveSongFromSelection,
      );
    }
  }

  bool _isAnySelected() {
    return _selection.isNotEmpty;
  }

  void _selectAllInView() {
    setState(() {
      _selection.addAll(_allSongs.map((e) => e.hash));
    });
  }

  void _clearSelection() {
    setState(() {
      _selection.clear();
    });
  }

  void songListChanged(Map<String, Song> songs) {
    setState(() {
      _songMap = songs;
      _allSongs = songs.values.toList();
      _removeInvalidSongsFromSelection();
    });
  }

  void _openSearch() {
    setState(() {
      _showSearch = true;
    });
  }

  void _closeSearch() {
    setState(() {
      _searchController.text = "";
      _showSearch = false;
    });
  }

  void _removeInvalidSongsFromSelection() {
    _selection.removeWhere((hash) => !_songMap.containsKey(hash));
    _searchHits.removeWhere((hash) => !_songMap.containsKey(hash));
  }

  void _addSelectionToPlaylist() async {
    var playlist = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const PlaylistPickerPage(),
      ),
    ) as Playlist?;

    if (playlist == null) {
      return;
    }

    var songs = _selection
        .map((e) => _songMap[e])
        .where((x) => x != null && x.isValid)
        .map((e) => PlayListSong(e!.hash, e.meta.songName))
        .toList();

    _clearSelection();

    playlist.songs.addAll(songs);

    try {
      await App.modManager.applyPlaylistChanges(playlist);
      App.showToast('Added ${songs.length} songs to ${playlist.playlistTitle}');
    } catch (e) {
      App.showToast('Error $e');
    }
  }

  void _deleteSelection() async {
    var confirm = await GuiUtil.confirmChoice(context, "Delete songs",
        "Are you sure you want to delete ${_selection.length} songs?");
    if (confirm == null || !confirm) {
      return;
    }

    var toDelete = _selection
        .map((e) => _songMap[e])
        .where((x) => x != null && x.isValid)
        .map((e) => e!)
        .toList();

    _clearSelection();

    try {
      await App.modManager.deleteSongs(toDelete);
      App.showToast('Deleted ${toDelete.length} songs');
    } catch (e) {
      App.showToast('Error $e');
    }
  }

  AppBar _appbar() {
    var titleText = "";

    if (_isAnySelected()) {
      titleText = "${_selection.length} selected";
    } else if (_searchController.text.isNotEmpty) {
      titleText = "${_searchHits.length} results";
    } else {
      titleText = "Found ${_allSongs.length} songs";
    }

    List<Widget> actions = [];

    if (_showSearch) {
      actions.add(IconButton(
          icon: const Icon(Icons.search_off_outlined),
          onPressed: _closeSearch));
    } else {
      actions.add(
          IconButton(icon: const Icon(Icons.search), onPressed: _openSearch));
    }

    if (_isAnySelected()) {
      actions.add(IconButton(
          icon: const Icon(Icons.playlist_add),
          onPressed: _addSelectionToPlaylist));
      actions.add(IconButton(
          icon: const Icon(Icons.delete), onPressed: _deleteSelection));

      actions.add(IconButton(
          icon: const Icon(Icons.clear), onPressed: _clearSelection));
    } else {
      actions.add(IconButton(
          icon: const Icon(Icons.select_all), onPressed: _selectAllInView));
    }

    if (_showSearch) {
      return AppBar(
        title: Row(children: [
          Text(titleText),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              controller: _searchController,
              onChanged: _onSearchTextChanged,
              decoration: const InputDecoration(
                hintText: 'Search',
              ),
            ),
          ),
        ]),
        actions: actions,
      );
    } else {
      return AppBar(title: Text(titleText), actions: actions);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _appbar(),
      body: ListView.builder(
          padding: GuiUtil.defaultViewPadding(context),
          itemCount: _allSongs.length,
          itemBuilder: _buildItem),
    );
  }
}

class SongListWidget extends StatefulWidget {
  const SongListWidget(this.controller, {super.key});

  final SongListWidgetController controller;

  @override
  State<SongListWidget> createState() => SongListWidgetState();
}

import 'dart:async';

import 'package:bsaberquest/gui_util.dart';
import 'package:bsaberquest/main.dart';
import 'package:bsaberquest/mod_manager/gui/playlist_picker_page.dart';
import 'package:bsaberquest/mod_manager/gui/song_detail_page.dart';
import 'package:bsaberquest/mod_manager/model/song.dart';
import 'package:flutter/material.dart';

import 'simple_widgets.dart';

class SongsListState extends State<SongListPage> {
  late StreamSubscription _songListSubscription;

  final Set<String> _selection = <String>{};
  final TextEditingController _searchController = TextEditingController();

  List<String> _uiSongs = [];

  bool _showSearch = false;

  @override
  void initState() {
    _songListSubscription =
        App.modManager.songListObservable.stream.listen((_) {
      _songListChanged();
    });

    _updateSearchResults(null);

    super.initState();
  }

  @override
  void dispose() {
    _songListSubscription.cancel();
    super.dispose();
  }

  void _addOrRemoveSongFromSelection(Song song) {
    var hash = song.hash;

    if (hash == null) {
      return;
    }

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

  Widget? _buildItem(BuildContext context, int index) {
    var hash = _uiSongs[index];
    var song = App.modManager.songs[hash];

    if (song == null) {
      // Shouldn't happen
      return null;
    }

    if (_isAnySelected()) {
      return SongWidget(
        song: song,
        onTap: _addOrRemoveSongFromSelection,
        highlight: _selection.contains(hash),
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
      _selection.addAll(_uiSongs);
    });
  }

  void _clearSelection() {
    setState(() {
      _selection.clear();
    });
  }

  void _songListChanged() {
    _updateSearchResults(_searchController.text);
  }

  void _openSearch() {
    setState(() {
      _showSearch = true;
    });
    _updateSearchResults(null);
  }

  void _closeSearch() {
    setState(() {
      _showSearch = false;
    });
    _updateSearchResults(null);
  }

  void _updateSearchResults(String? value) {
    if (value == null || value.isEmpty) {
      setState(() {
        _uiSongs = App.modManager.songs.keys.toList();
      });
    } else {
      value = value.toLowerCase();

      setState(() {
        _uiSongs = App.modManager.songs.values
            .where((element) => element.isValid && element.meta.query(value!))
            .map((e) => e.hash!)
            .toList(growable: false);

        // deselect songs that are not in the search results
        _selection.removeWhere((element) => !_uiSongs.contains(element));
      });
    }
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
        .map((e) => App.modManager.songs[e])
        .where((x) => x != null && x.isValid)
        .map((e) => PlayListSong(e!.hash!, e.meta.songName))
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
        .map((e) => App.modManager.songs[e])
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
    var titleText =
        _isAnySelected() ? '${_selection.length} selected' : 'Song List';

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
              onChanged: _updateSearchResults,
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
      body:
          ListView.builder(itemCount: _uiSongs.length, itemBuilder: _buildItem),
    );
  }
}

class SongListPage extends StatefulWidget {
  const SongListPage({super.key});

  @override
  State<SongListPage> createState() => SongsListState();
}

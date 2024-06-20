import 'package:bsaberquest/util/generic_list_widget.dart';
import 'package:bsaberquest/util/gui_util.dart';
import 'package:bsaberquest/main.dart';
import 'package:bsaberquest/mod_manager/gui/simple_widgets.dart';
import 'package:bsaberquest/mod_manager/gui/song_detail_page.dart';
import 'package:bsaberquest/mod_manager/model/song.dart';
import 'package:bsaberquest/util/list_item_picker_page.dart';
import 'package:flutter/material.dart';

import '../model/playlist.dart';

class SongListWidget extends StatelessWidget {
  final SongListWidgetController renderer;
  final GenericListController<Song> _listController;

  SongListWidget(this.renderer, {super.key})
      : _listController = GenericListController(renderer);

  @override
  Widget build(BuildContext context) =>
      GenericList<Song>(controller: _listController);
}

class SongListWidgetController extends GenericListRenderer<Song> {
  final Function(BuildContext, Map<String, Song>) deleteSongs;

  SongListWidgetController(Map<String, Song>? initial, this.deleteSongs) {
    initialItems = initial;
    itemName = "song";
    itemsName = "songs";
  }

  @override
  String getItemUniqueKey(Song item) => item.hash;

  @override
  bool queryItem(Song item, String query) =>
      item.isValid && item.meta.query(query);

  @override
  Widget? renderItem(BuildContext context, Song item, bool isSelected,
      bool isAnySelected, Function()? selectCallback) {
    if (isAnySelected) {
      return SongWidget(
        song: item,
        onTap: selectCallback,
        highlight: isSelected,
      );
    } else {
      return SongWidget(
        song: item,
        onTap: () => _openSongPage(context, item),
        onLongPress: selectCallback,
      );
    }
  }

  @override
  void configureAppButtons(BuildContext context, List<Widget> actions) {
    if (controller.selection.isEmpty) {
      return;
    }

    actions.add(IconButton(
        tooltip: "Add selection to playlist",
        icon: const Icon(Icons.playlist_add),
        onPressed: () => _addSelectionToPlaylist(context)));

    actions.add(IconButton(
        tooltip: "Delete selected items",
        icon: const Icon(Icons.delete),
        onPressed: () => _handleDeleteSelection(context)));
  }

  void _handleDeleteSelection(BuildContext context) {
    deleteSongs(context, controller.getSelection());
    controller.clearSelection();
  }

  void _openSongPage(BuildContext context, Song song) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => SongDetailPage(song: song),
      ),
    );
  }

  void _addSelectionToPlaylist(BuildContext context) async {
    var playlist = await CommonPickers.pickPlaylist(context);

    if (playlist == null) {
      return;
    }

    var songs = controller.selection
        .map((e) => controller.items[e])
        .where((x) => x != null && x.isValid)
        .map((e) => PlayListSong(e!.hash, e.meta.songName))
        .toList();

    controller.clearSelection();

    playlist.songs.addAll(songs);

    try {
      await App.modManager.applyPlaylistChanges(playlist);
      App.showToast('Added ${songs.length} songs to ${playlist.playlistTitle}');
    } catch (e) {
      App.showToast('Error $e');
    }
  }
}

class GenericSongControllerActions {
  static void deleteSelected(
      BuildContext context, Map<String, Song> songs) async {
    var confirm = await GuiUtil.confirmChoice(context, "Delete songs",
        "Are you sure you want to delete ${songs.length} songs?");
    if (confirm == null || !confirm) {
      return;
    }

    try {
      await App.modManager.deleteSongs(songs.values.toList());
      App.showToast('Deleted ${songs.length} songs');
    } catch (e) {
      App.showToast('Error $e');
    }
  }
}

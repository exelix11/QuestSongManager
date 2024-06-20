import 'package:bsaberquest/util/generic_list_widget.dart';
import 'package:bsaberquest/util/gui_util.dart';
import 'package:bsaberquest/main.dart';
import 'package:bsaberquest/mod_manager/gui/simple_widgets.dart';
import 'package:bsaberquest/mod_manager/gui/song_detail_page.dart';
import 'package:bsaberquest/mod_manager/model/song.dart';
import 'package:bsaberquest/util/list_item_picker_page.dart';
import 'package:flutter/material.dart';

import '../model/playlist.dart';

class SongListWidgetController {
  final Function(BuildContext, List<Song>)? deleteHandler;
  late GenericListController<Song> list;

  SongListWidgetController(Map<String, Song>? initial, {this.deleteHandler}) {
    list = GenericListController(
        itemName: "song",
        itemsName: "songs",
        items: initial ?? {},
        getItemUniqueKey: (x) => x.hash,
        queryItem: (x, query) => x.isValid && x.meta.query(query),
        canSelect: true,
        configureAppButtons: _configureAppButtons,
        renderItem: _renderItem);
  }

  static void _openSongPage(BuildContext context, Song song) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => SongDetailPage(song: song),
      ),
    );
  }

  void _configureAppButtons(BuildContext context, List<Widget> actions) {
    if (!list.anySelected) {
      return;
    }

    actions.add(IconButton(
        tooltip: "Add selection to playlist",
        icon: const Icon(Icons.playlist_add),
        onPressed: () => _addSelectionToPlaylist(context)));

    if (deleteHandler != null) {
      actions.add(IconButton(
          tooltip: "Delete selected items",
          icon: const Icon(Icons.delete),
          onPressed: () => deleteHandler!(context, list.selectedItems)));
    }
  }

  Widget _renderItem(BuildContext context,
      GenericListController<Song> controller, Song item, bool isSelected) {
    if (controller.anySelected) {
      return SongWidget(
        song: item,
        onTap: () => controller.toggleItemSelection(item),
        highlight: isSelected,
      );
    } else {
      return SongWidget(
        song: item,
        onTap: () => _openSongPage(context, item),
        onLongPress: () => controller.toggleItemSelection(item),
      );
    }
  }

  void _addSelectionToPlaylist(BuildContext context) async {
    var playlist = await CommonPickers.pickPlaylist(context);

    if (playlist == null) {
      return;
    }

    var songs = list.selectedItems
        .where((e) => e.isValid)
        .map((e) => PlayListSong.fromSong(e));

    playlist.songs.addAll(songs);

    try {
      await App.modManager.applyPlaylistChanges(playlist);
      App.showToast('Added ${songs.length} songs to ${playlist.playlistTitle}');
    } catch (e) {
      App.showToast('Error $e');
      return;
    }

    list.clearSelection();
  }
}

class SongListWidget extends StatelessWidget {
  final SongListWidgetController controller;

  const SongListWidget(this.controller, {super.key});

  @override
  Widget build(BuildContext context) =>
      GenericList<Song>(controller: controller.list);
}

class GenericSongControllerActions {
  static void deleteSelected(BuildContext context, List<Song> songs) async {
    var confirm = await GuiUtil.confirmChoice(context, "Delete songs",
        "Are you sure you want to delete ${songs.length} songs?");
    if (confirm == null || !confirm) {
      return;
    }

    try {
      await App.modManager.deleteSongs(songs);
      App.showToast('Deleted ${songs.length} songs');
    } catch (e) {
      App.showToast('Error $e');
    }
  }
}

import 'package:bsaberquest/main.dart';
import 'package:bsaberquest/mod_manager/gui/simple_widgets.dart';
import 'package:bsaberquest/mod_manager/model/playlist.dart';
import 'package:bsaberquest/util/generic_list_widget.dart';
import 'package:flutter/material.dart';

typedef ConfirmCallback<T> = void Function(T item);

// ignore: must_be_immutable
class ListItemPickerPage<T> extends StatelessWidget {
  final String title;
  final Widget Function(BuildContext, ConfirmCallback, T) itemBuilder;
  final bool Function(String, T)? filter;
  final bool showListHeading;

  final Map<String, T> _content = {};
  final Map<T, String> _inverseLookup = {};

  late GenericListController<T> _controller;

  ListItemPickerPage(
      {super.key,
      required List<T> items,
      required this.itemBuilder,
      required this.title,
      this.showListHeading = true,
      this.filter}) {
    for (int i = 0; i < items.length; i++) {
      _content[i.toString()] = items[i];
      _inverseLookup[items[i]] = i.toString();
    }

    _controller = GenericListController(
        items: _content,
        getItemUniqueKey: (x) => _inverseLookup[x]!,
        queryItem: filter == null ? null : (query, x) => filter!(x, query),
        renderItem: _itemBuilder,
        canSelect: false,
        showHeading: showListHeading);
  }

  Widget _itemBuilder(BuildContext context, GenericListController<T> controller,
      T item, bool isSelected) {
    return itemBuilder(context, (x) => _confirmSelection(context, x), item);
  }

  void _confirmSelection(BuildContext context, T item) {
    Navigator.pop(context, item);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
          title: Text(title),
        ),
        body: GenericList<T>(controller: _controller));
  }
}

class CommonPickers {
  static Future<T?> pick<T>(
      BuildContext context, ListItemPickerPage<T> page) async {
    return await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => page,
      ),
    ) as T?;
  }

  static Future<Playlist?> pickPlaylist(BuildContext context) async {
    return await pick<Playlist>(context, playlistPickerPage());
  }

  static ListItemPickerPage<Playlist> playlistPickerPage() {
    var playlists = App.modManager.playlists.values.toList();

    return ListItemPickerPage<Playlist>(
        title: "Pick a playlist",
        items: playlists,
        filter: (text, playlist) => playlist.query(text),
        itemBuilder: (context, confirm, playlist) {
          return PlaylistWidget(playlist: playlist, onTap: confirm);
        });
  }
}

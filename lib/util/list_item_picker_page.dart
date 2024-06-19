import 'package:bsaberquest/main.dart';
import 'package:bsaberquest/mod_manager/gui/simple_widgets.dart';
import 'package:bsaberquest/mod_manager/model/playlist.dart';
import 'package:bsaberquest/util/gui_util.dart';
import 'package:flutter/material.dart';

typedef ConfirmCallback<T> = void Function(T item);

class ListItemPickerPage<T> extends StatelessWidget {
  final String title;
  final List<T> items;
  final Widget Function(BuildContext, ConfirmCallback, T) itemBuilder;

  const ListItemPickerPage(
      {super.key,
      required this.items,
      required this.itemBuilder,
      required this.title});

  void _confirmSelection(BuildContext context, T item) {
    Navigator.pop(context, item);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
          title: Text(title),
        ),
        body: ListView.builder(
          padding: GuiUtil.defaultViewPadding(context),
          itemCount: items.length,
          itemBuilder: (context, index) {
            return itemBuilder(
                context, (x) => _confirmSelection(context, x), items[index]);
          },
        ));
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
        itemBuilder: (context, confirm, playlist) {
          return PlaylistWidget(playlist: playlist, onTap: confirm);
        });
  }
}

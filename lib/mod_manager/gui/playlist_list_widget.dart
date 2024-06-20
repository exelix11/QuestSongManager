import 'package:bsaberquest/mod_manager/gui/simple_widgets.dart';
import 'package:bsaberquest/mod_manager/model/playlist.dart';
import 'package:bsaberquest/util/generic_list_widget.dart';
import 'package:flutter/material.dart';

class PlaylistListWidget extends StatelessWidget {
  final PlaylistListWidgetController renderer;
  final GenericListController<Playlist> _listController;

  PlaylistListWidget(this.renderer, {super.key})
      : _listController = GenericListController(renderer) {}

  @override
  Widget build(BuildContext context) =>
      GenericList<Playlist>(controller: _listController);
}

class PlaylistListWidgetController extends GenericListRenderer<Playlist> {
  final Function(BuildContext, Playlist)? onTap;
  final Function(BuildContext, Map<String, Playlist>)? deleteHandler;
  final Widget Function()? dotsMenu;

  PlaylistListWidgetController(Map<String, Playlist> initial, this.onTap,
      {this.deleteHandler, this.dotsMenu}) {
    initialItems = initial;
    itemName = "playlist";
    itemsName = "playlists";
  }

  @override
  String getItemUniqueKey(Playlist item) => item.fileName;

  @override
  bool queryItem(Playlist item, String query) => item.query(query);

  @override
  void configureAppButtons(
      BuildContext context, List<Widget> configureAppButtons) {
    if (controller.selection.isNotEmpty) {
      if (deleteHandler != null) {
        configureAppButtons.add(IconButton(
          tooltip: "Delete selected",
          icon: const Icon(Icons.delete),
          onPressed: () {
            deleteHandler!(context, controller.getSelection());
            controller.clearSelection();
          },
        ));
      }
    }

    if (dotsMenu != null) {
      configureAppButtons.add(dotsMenu!());
    }
  }

  @override
  Widget? renderItem(BuildContext context, Playlist item, bool isSelected,
      bool isAnySelected, Function() selectCallback) {
    if (isAnySelected) {
      return PlaylistWidget(
        playlist: item,
        onTap: (e) => selectCallback(),
        highlit: isSelected,
      );
    } else {
      return PlaylistWidget(
          playlist: item,
          onTap: onTap == null ? null : (e) => onTap!(context, item),
          onLongPress: (e) => selectCallback());
    }
  }
}

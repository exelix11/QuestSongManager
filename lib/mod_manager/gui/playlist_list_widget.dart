import 'package:bsaberquest/mod_manager/gui/simple_widgets.dart';
import 'package:bsaberquest/mod_manager/model/playlist.dart';
import 'package:bsaberquest/util/generic_list_widget.dart';
import 'package:flutter/material.dart';

class PlaylistListWidget extends StatelessWidget {
  final PlaylistListWidgetController renderer;

  const PlaylistListWidget(this.renderer, {super.key});

  @override
  Widget build(BuildContext context) =>
      GenericList<Playlist>(controller: renderer.list);
}

class PlaylistListWidgetController {
  final Function(BuildContext, Playlist)? onTap;
  final Function(BuildContext, List<Playlist>)? deleteHandler;
  final Widget Function()? dotsMenu;

  late GenericListController<Playlist> list;

  PlaylistListWidgetController(Map<String, Playlist> initial, this.onTap,
      {this.deleteHandler, this.dotsMenu}) {
    list = GenericListController(
        itemName: "playlist",
        itemsName: "playlists",
        items: initial,
        getItemUniqueKey: (x) => x.fileName,
        queryItem: (x, query) => x.query(query),
        canSelect: true,
        configureAppButtons: configureAppButtons,
        renderItem: renderItem);
  }

  void configureAppButtons(
      BuildContext context, List<Widget> configureAppButtons) {
    if (list.anySelected) {
      if (deleteHandler != null) {
        configureAppButtons.add(IconButton(
          tooltip: "Delete selected",
          icon: const Icon(Icons.delete),
          onPressed: () {
            deleteHandler!(context, list.selectedItems);
            list.clearSelection();
          },
        ));
      }
    }

    if (dotsMenu != null) {
      configureAppButtons.add(dotsMenu!());
    }
  }

  Widget? renderItem(
      BuildContext context,
      GenericListController<Playlist> controller,
      Playlist item,
      bool isSelected) {
    if (controller.anySelected) {
      return PlaylistWidget(
        playlist: item,
        onTap: controller.toggleItemSelection,
        highlit: isSelected,
      );
    } else {
      return PlaylistWidget(
          playlist: item,
          onTap: onTap == null ? null : (e) => onTap!(context, item),
          onLongPress: controller.toggleItemSelection);
    }
  }
}

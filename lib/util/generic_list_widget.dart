import 'package:bsaberquest/util/gui_util.dart';
import 'package:flutter/material.dart';

abstract class GenericListRenderer<T> {
  late GenericListController<T> controller;

  String getItemUniqueKey(T item);
  bool queryItem(T item, String query);
  Widget? renderItem(BuildContext context, T item, bool isSelected,
      bool isAnySelected, Function() selectCallback);

  void configureAppButtons(
      BuildContext context, List<Widget> configureAppButtons) {}
}

class GenericListController<T> {
  GenericListState<T>? _state;

  final GenericListRenderer<T> render;
  late Map<String, T> items;
  Set<String> selection = {};

  GenericListController(this.render);

  factory GenericListController.map(
      GenericListRenderer<T> render, Map<String, T> itemMap) {
    return GenericListController(render)..setItems(itemMap);
  }

  factory GenericListController.list(
      GenericListRenderer<T> render, Iterable<T> itemList) {
    return GenericListController(render)..mapItems(itemList);
  }

  void setItems(Map<String, T> itemMap) {
    items = itemMap;
    _state?._itemsChanged();
  }

  void mapItems(Iterable<T> itemList) {
    items = Map.fromIterable(itemList, key: (e) => render.getItemUniqueKey(e));
    _state?._itemsChanged();
  }

  void _subscribe(GenericListState<T> state) {
    _state = state;
    render.controller = this;
    state._itemsChanged();
  }

  void clearSelection() {
    selection.clear();
    _state?._itemsChanged();
  }
}

class GenericListState<T> extends State<GenericList<T>> {
  final GenericListController<T> controller;
  final Set<String> _searchHits = <String>{};
  final TextEditingController _searchController = TextEditingController();
  bool _showSearch = false;

  GenericListState({required this.controller});

  @override
  void initState() {
    controller._subscribe(this);
    super.initState();
  }

  void _toggleItemSelectionState(T item) {
    var hash = controller.render.getItemUniqueKey(item);

    setState(() {
      if (controller.selection.contains(hash)) {
        controller.selection.remove(hash);
      } else {
        controller.selection.add(hash);
      }
    });
  }

  void _onSearchTextChanged(String text) {
    setState(() {
      _searchHits.clear();
      _searchHits.addAll(controller.items.values
          .where((e) => controller.render.queryItem(e, text))
          .map((e) => controller.render.getItemUniqueKey(e)));
    });
  }

  Widget _buildItem(BuildContext context, String key) {
    var item = controller.items[key];

    if (item == null) {
      return Container(); // This should never happen, but we do it to silence dart warnings
    }

    if (_searchController.text.isNotEmpty) {
      if (!_searchHits.contains(key)) return Container();
    }

    var isSelected = widget.canSelect &&
        controller.selection
            .contains(widget.controller.render.getItemUniqueKey(item));
    var isAnySelected = widget.canSelect && controller.selection.isNotEmpty;

    var rendered = widget.controller.render
        .renderItem(context, item, isSelected, isAnySelected, () {
      if (widget.canSelect) _toggleItemSelectionState(item);
    });

    if (rendered == null) return Container();
    return rendered;
  }

  void _selectAllInView() {
    setState(() {
      controller.selection.addAll(
          _searchController.text.isEmpty ? controller.items.keys : _searchHits);
    });
  }

  void _clearSelection() {
    setState(() {
      controller.selection.clear();
    });
  }

  void _itemsChanged() {
    _removeInvalidSongsFromSelection();
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
    controller.selection
        .removeWhere((key) => !controller.items.containsKey(key));
    _searchHits.removeWhere((key) => !controller.items.containsKey(key));

    setState(() {});
  }

  Widget _buildControlBar() {
    var titleText = "";

    if (widget.canSelect && controller.selection.isNotEmpty) {
      titleText = "${controller.selection.length} selected";
    } else if (_searchController.text.isNotEmpty) {
      titleText = "${_searchHits.length} results";
    } else {
      titleText = "Found ${controller.items.length} items";
    }

    List<Widget> actions = [];

    if (_showSearch) {
      actions.add(IconButton(
          tooltip: "Close search",
          icon: const Icon(Icons.search_off_outlined),
          onPressed: _closeSearch));
    } else {
      actions.add(IconButton(
          tooltip: "Search",
          icon: const Icon(Icons.search),
          onPressed: _openSearch));
    }

    if (controller.selection.isNotEmpty) {
      actions.add(IconButton(
          tooltip: "Select none",
          icon: const Icon(Icons.clear),
          onPressed: _clearSelection));
    } else if (widget.canSelect) {
      actions.add(IconButton(
          tooltip: "Select all",
          icon: const Icon(Icons.select_all),
          onPressed: _selectAllInView));
    }

    controller.render.configureAppButtons(context, actions);

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: <Widget>[
        // Left aligned header and search
        Row(
          children: [
            Text(titleText, style: const TextStyle(fontSize: 20)),
            const SizedBox(width: 10),
            if (_showSearch)
              SizedBox(
                  width: MediaQuery.of(context).size.width * 0.4,
                  child: TextField(
                    controller: _searchController,
                    onChanged: _onSearchTextChanged,
                    decoration: const InputDecoration(
                      hintText: 'Search',
                    ),
                  ))
          ],
        ),
        // Right aligned action buttons
        Row(children: actions),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListView(padding: GuiUtil.defaultViewPadding(context), children: [
      _buildControlBar(),
      ...controller.items.keys.map((key) => _buildItem(context, key)),
    ]);
  }
}

class GenericList<T> extends StatefulWidget {
  final GenericListController<T> controller;
  final bool canSelect;

  const GenericList({
    super.key,
    required this.controller,
    this.canSelect = true,
  });

  @override
  GenericListState<T> createState() =>
      // ignore: no_logic_in_create_state
      GenericListState<T>(controller: controller);
}

import 'package:bsaberquest/util/gui_util.dart';
import 'package:flutter/material.dart';

typedef ItemUniqueKeyGetter<T> = String Function(T item);
typedef ItemQueryCallback<T> = bool Function(T item, String query);
typedef ItemRenderer<T> = Widget? Function(BuildContext context,
    GenericListController<T> controller, T item, bool isSelected);
typedef ConfigureAppButtonsCallback = void Function(
    BuildContext context, List<Widget> configureAppButtons);

class GenericListController<T> {
  GenericListState<T>? _state;

  final String itemsName;
  final String itemName;

  final ItemUniqueKeyGetter<T> getItemUniqueKey;
  final ItemQueryCallback<T> queryItem;
  final ItemRenderer<T> renderItem;
  final ConfigureAppButtonsCallback? configureAppButtons;
  final bool canSelect;

  Map<String, T> items;
  Set<String> selection = {};

  bool get anySelected => selection.isNotEmpty;

  List<T> get selectedItems => selection
      .map((e) => items[e])
      .where((e) => e != null)
      .map((e) => e!)
      .toList(growable: false);

  GenericListController(
      {required this.items,
      required this.getItemUniqueKey,
      required this.queryItem,
      required this.renderItem,
      this.configureAppButtons,
      this.canSelect = true,
      this.itemName = "item",
      this.itemsName = "items"});

  void trySetList(Iterable<T> items) {
    Map<String, T> mapped =
        Map.fromIterable(items, key: (e) => getItemUniqueKey(e));
    setItems(mapped);
  }

  void setItems(Map<String, T> itemMap) {
    items = itemMap;
    _state?._itemsChanged();
  }

  void toggleItemSelection(T item) {
    var key = getItemUniqueKey(item);
    if (selection.contains(key)) {
      selection.remove(key);
    } else {
      selection.add(key);
    }
    _state?._itemsChanged();
  }

  void _subscribe(GenericListState<T> state) {
    _state = state;
    state._itemsChanged();
  }

  void clearSelection() {
    selection.clear();
    _state?._itemsChanged();
  }

  Map<String, T> getSelection() {
    Map<String, T> map = {};

    for (var key in selection) {
      var item = items[key];
      if (item != null) map[key] = item;
    }

    return map;
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

  void _onSearchTextChanged(String text) {
    setState(() {
      _searchHits.clear();
      text = text.toLowerCase();
      _searchHits.addAll(controller.items.values
          .where((e) => controller.queryItem(e, text))
          .map((e) => controller.getItemUniqueKey(e)));
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

    var isSelected = controller.canSelect &&
        controller.selection.contains(widget.controller.getItemUniqueKey(item));

    var rendered =
        widget.controller.renderItem(context, controller, item, isSelected);

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

    if (controller.canSelect && controller.selection.isNotEmpty) {
      titleText = "${controller.selection.length} selected";
    } else if (_searchController.text.isNotEmpty) {
      titleText = "${_searchHits.length} results";
    } else {
      titleText = "Found ${controller.items.length} ";
      if (controller.items.length == 1) {
        titleText += controller.itemName;
      } else {
        titleText += controller.itemsName;
      }
    }

    List<Widget> actions = [];

    if (_showSearch) {
      actions.add(IconButton(
          tooltip: "Close search",
          icon: const Icon(Icons.search_off_outlined),
          onPressed: _closeSearch));
    } else if (controller.items.isNotEmpty) {
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
    } else if (controller.canSelect && controller.items.isNotEmpty) {
      actions.add(IconButton(
          tooltip: "Select all",
          icon: const Icon(Icons.select_all),
          onPressed: _selectAllInView));
    }

    if (controller.configureAppButtons != null) {
      controller.configureAppButtons!(context, actions);
    }

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

  Widget _buildListView() => ListView(
          shrinkWrap: widget.fixedList,
          physics:
              widget.fixedList ? const NeverScrollableScrollPhysics() : null,
          children: [
            ...controller.items.keys.map((key) => _buildItem(context, key)),
          ]);

  Widget _pad(Widget base) {
    if (widget.padded) {
      return Padding(
        padding: GuiUtil.defaultViewPadding(context),
        child: base,
      );
    } else {
      return base;
    }
  }

  @override
  Widget build(BuildContext context) {
    return _pad(
      Column(
        children: [
          _buildControlBar(),
          if (widget.fixedList)
            _buildListView()
          else
            Expanded(child: _buildListView())
        ],
      ),
    );
  }
}

class GenericList<T> extends StatefulWidget {
  final GenericListController<T> controller;
  final bool fixedList;
  final bool padded;

  const GenericList({
    super.key,
    required this.controller,
    this.fixedList = false,
    this.padded = true,
  });

  @override
  GenericListState<T> createState() =>
      // ignore: no_logic_in_create_state
      GenericListState<T>(controller: controller);
}

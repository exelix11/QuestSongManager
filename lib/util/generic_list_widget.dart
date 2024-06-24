import 'package:bsaberquest/util/gui_util.dart';
import 'package:flutter/material.dart';

typedef ItemUniqueKeyGetter<T> = String Function(T item);
typedef ItemQueryCallback<T> = bool Function(T item, String query);
typedef ItemRenderer<T> = Widget? Function(BuildContext context,
    GenericListController<T> controller, T item, bool isSelected);
typedef ConfigureAppButtonsCallback = void Function(
    BuildContext context, List<Widget> configureAppButtons);

class GenericListController<T> {
  // Internal state
  GenericListBodyState<T>? _body;
  GenericListHeadState<T>? _head;

  final Set<String> _searchHits = <String>{};
  bool _isSearching = false;

  // public state
  final String itemsName;
  final String itemName;

  final ItemUniqueKeyGetter<T> getItemUniqueKey;
  final ItemQueryCallback<T>? queryItem;
  final ItemRenderer<T> renderItem;
  final ConfigureAppButtonsCallback? configureAppButtons;
  final bool canSelect;
  final bool showHeading;

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
      this.queryItem,
      required this.renderItem,
      this.configureAppButtons,
      this.canSelect = true,
      this.itemName = "item",
      this.itemsName = "items",
      this.showHeading = true});

  void trySetList(Iterable<T> items) {
    Map<String, T> mapped =
        Map.fromIterable(items, key: (e) => getItemUniqueKey(e));
    setItems(mapped);
  }

  void setItems(Map<String, T> itemMap) {
    items = itemMap;
    _removeInvalidSongsFromSelection();
    _updateState();
  }

  void toggleItemSelection(T item) {
    var key = getItemUniqueKey(item);
    if (selection.contains(key)) {
      selection.remove(key);
    } else {
      selection.add(key);
    }
    _updateState();
  }

  void _subscribeBody(GenericListBodyState<T> state) {
    _body = state;
  }

  void _subscribeHead(GenericListHeadState<T> state) {
    _head = state;
  }

  void _removeInvalidSongsFromSelection() {
    selection.removeWhere((key) => !items.containsKey(key));
    _searchHits.removeWhere((key) => !items.containsKey(key));
  }

  void _updateState() {
    _body?._updateState();
    _head?._updateState();
  }

  void clearSelection() {
    selection.clear();
    _updateState();
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

class GenericListBodyState<T> extends State<GenericListBody<T>> {
  final GenericListController<T> controller;

  GenericListBodyState({required this.controller});

  @override
  void initState() {
    controller._subscribeBody(this);
    super.initState();
  }

  Widget _buildItem(BuildContext context, String key) {
    var item = controller.items[key];

    if (item == null) {
      return Container(); // This should never happen, but we do it to silence dart warnings
    }

    if (controller._isSearching) {
      if (!controller._searchHits.contains(key)) return Container();
    }

    var isSelected = controller.canSelect &&
        controller.selection.contains(widget.controller.getItemUniqueKey(item));

    var rendered =
        widget.controller.renderItem(context, controller, item, isSelected);

    if (rendered == null) return Container();
    return rendered;
  }

  void _updateState() {
    setState(() {});
  }

  Widget _buildListView() => ListView(
          shrinkWrap: widget.fixedList,
          physics:
              widget.fixedList ? const NeverScrollableScrollPhysics() : null,
          children: [
            ...controller.items.keys.map((key) => _buildItem(context, key)),
          ]);

  @override
  Widget build(BuildContext context) {
    return _buildListView();
  }
}

class GenericListHeadState<T> extends State<GenericListHead<T>> {
  final GenericListController<T> controller;
  final TextEditingController _searchController = TextEditingController();
  bool _showSearch = false;

  GenericListHeadState({required this.controller});

  @override
  void initState() {
    controller._subscribeHead(this);
    super.initState();
  }

  void _updateState() {
    setState(() {});
  }

  void _onSearchTextChanged(String text) {
    if (controller.queryItem == null) return;

    controller._isSearching = text.isNotEmpty;

    controller._searchHits.clear();
    if (controller._isSearching) {
      text = text.toLowerCase();
      controller._searchHits.addAll(controller.items.values
          .where((e) => controller.queryItem!(e, text))
          .map((e) => controller.getItemUniqueKey(e)));
    }

    controller._updateState();
  }

  void _selectAllInView() {
    controller.selection.addAll(_searchController.text.isEmpty
        ? controller.items.keys
        : controller._searchHits);

    controller._updateState();
  }

  void _clearSelection() {
    controller.selection.clear();
    controller._updateState();
  }

  void _openSearch() {
    setState(() {
      _showSearch = true;
    });
  }

  void _closeSearch() {
    _searchController.text = "";
    _onSearchTextChanged("");
    setState(() {
      _showSearch = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    var titleText = "";

    if (controller.canSelect && controller.selection.isNotEmpty) {
      titleText = "${controller.selection.length} selected";
    } else if (_searchController.text.isNotEmpty) {
      titleText = "${controller._searchHits.length} results";
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
    } else if (controller.items.isNotEmpty && controller.queryItem != null) {
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
            if (controller.showHeading)
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
}

class GenericListHead<T> extends StatefulWidget {
  final GenericListController<T> controller;
  const GenericListHead(this.controller, {super.key});

  @override
  GenericListHeadState<T> createState() =>
      // ignore: no_logic_in_create_state
      GenericListHeadState<T>(controller: controller);
}

class GenericListBody<T> extends StatefulWidget {
  final GenericListController<T> controller;
  final bool fixedList;

  const GenericListBody(
      {super.key, required this.controller, this.fixedList = false});

  @override
  GenericListBodyState<T> createState() =>
      // ignore: no_logic_in_create_state
      GenericListBodyState<T>(controller: controller);
}

class GenericList<T> extends StatelessWidget {
  final GenericListController<T> controller;
  final bool fixedList;
  final bool padded;

  const GenericList({
    super.key,
    required this.controller,
    this.fixedList = false,
    this.padded = true,
  });

  Widget _pad(BuildContext context, Widget base) {
    if (padded) {
      return Padding(
        padding: GuiUtil.defaultViewPadding(context),
        child: base,
      );
    } else {
      return base;
    }
  }

  @override
  Widget build(BuildContext context) => _pad(
      context,
      Column(
        children: [
          GenericListHead(controller),
          Expanded(
            child: GenericListBody(
              controller: controller,
              fixedList: fixedList,
            ),
          )
        ],
      ));
}

import 'package:bsaberquest/util/gui_util.dart';
import 'package:bsaberquest/main.dart';
import 'package:bsaberquest/options/preferences.dart';
import 'package:flutter/material.dart';

class BookmarksManagerState extends State<BookmarksManager> {
  BrowserPreferences prefs = BrowserPreferences();
  int homeIndex = 0;

  void _reloadBookmarks() {
    prefs = App.preferences.webBookmarks;
    _updateState();
  }

  void _updateState() {
    setState(() {
      homeIndex = prefs.getHomepageIndex();
    });
  }

  @override
  void initState() {
    _reloadBookmarks();
    super.initState();
  }

  Widget _buildItem(BuildContext context, int index) {
    var bookmark = prefs.bookmarks[index];

    var isDefault = index == homeIndex;
    var leading = isDefault ? const Icon(Icons.home) : null;

    return ListTile(
      title: Text(bookmark.title),
      subtitle: Text(bookmark.url),
      leading: leading,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          isDefault
              ? const SizedBox()
              : IconButton(
                  icon: const Icon(Icons.home),
                  tooltip: "Set as home page",
                  onPressed: () {
                    prefs.homepage = bookmark.url;
                    App.preferences.webBookmarks = prefs;
                    _updateState();
                  },
                ),
          IconButton(
            icon: const Icon(Icons.delete),
            tooltip: "remove",
            onPressed: () async {
              prefs.bookmarks.removeAt(index);
              App.preferences.webBookmarks = prefs;
              _updateState();
            },
          )
        ],
      ),
    );
  }

  void _addNew() async {
    var url = await GuiUtil.textInputDialog(context, "Enter the bookmark URL");
    if (url == null || url.isEmpty) {
      return;
    }

    if (!mounted) return;

    var name =
        await GuiUtil.textInputDialog(context, "Enter the bookmark short name");
    if (name == null || name.isEmpty) {
      return;
    }

    if (!url.toLowerCase().startsWith("http")) url = "https://$url";

    var newBookmark = WebBookmark(name, url);
    prefs.bookmarks.add(newBookmark);

    App.preferences.webBookmarks = prefs;

    _updateState();
  }

  void _revertDefault() async {
    var res = await GuiUtil.confirmChoice(context, "Reset bookmarks",
        "Do you want to reset the bookmarks to the default ones ? All your custom ones will be lost");
    if (res == null || !res) {
      return;
    }

    App.preferences.resetWebBookmarks();
    _reloadBookmarks();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
          title: const Text('Bookmarks'),
          actions: [
            IconButton(
                tooltip: "Add now",
                onPressed: _addNew,
                icon: const Icon(Icons.add)),
            IconButton(
                tooltip: "Restore to default bookmarks",
                onPressed: _revertDefault,
                icon: const Icon(Icons.cleaning_services_outlined)),
          ],
        ),
        body: ListView.builder(
          itemCount: prefs.bookmarks.length,
          itemBuilder: _buildItem,
        ));
  }
}

class BookmarksManager extends StatefulWidget {
  const BookmarksManager({super.key});

  @override
  State<BookmarksManager> createState() => BookmarksManagerState();
}

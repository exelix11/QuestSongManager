import 'package:bsaberquest/gui_util.dart';
import 'package:bsaberquest/main.dart';
import 'package:bsaberquest/preferences.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

class BookmarksManagerState extends State<BookmarksManager> {
  List<WebBookmark> bookmarks = [];

  void _reloadBookmarks() {
    PreferencesManager().getWebBookmarks().then((value) {
      setState(() {
        bookmarks = value;
      });
    });
  }

  @override
  void initState() {
    _reloadBookmarks();
    super.initState();
  }

  Widget _buildItem(BuildContext context, int index) {
    var bookmark = bookmarks[index];
    return ListTile(
      title: Text(bookmark.title),
      subtitle: Text(bookmark.url),
      trailing: IconButton(
        icon: const Icon(Icons.delete),
        onPressed: () async {
          await App.preferences.setWebBookmarks(bookmarks);
          setState(() {
            bookmarks.removeAt(index);
          });
        },
      ),
    );
  }

  void _addNew() async {
    var url = await GuiUtil.textInputDialog(context, "Enter the bookmark URL");
    if (url == null || url.isEmpty) {
      return;
    }

    if (!context.mounted) return;

    var name =
        await GuiUtil.textInputDialog(context, "Enter the bookmark short name");
    if (name == null || name.isEmpty) {
      return;
    }

    if (!url.toLowerCase().startsWith("http")) url = "https://$url";

    var newBookmark = WebBookmark(name, url);
    bookmarks.add(newBookmark);

    await App.preferences.setWebBookmarks(bookmarks);

    setState(() {});
  }

  void _revertDefault() async {
    var res = await GuiUtil.confirmChoice(context, "Reset bookmarks",
        "Do you want to reset the bookmarks to the default ones ? All your custom ones will be lost");
    if (res == null || !res) {
      return;
    }

    await App.preferences.resetWebBookmarks();
    _reloadBookmarks();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
          title: const Text('Favorites'),
          actions: [
            IconButton(onPressed: _addNew, icon: const Icon(Icons.add)),
            IconButton(
                onPressed: _revertDefault,
                icon: const Icon(Icons.cleaning_services_outlined)),
          ],
        ),
        body: ListView.builder(
          itemCount: bookmarks.length,
          itemBuilder: _buildItem,
        ));
  }
}

class BookmarksManager extends StatefulWidget {
  const BookmarksManager({super.key});

  @override
  State<BookmarksManager> createState() => BookmarksManagerState();
}

import 'dart:io';

import 'package:bsaberquest/download_manager/gui/bookmarks_manager.dart';
import 'package:bsaberquest/download_manager/gui/util.dart';
import 'package:bsaberquest/gui_util.dart';
import 'package:bsaberquest/main.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

class OptionsPageState extends State<OptionsPage> {
  final TextEditingController _idController = TextEditingController();

  void _downloadById(BuildContext context) async {
    var id = _idController.text;
    if (id.isEmpty) {
      return;
    }

    await DownloadUtil.downloadById(id, null);
  }

  static Future<bool> requestFileAccess() async {
    if (await Permission.manageExternalStorage.request().isGranted) {
      return true;
    }
    return false;
  }

  Widget _permissionCheckWidget() {
    if (Platform.isAndroid) {
      return ElevatedButton(
          child: const Text('Request file access permission'),
          onPressed: () async {
            if (await requestFileAccess()) {
              _reloadSongs();
            } else {
              App.showToast("Permission denied");
            }
          });
    }

    return const SizedBox();
  }

  Future<int> _doRehashAllSongs() async {
    // First reload in case of changes
    await App.modManager.reloadFromDisk();
    // Then rehash all songs
    int fixed = 0;
    for (var song in App.modManager.songs.values) {
      if (!await App.modManager.checkSongHash(song)) {
        fixed++;
      }
    }

    return fixed;
  }

  void _rehashAllSongs() async {
    if (!App.modManager.useFastHashCache) {
      App.showToast(
          "Hash cache is disabled, rehashing all songs is not possible");
      return;
    }

    var future = _doRehashAllSongs();
    var res = await GuiUtil.loadingDialog(
        context, "Recalculating the hash of all the songs...", future);

    if (res != null) {
      var num = await res;
      if (num == 0) {
        App.showToast("All songs hashes were correct");
      } else {
        App.showToast("$num songs hashes were invalid and have been corrected");
      }
    }
  }

  Widget _hashCacheOptions() {
    var using = App.modManager.useFastHashCache;

    Widget button;

    if (using) {
      button = ElevatedButton(
        onPressed: () async {
          await App.modManager.removeCachedHashes();
          App.modManager.useFastHashCache = false;
          await App.preferences.setUseHashCache(false);
          App.showToast("Hash cache has been disabled");
          setState(() {});
        },
        child: const Text("Remove hash cache"),
      );
    } else {
      button = ElevatedButton(
        onPressed: () async {
          await App.preferences.setUseHashCache(true);
          App.showToast("Restart the app to apply changes");
          setState(() {});
        },
        child: const Text("Enable hash cache"),
      );
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(using ? "Using fast hash cache" : "hash cache has been disabled"),
        const SizedBox(width: 10),
        button,
        const SizedBox(width: 10),
        ElevatedButton(
          onPressed: () => _rehashAllSongs(),
          child: const Text("Check all song hashes"),
        ),
      ],
    );
  }

  Widget _utilOptions() {
    return Row(mainAxisAlignment: MainAxisAlignment.center, children: [
      ElevatedButton(
          onPressed: _reloadSongs,
          child: const Text("Reload songs and playlists")),
      const SizedBox(width: 10),
      ElevatedButton(
          onPressed: _openBookmarksManager,
          child: const Text("Manage browser bookmarks"))
    ]);
  }

  void _reloadSongs() async {
    try {
      await App.modManager.reloadFromDisk();
      App.showToast("Songs reloaded");
    } catch (e) {
      App.showToast("Reloading songs failed: $e");
    }
  }

  void _openBookmarksManager() {
    Navigator.of(context).push(
        MaterialPageRoute(builder: (context) => const BookmarksManager()));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Options'),
      ),
      body: Center(
        child: Column(
          children: [
            _permissionCheckWidget(),
            const SizedBox(height: 20),
            _utilOptions(),
            const SizedBox(height: 20),
            _hashCacheOptions(),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text("Download by ID"),
                const SizedBox(width: 10),
                SizedBox(
                  width: 100,
                  child: TextField(
                    controller: _idController,
                  ),
                ),
                const SizedBox(width: 10),
                ElevatedButton(
                  onPressed: () => _downloadById(context),
                  child: const Text("Download"),
                )
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class OptionsPage extends StatefulWidget {
  const OptionsPage({super.key});

  @override
  OptionsPageState createState() => OptionsPageState();
}

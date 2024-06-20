import 'dart:io';

import 'package:bsaberquest/download_manager/gui/browser_page.dart';
import 'package:bsaberquest/download_manager/gui/pending_downloads_widget.dart';
import 'package:bsaberquest/download_manager/gui/song_update_check_widget.dart';
import 'package:bsaberquest/util/gui_util.dart';
import 'package:bsaberquest/main.dart';
import 'package:bsaberquest/mod_manager/gui/simple_widgets.dart';
import 'package:bsaberquest/rpc/rpc_manager.dart';
import 'package:bsaberquest/util/list_item_picker_page.dart';
import 'package:flutter/material.dart';

class DownloadsTabState extends State<DownloadsTab> {
  bool _playlistIsPersistent = false;

  @override
  void initState() {
    super.initState();

    _playlistIsPersistent = App.preferences.autoDownloadPlaylist != null &&
        App.preferences.autoDownloadPlaylist ==
            App.downloadManager.downloadToPlaylist?.fileName;
  }

  void _openBrowser(String? url) {
    if (Platform.isAndroid) {
      Navigator.push(
        context,
        MaterialPageRoute(
            builder: (context) => BrowserPageView(
                  initialUrl: url,
                )),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Opening browser is not supported on this platform'),
      ));
    }
  }

  void _pickPlaylist(BuildContext context) async {
    var playList = await CommonPickers.pickPlaylist(context);
    App.downloadManager.downloadToPlaylist = playList;

    setState(() {});
  }

  void _clearPlaylist() {
    App.downloadManager.downloadToPlaylist = null;
    _playlistDownloadSetPersistent(false);
  }

  void _playlistDownloadSetPersistent(bool? value) {
    value ??= false;

    if (value) {
      App.preferences.autoDownloadPlaylist =
          App.downloadManager.downloadToPlaylist?.fileName;
    } else {
      App.preferences.autoDownloadPlaylist = null;
    }

    setState(() {
      _playlistIsPersistent = value!;
    });
  }

  Widget _playlistSelectWidget(BuildContext context) {
    if (App.downloadManager.downloadToPlaylist == null) {
      return ListTile(
          title: const Text("Download to playlist"),
          leading: const Icon(Icons.playlist_add),
          subtitle: const Text(
              "Tap to select the playlist where new songs are added automatically"),
          onTap: () => _pickPlaylist(context));
    } else {
      return Column(
        children: [
          const Text("Downloading to playlist"),
          PlaylistWidget(
              playlist: App.downloadManager.downloadToPlaylist!,
              extraIcon: IconButton(
                tooltip: "Clear playlist selection",
                icon: const Icon(Icons.close),
                onPressed: _clearPlaylist,
              )),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Checkbox(
                  value: _playlistIsPersistent,
                  onChanged: _playlistDownloadSetPersistent),
              const Text("Remember playlist selection"),
            ],
          )
        ],
      );
    }
  }

  void _removeRpcHandler() async {
    try {
      await RpcManager.removeRpcHandler();
      App.showToast("Protocol handler removed");
    } catch (e) {
      App.showToast("Error: $e");
    }
  }

  void _installRpcHandler() async {
    try {
      await RpcManager.installRpcHandler();
      App.showToast("Protocol handler installed");
    } catch (e) {
      App.showToast("Error: $e");
    }
  }

  Widget _pcDownloadTextInfo() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        const Text(
            "The in-app browser is not supported on PC. Download songs from the browser using the beatsaber:// protocol."),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ElevatedButton(
                onPressed: _installRpcHandler,
                child: const Text("Install the protocol handler")),
            const SizedBox(width: 30),
            ElevatedButton(
                onPressed: _removeRpcHandler,
                child: const Text("Remove the protocol handler")),
          ],
        )
      ],
    );
  }

  Widget _questOpenBrowser() {
    return ListTile(
      onTap: () => _openBrowser(null),
      title: const Text('Launch browser'),
      leading: const Icon(Icons.online_prediction),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
          title: const Text('Download manager'),
          actions: [
            IconButton(
                tooltip: "Remove completed downloads",
                onPressed: App.downloadManager.clearCompleted,
                icon: const Icon(Icons.playlist_remove))
          ],
        ),
        body: ListView(
          padding: GuiUtil.defaultViewPadding(context),
          children: [
            _playlistSelectWidget(context),
            const SizedBox(height: 20),
            App.isQuest ? _questOpenBrowser() : _pcDownloadTextInfo(),
            const SizedBox(height: 30),
            const MapUpdateCheckWidget(),
            PendingDownloadsWidget(
              navigateCallback: _openBrowser,
              isPartOfList: true,
            )
          ],
        ));
  }
}

class DownloadsTab extends StatefulWidget {
  const DownloadsTab({super.key});

  @override
  State<DownloadsTab> createState() => DownloadsTabState();
}

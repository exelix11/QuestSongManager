import 'dart:io';

import 'package:bsaberquest/download_manager/gui/browser_page.dart';
import 'package:bsaberquest/download_manager/gui/pending_downloads_widget.dart';
import 'package:bsaberquest/download_manager/gui/song_update_check_widget.dart';
import 'package:bsaberquest/options/windows_protocol_handler_configure.dart';
import 'package:bsaberquest/util/gui_util.dart';
import 'package:bsaberquest/main.dart';
import 'package:bsaberquest/mod_manager/gui/simple_widgets.dart';
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

  void _configureProtocolHandler() async {
    await ProtocolHandlerConfiguration.configure(context);
  }

  Widget _pcDownloadTextInfo() {
    return ListTile(
        title: const Text('OneClick install support'),
        leading: const Icon(Icons.computer),
        subtitle: const Text(
            "Download songs and playlists directly from your web browser using the 'OneClick' protocol (beatsaver:// and bsplaylist://)"),
        trailing: SizedBox(
            width: 150,
            child: IconButton(
                onPressed: _configureProtocolHandler,
                icon: const Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [Icon(Icons.settings), Text("Configure")],
                ))));
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
            App.isQuest ? _questOpenBrowser() : _pcDownloadTextInfo(),
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

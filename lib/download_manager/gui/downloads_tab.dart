import 'dart:io';

import 'package:bsaberquest/download_manager/gui/browser_page.dart';
import 'package:bsaberquest/download_manager/gui/pending_downloads_widget.dart';
import 'package:bsaberquest/main.dart';
import 'package:bsaberquest/mod_manager/gui/playlist_picker_page.dart';
import 'package:bsaberquest/mod_manager/gui/simple_widgets.dart';
import 'package:bsaberquest/mod_manager/model/song.dart';
import 'package:flutter/material.dart';

class DownloadsTabState extends State<DownloadsTab> {
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
    var playList = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const PlaylistPickerPage(),
      ),
    ) as Playlist?;

    App.downloadManager.downloadToPlaylist = playList;

    setState(() {});
  }

  void _clearPlaylist() {
    App.downloadManager.downloadToPlaylist = null;
    setState(() {});
  }

  Widget _playlistSelectWidget(BuildContext context) {
    if (App.downloadManager.downloadToPlaylist == null) {
      return ElevatedButton(
          child: const Text("Enable auto download to playlist"),
          onPressed: () => _pickPlaylist(context));
    } else {
      return Column(
        children: [
          const Text("Downloading to playlist"),
          PlaylistWidget(
              playlist: App.downloadManager.downloadToPlaylist!,
              extraIcon: IconButton(
                icon: const Icon(Icons.close),
                onPressed: _clearPlaylist,
              ))
        ],
      );
    }
  }

  Widget _pcDownloadTextInfo() {
    return const Text(
        "The in-app browser is not supported on PC. Download songs from the browser.");
  }

  Widget _questOpenBrowser() {
    return ElevatedButton(
      onPressed: () => _openBrowser(null),
      child: const Text('Launch browser'),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
          title: const Text('Download manager'),
          actions: [
            IconButton(
                onPressed: App.downloadManager.clearCompleted,
                icon: const Icon(Icons.playlist_remove))
          ],
        ),
        body: Center(
          child: Column(children: [
            _playlistSelectWidget(context),
            const SizedBox(height: 10),
            App.isQuest ? _questOpenBrowser() : _pcDownloadTextInfo(),
            const SizedBox(height: 20),
            Expanded(
                child: PendingDownloadsWidget(
              navigateCallback: _openBrowser,
            ))
          ]),
        ));
  }
}

class DownloadsTab extends StatefulWidget {
  const DownloadsTab({super.key});

  @override
  State<DownloadsTab> createState() => DownloadsTabState();
}

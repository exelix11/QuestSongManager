import 'dart:async';

import 'package:bsaberquest/download_manager/downloader.dart';
import 'package:bsaberquest/main.dart';
import 'package:bsaberquest/mod_manager/gui/playlist_detail_page.dart';
import 'package:bsaberquest/mod_manager/gui/song_detail_page.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

class PendingDownloadsState extends State<PendingDownloadsWidget> {
  late StreamSubscription<DownloadItem?> _downloadItemsSubscription;

  @override
  void initState() {
    _downloadItemsSubscription =
        App.downloadManager.downloadItemsObservable.stream.listen((_) {
      setState(() {});
    });

    super.initState();
  }

  @override
  void dispose() {
    _downloadItemsSubscription.cancel();

    super.dispose();
  }

  void _tappedItem(DownloadItem item) {
    if (item.status == ItemDownloadStatus.pending) {
      return;
    } else if (item.status == ItemDownloadStatus.error) {
      if (widget.navigateCallback != null && item.webSource != null) {
        widget.navigateCallback!(item.webSource!);
      }
    } else if (item.status == ItemDownloadStatus.done &&
        item is SongDownloadItem) {
      var song = App.modManager.songs[item.hash];
      if (song != null) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => SongDetailPage(song: song),
          ),
        );
      }
    } else if (item.status == ItemDownloadStatus.done &&
        item is PlaylistDownloadItem) {
      var playlist = App.modManager.playlists[item.playlistFileName];
      if (playlist != null) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => PlaylistDetailPage(playlist: playlist),
          ),
        );
      }
    }
  }

  Widget _imageForItem(DownloadItem item) {
    if (item.urlIcon != null) {
      return CachedNetworkImage(
        imageUrl: item.urlIcon!,
        placeholder: (context, url) => const Icon(Icons.music_note),
        errorWidget: (context, url, error) => const Icon(Icons.error),
      );
    } else if (item.downloadedIcon != null) {
      return Image.memory(item.downloadedIcon!);
    } else {
      return const Icon(Icons.music_note);
    }
  }

  Widget? _buildEntry(BuildContext context, int index) {
    DownloadItem item = App.downloadManager.items[index];

    var message = "";

    if (item.status == ItemDownloadStatus.pending) {
      message = item.statusMessage;
    } else if (item.status == ItemDownloadStatus.error) {
      message = "Error: ${item.statusMessage}";
      if (item.webSource != null) {
        message += " (tap to open download page)";
      }
    } else if (item.status == ItemDownloadStatus.done) {
      message = "Complete";
    }

    return ListTile(
        leading: _imageForItem(item),
        title: Text(item.name),
        subtitle: item.status == ItemDownloadStatus.pending
            ? Column(children: [Text(message), const LinearProgressIndicator()])
            : Text(message),
        onTap: () => _tappedItem(item));
  }

  void _cancelPendingQueue() {
    App.downloadManager.cancelQueue();
  }

  Widget _buildListView() => ListView.builder(
        shrinkWrap: widget.isPartOfList,
        physics:
            widget.isPartOfList ? const NeverScrollableScrollPhysics() : null,
        itemCount: App.downloadManager.items.length,
        reverse: true,
        itemBuilder: _buildEntry,
      );

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text("Downloads queue"),
            if (App.downloadManager.queuedCount > 0)
              Padding(
                  padding: const EdgeInsets.only(left: 5),
                  child: IconButton(
                      icon: Text(
                          "Cancel ${App.downloadManager.queuedCount} pending items"),
                      onPressed: _cancelPendingQueue))
          ],
        ),
        if (widget.isPartOfList)
          _buildListView()
        else
          Expanded(child: _buildListView()),
      ],
    );
  }
}

class PendingDownloadsWidget extends StatefulWidget {
  const PendingDownloadsWidget(
      {super.key, this.navigateCallback, this.isPartOfList = false});

  final Function(String)? navigateCallback;
  final bool isPartOfList;

  @override
  State<PendingDownloadsWidget> createState() => PendingDownloadsState();
}

class PendingDownloadsStandalonePage extends StatelessWidget {
  const PendingDownloadsStandalonePage({super.key, this.navigateCallback});

  final Function(String)? navigateCallback;

  void _navigate(BuildContext context, String name) {
    if (navigateCallback != null) {
      navigateCallback!(name);
    }

    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Downloads'),
        actions: [
          IconButton(
              onPressed: App.downloadManager.clearCompleted,
              icon: const Icon(Icons.playlist_remove))
        ],
      ),
      body: Center(
        child: PendingDownloadsWidget(
            navigateCallback: (str) => _navigate(context, str)),
      ),
    );
  }
}

import 'dart:async';

import 'package:bsaberquest/download_manager/downloader.dart';
import 'package:bsaberquest/main.dart';
import 'package:bsaberquest/mod_manager/gui/song_detail_page.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

class PendingDownloadsState extends State<PendingDownloadsWidget> {
  late StreamSubscription<DownloadItem> _downloadItemsSubscription;

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
    if (item.status == ItemDownloadStatus.peding) {
      return;
    } else if (item.status == ItemDownloadStatus.error) {
      if (widget.navigateCallback != null && item.webSource != null) {
        widget.navigateCallback!(item.webSource!);
      }
    } else if (item.status == ItemDownloadStatus.done) {
      var song = App.modManager.songs[item.hash];
      if (song != null) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => SongDetailPage(song: song),
          ),
        );
      }
    }
  }

  Widget _buildEntry(BuildContext context, int index) {
    var item = App.downloadManager.downloadItems[index];

    var message = "";

    if (item.status == ItemDownloadStatus.peding) {
      // message not shown
    } else if (item.status == ItemDownloadStatus.error) {
      message = "Error";
      if (item.webSource != null) {
        message += " (tap to open download page)";
      }
    } else if (item.status == ItemDownloadStatus.done) {
      message = "Complete";
    }

    return ListTile(
        leading: CachedNetworkImage(
          imageUrl: item.urlIcon,
          placeholder: (context, url) => const Icon(Icons.music_note),
          errorWidget: (context, url, error) => const Icon(Icons.error),
        ),
        title: Text(item.name),
        subtitle: item.status == ItemDownloadStatus.peding
            ? const LinearProgressIndicator()
            : Text(message),
        onTap: () => _tappedItem(item));
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const Text("Downloads queue:"),
        Expanded(
          child: ListView.builder(
            itemCount: App.downloadManager.downloadItems.length,
            itemBuilder: _buildEntry,
          ),
        ),
      ],
    );
  }
}

class PendingDownloadsWidget extends StatefulWidget {
  const PendingDownloadsWidget({super.key, this.navigateCallback});

  final Function(String)? navigateCallback;

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
      ),
      body: Center(
        child: PendingDownloadsWidget(
            navigateCallback: (str) => _navigate(context, str)),
      ),
    );
  }
}

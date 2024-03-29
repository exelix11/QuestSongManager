import 'package:bsaberquest/download_manager/gui/pending_downloads_widget.dart';
import 'package:bsaberquest/download_manager/gui/util.dart';
import 'package:bsaberquest/gui_util.dart';
import 'package:bsaberquest/main.dart';
import 'package:bsaberquest/preferences.dart';
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';

class BrowserPageViewState extends State<BrowserPageView> {
  late WebViewController controller;

  final RegExp _playlistUrlRegex =
      RegExp(r'^https://api.beatsaver.com/playlists/id/(\d+)/download$');

  List<WebBookmark> bookmarks = [];

  @override
  void initState() {
    controller = WebViewController.fromPlatformCreationParams(
        const PlatformWebViewControllerCreationParams())
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0x00000000))
      ..setNavigationDelegate(
        NavigationDelegate(
          onProgress: (int progress) {
            // Update loading bar.
          },
          onPageStarted: (String url) {},
          onPageFinished: (String url) {},
          onWebResourceError: (WebResourceError error) {},
          onNavigationRequest: (NavigationRequest request) async {
            if (request.url.startsWith('beatsaver://')) {
              _downloadSongById(request.url.split('beatsaver://').last);
              return NavigationDecision.prevent;
            } else if (request.url.startsWith('bsplaylist://playlist/')) {
              _downloadPlaylistByUrl(
                  request.url.split('bsplaylist://playlist/').last);
              return NavigationDecision.prevent;
            } else if (_playlistUrlRegex.hasMatch(request.url)) {
              _downloadPlaylistByUrl(request.url);
              return NavigationDecision.prevent;
            } else if (request.url.endsWith(".zip")) {
              App.showToast(
                  "Download by zip is not currently supported, use the beatsaver:// url");
              return NavigationDecision.prevent;
            }
            return NavigationDecision.navigate;
          },
        ),
      );

    var androidparams = controller.platform as AndroidWebViewController?;
    if (androidparams != null) {
      androidparams.setMediaPlaybackRequiresUserGesture(false);
    }

    PreferencesManager().getWebBookmarks().then((value) {
      setState(() {
        bookmarks = value.bookmarks;
      });

      var startFrom = widget.initialUrl;

      if (startFrom == null || startFrom.isEmpty) {
        startFrom = value.getHomepage()?.url ?? 'https://bsaber.com/';
      }

      _navigateTo(startFrom);
    });

    super.initState();
  }

  // Can't seem to initiate download from the browser callback so we store the state here and handle the next time we redraw
  String? downloadPlaylist;
  String? downloadId;
  String? downloadPageSource;

  void _downloadSongById(String id) async {
    if (downloadId != null) return;
    downloadId = id;
    downloadPageSource = await controller.currentUrl();
    setState(() {});
  }

  void _downloadPlaylistByUrl(String url) async {
    if (downloadPlaylist != null) return;
    downloadPlaylist = url;
    downloadPageSource = await controller.currentUrl();
    setState(() {});
  }

  void _processPendingDownloadRequests(BuildContext context) async {
    if (downloadId != null) {
      DownloadUtil.downloadById(downloadId!, downloadPageSource);
      downloadId = null;
      downloadPageSource = null;
    } else if (downloadPlaylist != null) {
      var url = downloadPlaylist;
      downloadPlaylist = null;

      var defaultName = await controller.getTitle();

      if (!context.mounted) return;

      var name = await GuiUtil.textInputDialog(
          context, "Enter the name of the playlist",
          defaultValue: defaultName);
      if (name == null || name.isEmpty) {
        return;
      }

      DownloadUtil.downloadPlaylist(url!, name, downloadPageSource, true);
    }
  }

  void _navigateTo(String url) {
    controller.loadRequest(Uri.parse(url));
  }

  void _quitPage() {
    Navigator.pop(context);
  }

  void _refreshPage() {
    controller.reload();
  }

  void _openDownloadsView() {
    Navigator.push(
      context,
      MaterialPageRoute(
          builder: (context) => PendingDownloadsStandalonePage(
                navigateCallback: _navigateTo,
              )),
    );
  }

  @override
  Widget build(BuildContext context) {
    _processPendingDownloadRequests(context);
    return Scaffold(
        appBar: AppBar(
          actions: [
            IconButton(
                onPressed: _openDownloadsView,
                icon: const Icon(Icons.download)),
            IconButton(onPressed: _refreshPage, icon: const Icon(Icons.sync)),
            IconButton(onPressed: _quitPage, icon: const Icon(Icons.close)),
          ],
          title: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                  children: bookmarks
                      .map((e) => ElevatedButton(
                            child: Text(e.title),
                            onPressed: () => _navigateTo(e.url),
                          ))
                      .toList())),
        ),
        // ignore: deprecated_member_use
        body: WillPopScope(
          onWillPop: () async {
            final canGoBack = await controller.canGoBack();
            if (canGoBack) {
              controller.goBack();
              return false;
            }
            return true;
          },
          child: WebViewWidget(
            controller: controller,
          ),
        ));
  }
}

class BrowserPageView extends StatefulWidget {
  const BrowserPageView({super.key, this.initialUrl});

  final String? initialUrl;

  @override
  State<BrowserPageView> createState() => BrowserPageViewState();
}

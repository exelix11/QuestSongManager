import 'package:bsaberquest/download_manager/gui/pending_downloads_widget.dart';
import 'package:bsaberquest/download_manager/gui/util.dart';
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';

class BrowserPageViewState extends State<BrowserPageView> {
  late WebViewController controller;

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
              var id = request.url.split('/').last;
              downloadPageSource = await controller.currentUrl();
              setState(() {
                downloadId = id;
              });
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

    _navigateTo(widget.initialUrl ?? 'https://bsaber.com/');

    super.initState();
  }

  String? downloadId;
  String? downloadPageSource;

  void _checkDownloadId(BuildContext context) async {
    if (downloadId != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        DownloadUtil.downloadById(downloadId!, downloadPageSource);
        downloadId = null;
        downloadPageSource = null;
      });
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
    _checkDownloadId(context);
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
            child: Row(children: [
              ElevatedButton(
                child: const Text('bsaber.com'),
                onPressed: () => _navigateTo("https://bsaber.com/"),
              ),
              ElevatedButton(
                child: const Text('beatsaver.com'),
                onPressed: () => _navigateTo("https://beatsaver.com/"),
              ),
            ]),
          ),
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

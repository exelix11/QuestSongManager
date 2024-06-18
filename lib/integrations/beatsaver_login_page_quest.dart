import 'package:bsaberquest/main.dart';
import 'package:bsaberquest/rpc/rpc_manager.dart';
import 'package:bsaberquest/rpc/schema_parser.dart';
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

class BeatSaverLoginPageQuestState extends State<BeatSaverLoginPageQuest> {
  late WebViewController controller;

  Future _finalizeLogin(String code) async {
    try {
      await App.beatSaverClient.finalizeOauthLogin(code);
      App.showToast("Successfully logged in");
    } catch (e) {
      App.showToast(e.toString());
    }
    _quitPage();
  }

  @override
  void initState() {
    super.initState();

    controller = WebViewController.fromPlatformCreationParams(
        const PlatformWebViewControllerCreationParams())
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onNavigationRequest: (NavigationRequest request) async {
            var parse = BsSchemaParser.parse(request.url);
            if (parse != null) {
              if (parse.name == RpcCommandType.beatSaverOauthLogin) {
                _finalizeLogin(parse.args[0]);
                return NavigationDecision.prevent;
              } else {
                App.showToast("Can't handle this command here");
                return NavigationDecision.prevent;
              }
            }
            return NavigationDecision.navigate;
          },
        ),
      );

    _navigateTo(App.beatSaverClient.beginOauthLogin());
  }

  void _quitPage() {
    Navigator.pop(context);
  }

  void _navigateTo(Uri uri) {
    controller.loadRequest(uri);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
          actions: [
            IconButton(onPressed: _quitPage, icon: const Icon(Icons.close)),
          ],
          title: const Text("BeatSaver Login"),
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

class BeatSaverLoginPageQuest extends StatefulWidget {
  const BeatSaverLoginPageQuest({super.key});

  @override
  State<StatefulWidget> createState() => BeatSaverLoginPageQuestState();
}

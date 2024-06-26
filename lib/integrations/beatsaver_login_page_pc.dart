import 'dart:async';
import 'dart:io';

import 'package:bsaberquest/download_manager/beat_saver_api.dart';
import 'package:bsaberquest/main.dart';
import 'package:bsaberquest/mod_manager/platform_helper.dart';
import 'package:bsaberquest/rpc/rpc_manager.dart';
import 'package:flutter/material.dart';

class BeatSaverLoginPagePcState extends State<BeatSaverLoginPagePc> {
  late StreamSubscription<BeatSaverLoginState> _loginStateSubscription;
  late Future _initFuture;

  // For development on linux allow manual input of the auth code
  final bool _debugCodeInput = Platform.isLinux;
  final _debugInputController = TextEditingController();

  bool _loginRequested = false;

  void _leavePage() {
    Navigator.of(context).pop();
  }

  void _onLoginStateChange(BeatSaverLoginState state) {
    if (state.state == LoginState.authenticated) {
      App.showToast(state.toGuiMessage());
      _leavePage();
    } else if (state.error != null) {
      App.showToast(state.error!);
      _leavePage();
    }

    // Othrwise, don't leave yet. Might be a notification about the login state. (eg. logoff before login)
  }

  void _openLoginWebpage() {
    PlatformHelper.openUrl(App.beatSaverClient.beginOauthLogin());
    setState(() {
      _loginRequested = true;
    });
  }

  @override
  void initState() {
    super.initState();

    _initFuture = RpcManager.installOauthLoginHandler();
    _loginStateSubscription = App.beatSaverClient.loginStateObservable.stream
        .listen(_onLoginStateChange);
  }

  @override
  void dispose() {
    // Hope it never fails :)
    RpcManager.removeOauthHandler();

    _loginStateSubscription.cancel();
    super.dispose();
  }

  void _testLoginFromManualInput() {
    App.beatSaverClient.finalizeOauthLogin(_debugInputController.text);
  }

  List<Widget> _buildTestCodeInput() {
    if (!_debugCodeInput) return [];
    return [
      TextField(controller: _debugInputController),
      ElevatedButton(
        onPressed: _testLoginFromManualInput,
        child: const Text('Login with code'),
      )
    ];
  }

  List<Widget> _buildActionButtons() {
    if (_loginRequested) {
      return [
        const SizedBox(
          width: 50,
          height: 50,
          child: CircularProgressIndicator(),
        ),
        const SizedBox(height: 40),
        const Text("Not working ?"),
        IconButton(onPressed: _openLoginWebpage, icon: const Text("Try again")),
        const SizedBox(height: 20),
        ElevatedButton(
          onPressed: _leavePage,
          child: const Text('Cancel'),
        ),
        ..._buildTestCodeInput()
      ];
    } else {
      return [
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          ElevatedButton(
            onPressed: _openLoginWebpage,
            child: const Text('Login with BeatSaver'),
          ),
          const SizedBox(width: 40),
          ElevatedButton(
            onPressed: _leavePage,
            child: const Text('No thanks'),
          )
        ])
      ];
    }
  }

  Widget _buildMainPage() => Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const SizedBox(height: 20),
          Image.asset("assets/BeatSaverIcon.png", width: 100, height: 100),
          const SizedBox(height: 20),
          const Text(
              "By logging in, you can access and synchronize your private playlists."),
          const SizedBox(height: 40),
          const Text(
              "Clicking the button below will redirect you to BeatSaver to authorize this app."),
          const SizedBox(height: 20),
          ..._buildActionButtons()
        ],
      );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
          title: const Text('Login with your BeatSaver account'),
        ),
        body: FutureBuilder(
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.done) {
              if (snapshot.hasError) {
                return Center(child: Text("Error: ${snapshot.error}"));
              }

              return Center(child: _buildMainPage());
            } else {
              return const Center(child: CircularProgressIndicator());
            }
          },
          future: _initFuture,
        ));
  }
}

class BeatSaverLoginPagePc extends StatefulWidget {
  const BeatSaverLoginPagePc({super.key});

  @override
  BeatSaverLoginPagePcState createState() => BeatSaverLoginPagePcState();
}

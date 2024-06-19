import 'dart:async';

import 'package:bsaberquest/download_manager/gui/downloads_tab.dart';
import 'package:bsaberquest/download_manager/gui/util.dart';
import 'package:bsaberquest/download_manager/map_update_controller.dart';
import 'package:bsaberquest/options/options_page.dart';
import 'package:bsaberquest/main.dart';
import 'package:bsaberquest/mod_manager/gui/playlist_list_page.dart';
import 'package:bsaberquest/mod_manager/gui/song_list_page.dart';
import 'package:flutter/material.dart';

import 'rpc/rpc_manager.dart';

class MainPageState extends State<MainPage> {
  StreamSubscription<RpcCommand>? _rpcSubscription;
  late StreamSubscription _updateCheckSubscription;

  @override
  void initState() {
    if (App.rpc != null) {
      _rpcSubscription = App.rpc!.subscribeEvents(_processRpcCommand);
    }

    _updateCheckSubscription =
        App.mapUpdates.stateListener.stream.listen((_) => setState(() {}));

    super.initState();
  }

  @override
  void dispose() {
    _rpcSubscription?.cancel();
    _updateCheckSubscription.cancel();
    super.dispose();
  }

  void _processRpcCommand(RpcCommand cmd) async {
    if (cmd.name == RpcCommandType.getSongById) {
      DownloadUtil.downloadById(cmd.args[0], null);
    } else if (cmd.name == RpcCommandType.getPlaylistByUrl) {
      DownloadUtil.downloadPlaylist(context, cmd.args[0], null);
    } else if (cmd.name == RpcCommandType.beatSaverOauthLogin) {
      App.beatSaverClient.finalizeOauthLogin(cmd.args[0]).onError(
          (error, stackTrace) =>
              {}); // Ignore errors as they are handled by the login page
    }
  }

  Widget _networkIcon() {
    if (App.mapUpdates.state.state != AutoMapUpdateState.updatesAvailable) {
      return const Icon(Icons.wifi);
    }

    // Else render a notification dot
    return Stack(
      children: [
        const Icon(Icons.wifi),
        Positioned(
          right: 0,
          top: 1,
          child: Container(
            padding: const EdgeInsets.all(2),
            decoration:
                const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
            width: 10,
            height: 10,
          ),
        )
      ],
    );
  }

  Widget _buildMainView() {
    return DefaultTabController(
      length: 4,
      child: Scaffold(
        appBar: AppBar(
          title: TabBar(tabs: [
            const Tab(icon: Icon(Icons.music_note)),
            const Tab(icon: Icon(Icons.list)),
            Tab(icon: _networkIcon()),
            const Tab(icon: Icon(Icons.settings)),
          ]),
        ),
        body: const TabBarView(
          children: [
            SongsListPage(),
            PlaylistListPage(),
            DownloadsTab(),
            OptionsPage()
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => _buildMainView();
}

class MainPage extends StatefulWidget {
  const MainPage({super.key});

  @override
  State<MainPage> createState() => MainPageState();
}

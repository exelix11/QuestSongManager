import 'dart:async';
import 'dart:io';

import 'package:bsaberquest/download_manager/beat_saver_api.dart';
import 'package:bsaberquest/download_manager/gui/bookmarks_manager.dart';
import 'package:bsaberquest/download_manager/gui/util.dart';
import 'package:bsaberquest/download_manager/oauth_config.dart';
import 'package:bsaberquest/gui_util.dart';
import 'package:bsaberquest/integrations/beatsaver_integration.dart';
import 'package:bsaberquest/main.dart';
import 'package:bsaberquest/mod_manager/mod_manager.dart';
import 'package:bsaberquest/mod_manager/version_detector.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

import 'game_path_picker_page.dart';
import 'quest_install_location_options.dart';

class OptionsPageState extends State<OptionsPage> {
  final TextEditingController _idController = TextEditingController();
  final TextEditingController _urlController = TextEditingController();
  late StreamSubscription<BeatSaverLoginNotification> _loginStateSubscription;

  bool _showTestOptions = false;
  bool _pathChangedRestart = false;
  bool _showFsRequestButton = true;

  @override
  void initState() {
    super.initState();

    _loginStateSubscription =
        App.beatSaverClient.loginStateObservable.stream.listen((event) {
      setState(() {});
    });
  }

  @override
  void dispose() {
    _loginStateSubscription.cancel();
    super.dispose();
  }

  void _downloadById() async {
    var id = _idController.text;
    if (id.isEmpty) {
      return;
    }

    await DownloadUtil.downloadById(id, null);
  }

  void _downloadPlaylist() async {
    var url = _urlController.text;
    if (url.isEmpty) {
      return;
    }

    await DownloadUtil.downloadPlaylist(context, url, null);
  }

  static Future<bool> requestFileAccess() async {
    if (await Permission.manageExternalStorage.request().isGranted) {
      return true;
    }
    return false;
  }

  List<Widget> _permissionCheckWidget() {
    if (Platform.isAndroid && _showFsRequestButton) {
      return [
        ElevatedButton(
            child: const Text('Request file access permission'),
            onPressed: () async {
              if (await requestFileAccess()) {
                App.showToast("Permission granted");
                _reloadSongs();
                setState(() {
                  _showFsRequestButton = false;
                });
              } else {
                App.showToast("Permission denied");
              }
            }),
        const SizedBox(height: 20),
      ];
    }

    return [];
  }

  Future<int> _doRehashAllSongs() async {
    // First reload in case of changes
    await App.modManager.reloadFromDisk();
    // Then rehash all songs
    int fixed = 0;
    for (var song in App.modManager.songs.values) {
      if (!await App.modManager.checkSongHash(song)) {
        fixed++;
      }
    }

    return fixed;
  }

  void _rehashAllSongs() async {
    if (!App.modManager.useFastHashCache) {
      App.showToast(
          "Hash cache is disabled, rehashing all songs is not possible");
      return;
    }

    var future = _doRehashAllSongs();
    var res = await GuiUtil.loadingDialog(
        context, "Recalculating the hash of all the songs...", future);

    if (res != null) {
      var num = await res;
      if (num == 0) {
        App.showToast("All songs hashes were correct");
      } else {
        App.showToast("$num songs hashes were invalid and have been corrected");
      }
    }
  }

  Widget _hashCacheOptions() {
    var using = App.modManager.useFastHashCache;

    Widget button;

    if (using) {
      button = ElevatedButton(
        onPressed: () async {
          await App.modManager.removeCachedHashes();
          App.modManager.useFastHashCache = false;
          App.preferences.useHashCache = false;
          App.showToast("Hash cache has been disabled");
          setState(() {});
        },
        child: const Text("Disable hash cache"),
      );
    } else {
      button = ElevatedButton(
        onPressed: () {
          App.preferences.useHashCache = true;
          App.showToast("Restart the app to apply changes");
          setState(() {});
        },
        child: const Text("Enable hash cache"),
      );
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(using ? "Using fast hash cache" : "hash cache has been disabled"),
        const SizedBox(width: 10),
        button,
        const SizedBox(width: 10),
        ElevatedButton(
          onPressed: () => _rehashAllSongs(),
          child: const Text("Check all song hashes"),
        ),
      ],
    );
  }

  void _removeFromPlaylistOnSongDeleteChange(bool? value) {
    setState(() {
      App.preferences.removeFromPlaylistOnSongDelete = value ?? false;
    });
  }

  List<Widget> _utilOptions() => [
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          ElevatedButton(
              onPressed: _reloadSongs,
              child: const Text("Reload songs and playlists")),
          const SizedBox(width: 10),
          if (App.isQuest)
            ElevatedButton(
                onPressed: _openBookmarksManager,
                child: const Text("Manage browser bookmarks"))
        ]),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Checkbox(
                value: App.preferences.removeFromPlaylistOnSongDelete,
                onChanged: _removeFromPlaylistOnSongDeleteChange),
            const Text("When deleting a song, remove it from all playlists")
          ],
        )
      ];

  void _openInstallLocationOptions() async {
    if (!App.isQuest) throw Exception("This should not be called on PC");

    // Initialize version cache in case it was not done yet
    await BeatSaberVersionDetector.getBeatSaberVersion();

    var pref = App.preferences.preferredCustomSongFolder;

    if (mounted) {
      await Navigator.of(context).push(
          MaterialPageRoute(builder: (context) => InstallLocationPage(pref)));

      setState(() {});
    }
  }

  Widget _questInstallLocationOptions() {
    return Row(mainAxisAlignment: MainAxisAlignment.center, children: [
      (App.modManager.paths as QuestPaths).preferredInstallLocation ==
              CustomLevelLocation.songCore
          ? const Text("Songs will be installed to the new 'SongCore' folder")
          : const Text(
              "Songs will be installed to the legacy 'SongLoader' folder"),
      const SizedBox(width: 10),
      ElevatedButton(
          onPressed: _openInstallLocationOptions, child: const Text("Change"))
    ]);
  }

  void _openGamePathPicker() async {
    var path = App.preferences.gameRootPath;

    await Navigator.of(context).push(MaterialPageRoute(
        builder: (context) => const GamePathPickerPage(true)));

    var newPath = App.preferences.gameRootPath;
    if (path != newPath) {
      setState(() {
        _pathChangedRestart = true;
      });
    }
  }

  Widget _pcInstallLocationOptions() {
    return Column(children: [
      Text("Current game location: ${App.modManager.gameRoot}"),
      ElevatedButton(
          onPressed: _openGamePathPicker, child: const Text("Change")),
      _pathChangedRestart
          ? const Text(
              "The path has been changed, restart the app to use the new path.")
          : const SizedBox(
              width: 1,
              height: 1,
            )
    ]);
  }

  Widget _installLocationOptions() {
    if (App.isQuest) {
      return _questInstallLocationOptions();
    } else {
      return _pcInstallLocationOptions();
    }
  }

  void _reloadSongs() async {
    try {
      await App.modManager.reloadFromDisk();
      App.showToast("Songs reloaded");
    } catch (e) {
      App.showToast("Reloading songs failed: $e");
    }
  }

  void _openBookmarksManager() {
    Navigator.of(context).push(
        MaterialPageRoute(builder: (context) => const BookmarksManager()));
  }

  Widget _downloadByIdTest() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Text("Download by ID"),
        const SizedBox(width: 10),
        SizedBox(
          width: 100,
          child: TextField(
            controller: _idController,
          ),
        ),
        const SizedBox(width: 10),
        ElevatedButton(
          onPressed: _downloadById,
          child: const Text("Download"),
        )
      ],
    );
  }

  Widget _downloadPlaylistByUrlTest() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Text("Download playlist by url"),
        const SizedBox(width: 10),
        SizedBox(
          width: 100,
          child: TextField(
            controller: _urlController,
          ),
        ),
        const SizedBox(width: 10),
        ElevatedButton(
          onPressed: _downloadPlaylist,
          child: const Text("Download"),
        )
      ],
    );
  }

  Widget _credits() {
    return Column(children: [
      const Text("Quest Song Manager, by exelix11"),
      const Text("Release ${App.versionName}"),
      const Text("https://github.com/exelix11/QuestSongManager"),
      if (!App.isQuest) const Text("(PC Version, rename pending.)"),
    ]);
  }

  void _setShowTestOptions(bool value) {
    setState(() {
      _showTestOptions = value;
    });
  }

  Widget _buildTestOptions() {
    if (!_showTestOptions) {
      return IconButton(
          onPressed: () => _setShowTestOptions(true),
          icon: const Text("Show advanced options"));
    } else {
      return Column(
        children: [
          IconButton(
              onPressed: () => _setShowTestOptions(false),
              icon: const Text("Advanced/Test options")),
          const SizedBox(height: 20),
          _hashCacheOptions(),
          const SizedBox(height: 20),
          _downloadByIdTest(),
          _downloadPlaylistByUrlTest(),
          const SizedBox(height: 20),
        ],
      );
    }
  }

  List<Widget> _beatSaverIntegration() {
    // Only official builds include the secrets needed for this
    if (!BeatSaverOauthConfig.isConfigured) return [];

    var user = App.beatSaverClient.userInfo;

    var tile = user == null
        ? ListTile(
            leading: Image.asset("assets/BeatSaverIcon.png"),
            title: const Text('Login with BeatSaver'),
            onTap: () async {
              await BeatSaverIntegration.beginLoginFlow(context);
              setState(() {});
            },
          )
        : ListTile(
            leading: user.avatar == null
                ? const Icon(Icons.account_circle)
                : Image.network(user.avatar!),
            title: Text('Logged in as ${user.username}'),
            subtitle: const Text("BeatSaver account"),
            trailing: IconButton(
              icon: const Icon(Icons.logout),
              onPressed: () => {
                setState(() {
                  App.beatSaverClient.logout();
                })
              },
            ),
          );

    return [
      Container(
          alignment: Alignment.center,
          padding: const EdgeInsets.only(left: 40, right: 40),
          child: tile),
      const SizedBox(height: 20)
    ];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Options'),
      ),
      body: SingleChildScrollView(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ..._permissionCheckWidget(),
            ..._beatSaverIntegration(),
            ..._utilOptions(),
            const SizedBox(height: 20),
            _installLocationOptions(),
            const SizedBox(height: 20),
            _buildTestOptions(),
            const SizedBox(height: 20),
            _credits(),
          ],
        ),
      ),
    );
  }
}

class OptionsPage extends StatefulWidget {
  const OptionsPage({super.key});

  @override
  OptionsPageState createState() => OptionsPageState();
}

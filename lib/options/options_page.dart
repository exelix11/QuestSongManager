import 'dart:async';
import 'dart:io';

import 'package:bsaberquest/download_manager/beat_saver_api.dart';
import 'package:bsaberquest/download_manager/gui/bookmarks_manager.dart';
import 'package:bsaberquest/download_manager/oauth_config.dart';
import 'package:bsaberquest/util/gui_util.dart';
import 'package:bsaberquest/integrations/beatsaver_integration.dart';
import 'package:bsaberquest/main.dart';
import 'package:bsaberquest/mod_manager/mod_manager.dart';
import 'package:bsaberquest/mod_manager/version_detector.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

import 'game_path_picker_page.dart';
import 'quest_install_location_options.dart';

class OptionsPageState extends State<OptionsPage> {
  late StreamSubscription<BeatSaverLoginState> _loginStateSubscription;

  bool _showAdvancedOptions = false;
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

  static Future<bool> requestFileAccess() async {
    if (await Permission.manageExternalStorage.request().isGranted) {
      return true;
    }
    return false;
  }

  List<Widget> _permissionCheckWidget() {
    if (Platform.isAndroid && _showFsRequestButton) {
      return [
        ListTile(
            title: const Text("Request file access"),
            leading: const Icon(Icons.settings),
            subtitle: const Text(
                "Try this option if the app can't access your songs"),
            onTap: () async {
              if (await requestFileAccess()) {
                App.showToast("Permission granted");
                _reloadSongs();
                setState(() {
                  _showFsRequestButton = false;
                });
              } else {
                App.showToast("Permission denied");
              }
            })
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

  void _removeFromPlaylistOnSongDeleteChange(bool? value) {
    setState(() {
      App.preferences.removeFromPlaylistOnSongDelete = value ?? false;
    });
  }

  void _autoUpdateMapsChange(bool? value) {
    setState(() {
      App.preferences.autoUpdateMaps = value ?? false;
    });
  }

  void _darkThemeChange(BuildContext context, bool? value) {
    value ??= false;
    App.changeTheme(context, value ? ThemeMode.dark : ThemeMode.light);
    setState(() {
      App.preferences.darkTheme = value!;
    });
  }

  List<Widget> _utilOptions(BuildContext context) => [
        ListTile(
          leading: const Icon(Icons.refresh),
          title: const Text("Reload songs and playlists"),
          onTap: _reloadSongs,
        ),
        if (App.isQuest)
          ListTile(
            leading: const Icon(Icons.star),
            title: const Text("Manage browser bookmarks"),
            onTap: _openBookmarksManager,
          ),
        CheckboxListTile(
          title: const Text("Dark theme"),
          value: App.preferences.darkTheme,
          onChanged: (value) => _darkThemeChange(context, value),
        ),
        CheckboxListTile(
          value: App.preferences.removeFromPlaylistOnSongDelete,
          onChanged: _removeFromPlaylistOnSongDeleteChange,
          title:
              const Text("When deleting a song, remove it from all playlists"),
        ),
        CheckboxListTile(
          value: App.preferences.autoUpdateMaps,
          onChanged: _autoUpdateMapsChange,
          title: const Text("Automatically check for map updates"),
        )
      ];

  void _openInstallLocationOptions() async {
    if (!App.isQuest) throw Exception("This should not be called on PC");

    var pref = App.preferences.preferredCustomSongFolder;

    if (mounted) {
      await Navigator.of(context).push(
          MaterialPageRoute(builder: (context) => InstallLocationPage(pref)));

      setState(() {});
    }
  }

  Widget _questInstallLocationOptions() {
    var text = (App.modManager.paths as QuestPaths).preferredInstallLocation ==
            CustomLevelLocation.songCore
        ? "Songs will be installed to the new 'SongCore' folder"
        : "Songs will be installed to the legacy 'SongLoader' folder";

    return ListTile(
      title: const Text("Custom maps install location"),
      subtitle: Text("$text\nTap to change"),
      leading: const Icon(Icons.folder),
      onTap: _openInstallLocationOptions,
    );
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
    if (_pathChangedRestart) {
      return const ListTile(
        title: Text("The game install location has been changed"),
        subtitle: Text("Restart the app to apply the changes"),
        leading: Icon(Icons.warning),
      );
    }

    return ListTile(
      title: const Text("Game install location"),
      subtitle: Text("${App.modManager.gameRoot}\nClick to change"),
      leading: const Icon(Icons.folder),
      onTap: _openGamePathPicker,
    );
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

  Widget _credits() {
    return Column(children: [
      const Text("Quest Song Manager, by exelix11"),
      const Text("Release ${App.versionName}"),
      const Text("https://github.com/exelix11/QuestSongManager"),
      if (!App.isQuest) const Text("(PC Version, rename pending.)"),
    ]);
  }

  List<Widget> _buildAdvancedOptions() {
    if (!_showAdvancedOptions) {
      return [
        ListTile(
          title: const Text("Show advanced options"),
          subtitle: const Text("Usually these are not needed"),
          leading: const Icon(Icons.warning_sharp),
          onTap: () {
            setState(() {
              _showAdvancedOptions = true;
            });
          },
        )
      ];
    }

    var usingCache = App.modManager.useFastHashCache;

    return [
      ListTile(
        title: const Text("Hide advanced options"),
        leading: const Icon(Icons.hide_source),
        onTap: () {
          setState(() {
            _showAdvancedOptions = false;
          });
        },
      ),
      ListTile(
        title: const Text("Rehash all songs"),
        subtitle: const Text(
            "This will recalculate the hash of all the songs. This is useful if you have modified the songs files. It may take some time"),
        onTap: _rehashAllSongs,
      ),
      if (usingCache)
        ListTile(
          title: const Text("Disable hash cache"),
          subtitle: const Text(
              "This will disable the map hash cache and make the app much slower. The cache files will be deleted. This option is NOT recommended."),
          leading: const Icon(Icons.warning_amber),
          onTap: () async {
            await App.modManager.removeCachedHashes();
            App.modManager.useFastHashCache = false;
            App.preferences.useHashCache = false;
            App.showToast("Hash cache has been disabled");
            setState(() {});
          },
        ),
      if (!usingCache)
        ListTile(
          title: const Text("Enable hash cache"),
          subtitle: const Text("The app will load faster (default mode)"),
          onTap: () async {
            App.preferences.useHashCache = true;
            App.showToast("Restart the app to apply changes");
            setState(() {});
          },
        ),
    ];
  }

  List<Widget> _beatSaverIntegration() {
    // Only official builds include the secrets needed for this
    if (!BeatSaverOauthConfig.isConfigured) return [];

    var user = App.beatSaverClient.userState;

    if (user.state == LoginState.notLoggedIn) {
      return [
        InkWell(
            onTap: () async {
              await BeatSaverIntegration.beginLoginFlow(context);
              setState(() {});
            },
            child: Center(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Image.asset("assets/BeatSaverIcon.png",
                      width: 60, height: 60),
                  const SizedBox(width: 20),
                  const Column(children: [
                    Text("Login with BeatSaver"),
                    Text(
                        "Use your account to download and sync private playlists",
                        style: TextStyle(fontSize: 12))
                  ])
                ],
              ),
            ))
      ];
    } else if (user.state == LoginState.authenticated) {
      return [
        ListTile(
          leading: user.avatar == null
              ? const Icon(Icons.account_circle)
              : Image.network(user.avatar!),
          title: Text(user.username!),
          subtitle: const Text("Current BeatSaver account"),
          trailing: IconButton(
            tooltip: "Logout",
            icon: const Icon(Icons.logout),
            onPressed: () => {
              setState(() {
                App.beatSaverClient.logout();
              })
            },
          ),
        )
      ];
    } else {
      return [
        ListTile(
          leading: const Icon(Icons.device_unknown),
          title: const Text("You are offline"),
          subtitle: const Text(
              "Failed to retrieve user data from BeatSaver.\nTap to try again."),
          onTap: () => App.beatSaverClient.tryLoginFromStoredCredentials(),
          trailing: IconButton(
            tooltip: "Logout",
            icon: const Icon(Icons.logout),
            onPressed: () => {
              setState(() {
                App.beatSaverClient.logout();
              })
            },
          ),
        )
      ];
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Options'),
      ),
      body: ListView(
        padding: GuiUtil.defaultViewPadding(context),
        children: [
          _credits(),
          const Divider(),
          ..._beatSaverIntegration(),
          const Divider(),
          ..._permissionCheckWidget(),
          ..._utilOptions(context),
          _installLocationOptions(),
          const Divider(),
          ..._buildAdvancedOptions(),
        ],
      ),
    );
  }
}

class OptionsPage extends StatefulWidget {
  const OptionsPage({super.key});

  @override
  OptionsPageState createState() => OptionsPageState();
}

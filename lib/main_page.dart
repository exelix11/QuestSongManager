import 'package:bsaberquest/download_manager/gui/downloads_tab.dart';
import 'package:bsaberquest/options_page.dart';
import 'package:bsaberquest/main.dart';
import 'package:bsaberquest/mod_manager/gui/playlist_list_page.dart';
import 'package:bsaberquest/mod_manager/gui/song_list_page.dart';
import 'package:flutter/material.dart';

class MainPageState extends State<MainPage> {
  late Future _init;
  String _hintText = "";

  @override
  void initState() {
    _init = _initialize();
    super.initState();
  }

  Future _initialize() async {
    var opt = await App.preferences.useHashCache();
    App.modManager.useFastHashCache = opt;

    // Redraw the UI to update in case loading opt was slow
    setState(() {
      _hintText = App.modManager.useFastHashCache
          ? "During the first start the app caches all the song hashses, future starts will be faster"
          : "Consider enabling hash caches to speed up the app start up times";
    });

    try {
      await App.modManager.reloadIfNeeded();
    } catch (e) {
      App.showToast(
          "Error during initialization: $e\nTry enabling permissions in the settings page");
    }
  }

  Widget _buildLoader() {
    return Scaffold(
      appBar: AppBar(title: const Text('Bsaber Quest')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('Loading song list...', style: TextStyle(fontSize: 20)),
            const SizedBox(height: 20),
            const SizedBox(
                height: 100, width: 100, child: CircularProgressIndicator()),
            const SizedBox(height: 50),
            Text(_hintText),
          ],
        ),
      ),
    );
  }

  Widget _buildMainView() {
    return DefaultTabController(
      length: 4,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Bsaber Quest'),
          bottom: const TabBar(
            tabs: [
              Tab(icon: Icon(Icons.music_note)),
              Tab(icon: Icon(Icons.list)),
              Tab(icon: Icon(Icons.wifi)),
              Tab(icon: Icon(Icons.settings)),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            SongListPage(),
            PlaylistListPage(),
            DownloadsTab(),
            OptionsPage()
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
        future: _init,
        builder: (ctx, state) {
          if (state.connectionState == ConnectionState.done) {
            return _buildMainView();
          } else {
            return _buildLoader();
          }
        });
  }
}

class MainPage extends StatefulWidget {
  const MainPage({super.key});

  @override
  State<MainPage> createState() => MainPageState();
}

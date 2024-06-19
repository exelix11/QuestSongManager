import 'dart:async';

import 'package:bsaberquest/download_manager/gui/song_update_page.dart';
import 'package:bsaberquest/download_manager/map_update_controller.dart';
import 'package:bsaberquest/main.dart';
import 'package:flutter/material.dart';

class MapUpdateCheckWidgetState extends State<MapUpdateCheckWidget> {
  late StreamSubscription _stateListener;

  @override
  void initState() {
    super.initState();
    _stateListener = App.mapUpdates.stateListener.stream.listen((event) {
      setState(() {});
    });
  }

  @override
  void dispose() {
    _stateListener.cancel();
    super.dispose();
  }

  void _checkAgain() {
    App.mapUpdates.checkForUpdates();
  }

  void _clearUpdates() {
    App.mapUpdates.clearPendingState();
  }

  void _openUpdatePage() async {
    await Navigator.of(context).push(MaterialPageRoute(
        builder: (context) => SongUpdateListPage(
              updates: List.from(App.mapUpdates.pendingUpdates),
            )));

    App.mapUpdates.clearPendingState();
  }

  Widget _buildLoader() => const ListTile(
        title: Text("Checking for map updates..."),
        trailing: CircularProgressIndicator(),
      );

  String _noUpdateState() {
    if (App.mapUpdates.state.error != null) {
      return "Error while checking for updates";
    } else if (App.mapUpdates.checkedOnce) {
      return "No map updates found";
    } else {
      return "Tap to check for map updates";
    }
  }

  Widget _buildNoUpdate() => ListTile(
        title: Text(_noUpdateState()),
        subtitle: App.mapUpdates.state.error != null
            ? Text(App.mapUpdates.state.error!)
            : null,
        leading: const Icon(Icons.refresh),
        onTap: _checkAgain,
      );

  String _updatePendingMapCount() {
    var count = App.mapUpdates.pendingUpdates.length;
    if (count == 0) {
      return "No map updates available";
    } else if (count == 1) {
      return "1 map can be updated";
    } else {
      return "$count maps can be updated";
    }
  }

  Widget _buildUpdateAvailable() => ListTile(
        title: Text(_updatePendingMapCount()),
        subtitle: const Text("Tap to see details"),
        leading: const Icon(Icons.download),
        onTap: _openUpdatePage,
        trailing: IconButton(
          icon: const Icon(Icons.close),
          onPressed: _clearUpdates,
        ),
      );

  @override
  Widget build(BuildContext context) {
    if (App.mapUpdates.state.state == AutoMapUpdateState.checking) {
      return _buildLoader();
    } else if (App.mapUpdates.state.state == AutoMapUpdateState.none) {
      return _buildNoUpdate();
    } else if (App.mapUpdates.state.state ==
        AutoMapUpdateState.updatesAvailable) {
      return _buildUpdateAvailable();
    } else {
      return const SizedBox();
    }
  }
}

class MapUpdateCheckWidget extends StatefulWidget {
  const MapUpdateCheckWidget({super.key});

  @override
  State<MapUpdateCheckWidget> createState() => MapUpdateCheckWidgetState();
}

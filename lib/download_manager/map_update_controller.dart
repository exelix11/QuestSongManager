import 'dart:async';
import 'dart:io';

import 'package:bsaberquest/download_manager/beat_saver_api.dart';
import 'package:bsaberquest/main.dart';

class MapUpdateController {
  final StreamController<AutoUpdateResult> stateListener =
      StreamController.broadcast();

  AutoUpdateResult state = AutoUpdateResult(AutoMapUpdateState.none);
  List<BeatSaverMapInfo> pendingUpdates = [];
  bool checkedOnce = false;

  void _setCheckingState() {
    state = AutoUpdateResult(AutoMapUpdateState.checking);
    pendingUpdates = [];
    stateListener.add(state);
  }

  void clearPendingState() {
    checkedOnce = false;
    pendingUpdates = [];
    state = AutoUpdateResult(AutoMapUpdateState.none);
    stateListener.add(state);
  }

  // This is async and will notify any listeners when done
  void checkForUpdates() async {
    if (state.state == AutoMapUpdateState.checking) {
      return;
    }

    _setCheckingState();

    try {
      var maps = await App.beatSaverClient
          .getMapsByHashes(App.modManager.songs.keys.toList());

      var updates = maps
          .where((element) =>
              element.versions.isNotEmpty &&
              element.requestHash != element.versions.first.hash)
          .toList();

      pendingUpdates = updates;

      checkedOnce = true;
      state = AutoUpdateResult(updates.isNotEmpty
          ? AutoMapUpdateState.updatesAvailable
          : AutoMapUpdateState.none);

      stateListener.add(state);
    } on SocketException catch (_) {
      // Socket exceptions may print the full url, so we'll just show a shorter error
      state =
          AutoUpdateResult(AutoMapUpdateState.none, error: "Connection error");
      stateListener.add(state);
    } catch (e) {
      state = AutoUpdateResult(AutoMapUpdateState.none, error: e.toString());
      stateListener.add(state);
    }
  }

  void doAutoUpdateCheckIfNeeded() {
    if (!App.preferences.autoUpdateMaps) {
      return;
    }

    // Do not check more often than once a day
    var lastCheck = App.preferences.lastMapUpdateCheck;
    if (DateTime.now().difference(lastCheck).inDays < 1) {
      // Pretend we checked
      checkedOnce = true;
      return;
    }

    checkForUpdates();
  }
}

enum AutoMapUpdateState { none, checking, updatesAvailable }

class AutoUpdateResult {
  final AutoMapUpdateState state;
  final String? error;

  AutoUpdateResult(this.state, {this.error});
}

import 'package:bsaberquest/util/gui_util.dart';
import 'package:bsaberquest/main.dart';
import 'package:bsaberquest/mod_manager/gui/simple_widgets.dart';
import 'package:bsaberquest/mod_manager/model/playlist.dart';
import 'package:flutter/material.dart';

class PlaylistSyncPageState extends State<PlaylistSyncPage> {
  List<PlayListSong> get _onlyFrom => widget.state._onlyFrom;
  List<PlayListSong> get _onlyTo => widget.state._onlyTo;

  List<bool> get _fromChecked => widget.state._fromChecked;
  List<bool> get _toChecked => widget.state._toChecked;

  Widget _songTile(int index, List<PlayListSong> from, List<bool> checks) {
    var song = from[index];

    var knownSong = App.modManager.songs[song.hash];
    var icon = SongWidget.iconForSong(knownSong);

    var name = knownSong?.meta.songName ?? song.songName;

    return CheckboxListTile(
      title: Row(
        children: [
          SizedBox(width: 26, height: 26, child: icon),
          const SizedBox(width: 10),
          Flexible(child: Text(name)),
        ],
      ),
      value: checks[index],
      onChanged: (bool? value) {
        setState(() {
          checks[index] = value ?? false;
        });
      },
      // places the checkbox at the start (leading)
      controlAffinity: ListTileControlAffinity.leading,
    );
  }

  void _apply() {
    Navigator.of(context).pop(true);
  }

  void _cancel() {
    Navigator.of(context).pop(false);
  }

  void _selectBatch(bool from, bool to) {
    for (var i = 0; i < _fromChecked.length; i++) {
      _fromChecked[i] = from;
    }
    for (var i = 0; i < _toChecked.length; i++) {
      _toChecked[i] = to;
    }
    setState(() {});
  }

  void _selectOnlyFrom() {
    _selectBatch(true, false);
  }

  void _selectOnlyTo() {
    _selectBatch(false, true);
  }

  void _selectAll() {
    _selectBatch(true, true);
  }

  void _selectNone() {
    _selectBatch(false, false);
  }

  Widget _popupMenu() {
    return PopupMenuButton<Function()>(
        onSelected: (value) => value(),
        itemBuilder: (ctx) => [
              PopupMenuItem(
                  value: _selectOnlyFrom,
                  child: Text("Only songs from ${widget.fromName}")),
              PopupMenuItem(
                  value: _selectOnlyTo,
                  child: Text("Only songs from ${widget.toName}")),
              PopupMenuItem(value: _selectAll, child: const Text("Select all")),
              PopupMenuItem(
                  value: _selectNone, child: const Text("Select none")),
            ]);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
          title: const Text("Compare playlists"),
          actions: [
            IconButton(onPressed: _cancel, icon: const Icon(Icons.close)),
            IconButton(onPressed: _apply, icon: const Icon(Icons.check)),
            _popupMenu()
          ],
        ),
        body: ListView(padding: GuiUtil.defaultViewPadding(context), children: [
          const ListTile(
            title: Text("The two playlists can't be merged automatically"),
            subtitle: Text(
                "The following songs are only in one of the playlists, select the ones you want to keep and confirm"),
          ),
          const Divider(),
          ListTile(
            title: Text("Only in ${widget.fromName}"),
          ),
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _onlyFrom.length,
            itemBuilder: (context, index) {
              return _songTile(index, _onlyFrom, _fromChecked);
            },
          ),
          const Divider(),
          ListTile(
            title: Text("Only in ${widget.toName}"),
          ),
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _onlyTo.length,
            itemBuilder: (context, index) {
              return _songTile(index, _onlyTo, _toChecked);
            },
          ),
        ]));
  }
}

// ignore: must_be_immutable
class PlaylistSyncPage extends StatefulWidget {
  final String fromName;
  final String toName;

  final PlaylistSyncState state;

  const PlaylistSyncPage(
      {super.key,
      required this.fromName,
      required this.toName,
      required this.state});

  @override
  State<StatefulWidget> createState() => PlaylistSyncPageState();
}

class PlaylistSyncState {
  final Playlist playlistFrom;
  final Playlist playlistTo;

  final List<PlayListSong> _onlyFrom;
  final List<PlayListSong> _onlyTo;

  late List<bool> _fromChecked;
  late List<bool> _toChecked;

  PlaylistSyncState(this.playlistFrom, this.playlistTo)
      : _onlyFrom = playlistFrom.songs
            .where((song) =>
                !playlistTo.songs.any((element) => element.hash == song.hash))
            .toList(),
        _onlyTo = playlistTo.songs
            .where((song) =>
                !playlistFrom.songs.any((element) => element.hash == song.hash))
            .toList() {
    _fromChecked = List.filled(_onlyFrom.length, true);
    _toChecked = List.filled(_onlyTo.length, false);
  }

  bool get fromEmpty => _onlyFrom.isEmpty;
  bool get toEmpty => _onlyTo.isEmpty;
}

class PlaylistSyncHelper {
  // Simple case: only more songs in from, meaning that to is only receiving
  static bool isSimpleAdditiveMerge(PlaylistSyncState state) =>
      !state.fromEmpty && state.toEmpty;

  // Simple case: both playlists are the same
  static bool isNoChanges(PlaylistSyncState state) =>
      state.fromEmpty && state.toEmpty;

  static bool isSimpleMerge(PlaylistSyncState state) =>
      isNoChanges(state) || isSimpleAdditiveMerge(state);

  static void performSimpleMerge(PlaylistSyncState state) {
    if (isNoChanges(state)) {
      return;
    }

    if (isSimpleAdditiveMerge(state)) {
      performSimpleAdditiveMerge(state);
      return;
    }

    throw Exception("Not a simple merge");
  }

  static void performSimpleAdditiveMerge(PlaylistSyncState state) {
    if (!isSimpleAdditiveMerge(state)) {
      throw Exception("Not a simple merge");
    }

    for (var song in state._onlyFrom) {
      state.playlistTo.songs.add(song);
    }
  }

  static void performCustomMerge(PlaylistSyncState state) {
    // Remove the songs in onlyTo that were excluded
    for (var i = 0; i < state._onlyTo.length; i++) {
      if (!state._toChecked[i]) {
        state.playlistTo.songs.remove(state._onlyTo[i]);
      }
    }

    // Add the songs from onlyFrom that were included
    for (var i = 0; i < state._onlyFrom.length; i++) {
      if (state._fromChecked[i]) {
        state.playlistTo.songs.add(state._onlyFrom[i]);
      }
    }
  }
}

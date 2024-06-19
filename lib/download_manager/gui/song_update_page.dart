import 'package:bsaberquest/download_manager/beat_saver_api.dart';
import 'package:bsaberquest/util/gui_util.dart';
import 'package:bsaberquest/main.dart';
import 'package:flutter/material.dart';

class SongUpdateListPageState extends State<SongUpdateListPage> {
  final List<bool> _selected;

  SongUpdateListPageState(int itemCount)
      : _selected = List.filled(itemCount, true);

  void _downloadSelected() {
    for (var i = 0; i < widget.updates.length; i++) {
      if (_selected[i]) {
        // Song updates are also added to the default playlist so the user can see them
        App.downloadManager.downloadMapByMetadata(
            widget.updates[i], null, App.downloadManager.downloadToPlaylist);
      }
    }

    App.showToast("Downloads queued");
    Navigator.pop(context);
  }

  void _updateSelection(bool select) {
    setState(() {
      for (var i = 0; i < _selected.length; i++) {
        _selected[i] = select;
      }
    });
  }

  Widget _songIcon(BeatSaverMapInfo song) {
    if (song.versions.first.coverUrl == null) {
      return const Icon(Icons.music_note);
    }

    return Image.network(song.versions.first.coverUrl!);
  }

  Widget _buildSongTile(int index, BeatSaverMapInfo song) => CheckboxListTile(
      title: Row(
        children: [
          SizedBox(width: 26, height: 26, child: _songIcon(song)),
          const SizedBox(width: 10),
          Flexible(child: Text(song.name)),
        ],
      ),
      value: _selected[index],
      onChanged: (value) => {
            setState(() {
              _selected[index] = value ?? false;
            })
          });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
          title: const Text("Update songs"),
          actions: [
            IconButton(
                onPressed: _downloadSelected, icon: const Icon(Icons.download)),
            PopupMenuButton(
                itemBuilder: (context) => [
                      PopupMenuItem(
                          child: const Text("Select all"),
                          onTap: () => _updateSelection(true)),
                      PopupMenuItem(
                          child: const Text("Select none"),
                          onTap: () => _updateSelection(false))
                    ])
          ],
        ),
        body: ListView.builder(
            padding: GuiUtil.defaultViewPadding(context),
            itemCount: widget.updates.length,
            itemBuilder: (context, index) =>
                _buildSongTile(index, widget.updates[index])));
  }
}

class SongUpdateListPage extends StatefulWidget {
  final List<BeatSaverMapInfo> updates;

  const SongUpdateListPage({super.key, required this.updates});

  @override
  State<StatefulWidget> createState() {
    // ignore: no_logic_in_create_state
    return SongUpdateListPageState(updates.length);
  }
}

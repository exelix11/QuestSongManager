import 'dart:async';

import 'package:bsaberquest/mod_manager/gui/playlist_list_widget.dart';
import 'package:bsaberquest/util/gui_util.dart';
import 'package:bsaberquest/main.dart';
import 'package:bsaberquest/mod_manager/gui/playlist_detail_page.dart';
import 'package:bsaberquest/mod_manager/gui/songs_in_no_playlist_page.dart';
import 'package:flutter/material.dart';

import '../model/playlist.dart';

class PlaylistListPageState extends State<PlaylistListPage> {
  late PlaylistListWidgetController renderer;

  late StreamSubscription _playlistSubscription;
  late StreamSubscription _songListSubscription;
  bool showPlaylistErrorList = false;
  bool showPlaylistIconFormatWarning = false;
  bool ignorePlaylistIconFormatWarning = false;

  void _checkUiConditionState() {
    if (ignorePlaylistIconFormatWarning) {
      showPlaylistIconFormatWarning = false;
      return;
    }

    showPlaylistIconFormatWarning =
        App.modManager.playlists.values.any((x) => x.imageCompatibilityIssue);

    showPlaylistErrorList = App.modManager.errorPlaylists.isNotEmpty;

    renderer.list.setItems(App.modManager.playlists);
  }

  @override
  void initState() {
    renderer = PlaylistListWidgetController(
        App.modManager.playlists, _onPlaylistTap,
        deleteHandler: _onPlaylistDelete, dotsMenu: _buildDotsMenu);

    _playlistSubscription =
        App.modManager.playlistObservable.stream.listen((_) {
      setState(() {
        _checkUiConditionState();
      });
    });

    _songListSubscription =
        App.modManager.songListObservable.stream.listen((_) {
      setState(() {});
    });

    _checkUiConditionState();
    super.initState();
  }

  @override
  void dispose() {
    _playlistSubscription.cancel();
    _songListSubscription.cancel();
    super.dispose();
  }

  static void _onPlaylistTap(BuildContext context, Playlist song) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PlaylistDetailPage(playlist: song),
      ),
    );
  }

  static void _onPlaylistDelete(
      BuildContext context, List<Playlist> playlists) async {
    var confirm = await GuiUtil.confirmChoice(context, "Delete playlists",
        "Are you sure you want to delete ${playlists.length} playlists?");

    if (confirm == true) {
      try {
        for (var playlist in playlists) {
          await App.modManager.deletePlaylist(playlist);
        }

        App.showToast('Deleted ${playlists.length} playlists');
      } catch (e) {
        App.showToast('Error $e');
      }
    }
  }

  void _onNewplaylistTap() async {
    var name = await GuiUtil.textInputDialog(
        context, 'Enter the name for the new playlist');

    if (name != null) {
      try {
        await App.modManager.createPlaylist(name);
      } catch (e) {
        App.showToast('Failed to create playlist: $e');
      }
    }
  }

  void _onSongsInNoPlaylistTap() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const SongsInNoPlaylistPage(),
      ),
    );
  }

  Widget _buildPlaylistList() => PlaylistListWidget(renderer);

  String playlistIconWarningText() => App.isQuest
      ? "This can happen when the playlists have been copied from the PC version of the game."
      : "This can happen when the playlists have been copied from the Quest version of the game.";

  void _fixPlaylistIcons() async {
    var list = App.modManager.playlists.values
        .where((x) => x.imageCompatibilityIssue)
        .toList();

    // Simply writing the playlist is enough as the platform specific code will re-encode the image as needed
    await App.modManager.applyMultiplePlaylistChanges(list);
  }

  void _ignorePlaylistIcons() {
    setState(() {
      showPlaylistIconFormatWarning = false;
      ignorePlaylistIconFormatWarning = true;
    });
  }

  Widget _iconFormatIssueWidget() => Padding(
        padding: GuiUtil.defaultViewPadding(context),
        child: ListTile(
          title: const Text('Invalid playlist icon data'),
          subtitle: Text(
              'Some playlists have wrong icon data and will appear without one in game. ${playlistIconWarningText()}\nClick this notification to fix them automatically.'),
          onTap: _fixPlaylistIcons,
          trailing: IconButton(
            tooltip: "Ignore",
            icon: const Icon(Icons.close),
            onPressed: _ignorePlaylistIcons,
          ),
        ),
      );

  void _openPlaylistErrorDetails() async {
    var errors = "";
    for (var error in App.modManager.errorPlaylists.values) {
      errors += "Failed to load ${error.fileName}:\n${error.error}\n\n";
    }
    await GuiUtil.longTextDialog(context, 'Playlist loading errors', errors);
  }

  Widget _playlistErrors() => Padding(
      padding: GuiUtil.defaultViewPadding(context),
      child: ListTile(
        title: const Text('Playlist loading errors'),
        subtitle: const Text(
            'Some playlists failed to load. This can be caused by a corrupted file or a missing song file.\nClick to see details.'),
        onTap: _openPlaylistErrorDetails,
        trailing: IconButton(
          tooltip: "Dismiss",
          icon: const Icon(Icons.close),
          onPressed: () {
            App.modManager.errorPlaylists.clear();
            setState(() {
              showPlaylistErrorList = false;
            });
          },
        ),
      ));

  Widget _bodyContent() {
    return Column(children: [
      if (showPlaylistIconFormatWarning) _iconFormatIssueWidget(),
      if (showPlaylistErrorList) _playlistErrors(),
      Expanded(child: _buildPlaylistList())
    ]);
  }

  Widget _buildDotsMenu() =>
      PopupMenuButton(itemBuilder: (BuildContext context) {
        return [
          PopupMenuItem(
            onTap: _onNewplaylistTap,
            child: const Text('New playlist'),
          ),
          PopupMenuItem(
            onTap: _onSongsInNoPlaylistTap,
            child: const Text('Find songs that are not in any playlist'),
          ),
        ];
      });

  @override
  Widget build(BuildContext context) => _bodyContent();
}

class PlaylistListPage extends StatefulWidget {
  const PlaylistListPage({super.key});

  @override
  State<PlaylistListPage> createState() => PlaylistListPageState();
}

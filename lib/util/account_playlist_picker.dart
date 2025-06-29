import 'package:bsaberquest/download_manager/beat_saver_api.dart';
import 'package:bsaberquest/main.dart';
import 'package:bsaberquest/util/gui_util.dart';
import 'package:bsaberquest/util/list_item_picker_page.dart';
import 'package:flutter/material.dart';

class AccountPlaylistPicker {
  static Future<BeatSaverPlaylistMetadata?> pick(BuildContext context) async {
    var userPlaylists = await GuiUtil.loadingDialog(context,
        "Loading playlists...", App.beatSaverClient.getUserPlaylists());

    if (userPlaylists == null || !context.mounted) return null;

    var picked = await CommonPickers.pick(
        context,
        ListItemPickerPage(
          title: "Select a playlist from your account",
          items: userPlaylists,
          filter: (text, playlist) => playlist.query(text),
          itemBuilder: (context, confirm, playlist) {
            return ListTile(
              onTap: () => confirm(playlist),
              title: Text(playlist.name),
              subtitle: Text(playlist.private ? "Private" : "Public"),
              leading: playlist.image == null
                  ? const Icon(Icons.music_note)
                  : Image.network(playlist.image!),
            );
          },
        ));

    return picked;
  }
}

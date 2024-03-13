import 'dart:io';

import 'package:bsaberquest/main.dart';
import 'package:bsaberquest/mod_manager/model/song.dart';
import 'package:flutter/material.dart';

class SongWidget extends StatelessWidget {
  const SongWidget({super.key, required this.song, this.onTap, this.extraIcon});

  final IconButton? extraIcon;
  final Song song;
  final Function(Song)? onTap;

  void _onTapEvent() {
    // Don't allow interaction with invalid songs
    if (!song.isValid) {
      App.showToast("Can't interact with invalid song");
      return;
    }

    if (onTap != null) {
      onTap!(song);
    }
  }

  Widget _songIcon() {
    if (!song.isValid) {
      return const Icon(Icons.warning);
    }

    if (song.meta.coverImageFilename.isEmpty) {
      return const Icon(Icons.music_note);
    }

    return Image.file(
        File("${song.folderPath}/${song.meta.coverImageFilename}"));
  }

  Widget? _extraIconWidget() {
    if (!song.isValid) {
      return null;
    }

    return extraIcon;
  }

  @override
  Widget build(BuildContext context) {
    return ListTile(
        leading: _songIcon(),
        title: Text(song.meta.songName),
        trailing: _extraIconWidget(),
        subtitle: Text(song.shortFolderName),
        onTap: _onTapEvent);
  }
}

class PlaylistWidget extends StatelessWidget {
  const PlaylistWidget(
      {super.key, required this.playlist, this.onTap, this.extraIcon});

  final IconButton? extraIcon;
  final Playlist playlist;
  final Function(Playlist)? onTap;

  void _onTapEvent() {
    if (onTap != null) {
      onTap!(playlist);
    }
  }

  static Widget? playlistIcon(Playlist playlist) => playlist.imageBytes != null
      ? Image.memory(playlist.imageBytes!)
      : const Icon(Icons.music_note);

  @override
  Widget build(BuildContext context) {
    return ListTile(
        leading: playlistIcon(playlist),
        title: Text(playlist.playlistTitle),
        trailing: extraIcon,
        subtitle: Text("${playlist.songs.length} songs\n${playlist.fileName}"),
        onTap: _onTapEvent);
  }
}

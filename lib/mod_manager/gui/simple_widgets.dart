import 'dart:io';

import 'package:bsaberquest/main.dart';
import 'package:bsaberquest/mod_manager/model/song.dart';
import 'package:flutter/material.dart';

import '../model/playlist.dart';

class SongWidget extends StatelessWidget {
  const SongWidget(
      {super.key,
      required this.song,
      this.onTap,
      this.extraIcon,
      this.onLongPress,
      this.highlight = false});

  final IconButton? extraIcon;
  final Song song;
  final Function()? onTap;
  final Function()? onLongPress;
  final bool highlight;

  void _onTapEvent() {
    // Don't allow interaction with invalid songs
    if (!song.isValid) {
      App.showToast("Can't interact with invalid song");
      return;
    }

    if (onTap != null) {
      onTap!();
    }
  }

  void _onLongPressEvent() {
    if (!song.isValid) {
      App.showToast("Can't interact with invalid song");
      return;
    }

    if (onLongPress != null) {
      onLongPress!();
    }
  }

  static Widget iconForSong(Song? song) {
    if (song == null) {
      return const Icon(Icons.music_note);
    }

    if (!song.isValid) {
      return const Icon(Icons.warning);
    }

    var icon = song.iconPath;
    if (icon != null) {
      return Image.file(File(icon));
    }

    return const Icon(Icons.music_note);
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
      leading: iconForSong(song),
      title: Text(song.meta.songName),
      trailing: _extraIconWidget(),
      subtitle: Text(song.prettyMetaInfo()),
      onTap: _onTapEvent,
      onLongPress: _onLongPressEvent,
      tileColor: highlight ? Colors.grey : null,
    );
  }
}

class UnknownSongWidget extends StatelessWidget {
  final String songName;
  final String hash;
  final bool isDownloading;

  final Function(String hash)? onDelete;
  final Function(String hash)? onDownload;

  const UnknownSongWidget(
      {super.key,
      required this.songName,
      required this.hash,
      this.onDelete,
      this.onDownload,
      this.isDownloading = false});

  Widget? _buidTrailing() {
    if (onDelete == null && onDownload == null) {
      return null;
    }

    List<Widget> buttons = [];

    if (onDelete != null) {
      buttons.add(IconButton(
          tooltip: "Remove song",
          onPressed: () => onDelete!(hash),
          icon: const Icon(Icons.delete)));
    }

    if (onDownload != null && !isDownloading) {
      buttons.add(IconButton(
          tooltip: "Download song",
          onPressed: () => onDownload!(hash),
          icon: const Icon(Icons.download)));
    }

    if (isDownloading) {
      buttons.add(const CircularProgressIndicator());
    }

    return Wrap(children: buttons);
  }

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: const Icon(Icons.music_note),
      title: Text(songName),
      subtitle: Text("Unknown song ($hash})"),
      trailing: _buidTrailing(),
    );
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

  static Widget playlistIcon(Playlist playlist) => playlist.imageBytes != null
      ? Image.memory(playlist.imageBytes!)
      : const Icon(Icons.music_note);

  @override
  Widget build(BuildContext context) {
    return ListTile(
        leading: SizedBox(width: 50, height: 50, child: playlistIcon(playlist)),
        title: Text(playlist.playlistTitle),
        trailing: extraIcon,
        subtitle: Text("${playlist.songs.length} songs\n${playlist.fileName}"),
        onTap: _onTapEvent);
  }
}

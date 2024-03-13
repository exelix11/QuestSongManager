import 'dart:async';

import 'package:bsaberquest/main.dart';
import 'package:bsaberquest/mod_manager/gui/song_detail_page.dart';
import 'package:bsaberquest/mod_manager/model/song.dart';
import 'package:flutter/material.dart';

import 'simple_widgets.dart';

class SongsListState extends State<SongListPage> {
  late StreamSubscription _playlistSubscription;
  late StreamSubscription _songListSubscription;

  @override
  void initState() {
    _playlistSubscription =
        App.modManager.playlistObservable.stream.listen((_) {
      setState(() {});
    });

    _songListSubscription =
        App.modManager.songListObservable.stream.listen((_) {
      setState(() {});
    });

    super.initState();
  }

  @override
  void dispose() {
    _playlistSubscription.cancel();
    _songListSubscription.cancel();
    super.dispose();
  }

  void _onSongTap(Song song) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => SongDetailPage(song: song),
      ),
    );
  }

  Widget _buildItem(BuildContext context, int index) {
    var song = App.modManager.songs.values.elementAt(index);
    return SongWidget(
      song: song,
      onTap: _onSongTap,
    );
  }

  Widget _buildAdaptiveListOrGird() {
    return GridView.builder(
      itemCount: App.modManager.songs.length,
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 200,
        childAspectRatio: 8 / 2,
        crossAxisSpacing: 20,
        mainAxisSpacing: 20,
      ),
      itemBuilder: _buildItem,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Song List'),
      ),
      body: ListView.builder(
          itemCount: App.modManager.songs.length, itemBuilder: _buildItem),
    );
  }
}

class SongListPage extends StatefulWidget {
  const SongListPage({super.key});

  @override
  State<SongListPage> createState() => SongsListState();
}

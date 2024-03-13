import 'dart:io';

import 'package:bsaberquest/download_manager/gui/util.dart';
import 'package:bsaberquest/main.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

class OptionsPageState extends State<OptionsPage> {
  final TextEditingController _idController = TextEditingController();

  void _downloadById(BuildContext context) async {
    var id = _idController.text;
    if (id.isEmpty) {
      return;
    }

    await DownloadUtil.downloadById(id, null);
  }

  Widget _permissionCheckWidget() {
    if (Platform.isAndroid) {
      return ElevatedButton(
          child: const Text('Request Permission'),
          onPressed: () async {
            if (await Permission.manageExternalStorage.request().isGranted) {
              // The user granted the permission
            }
          });
    }

    return const SizedBox();
  }

  Widget _hashCacheOptions() {
    var using = App.modManager.useFastHashCache;

    Widget button;

    if (using) {
      button = ElevatedButton(
        onPressed: () async {
          await App.modManager.removeCachedHashes();
          App.modManager.useFastHashCache = false;
          await App.preferences.setUseHashCache(false);
          App.showToast("Hash cache has been disabled");
          setState(() {});
        },
        child: const Text("Remove hash cache"),
      );
    } else {
      button = ElevatedButton(
        onPressed: () async {
          await App.preferences.setUseHashCache(true);
          App.showToast("Restart the app to apply changes");
          setState(() {});
        },
        child: const Text("Enable hash cache"),
      );
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(using ? "Using fast hash cache" : "hash cache has been disabled"),
        const SizedBox(width: 10),
        button
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Options'),
      ),
      body: Center(
        child: Column(
          children: [
            _permissionCheckWidget(),
            const SizedBox(height: 10),
            _hashCacheOptions(),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text("Download by ID"),
                const SizedBox(width: 10),
                SizedBox(
                  width: 100,
                  child: TextField(
                    controller: _idController,
                  ),
                ),
                const SizedBox(width: 10),
                ElevatedButton(
                  onPressed: () => _downloadById(context),
                  child: const Text("Download"),
                )
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class OptionsPage extends StatefulWidget {
  const OptionsPage({super.key});

  @override
  OptionsPageState createState() => OptionsPageState();
}

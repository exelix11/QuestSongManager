import 'package:bsaberquest/main.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

class GamePathPickerPage extends StatelessWidget {
  final bool canGoBack;

  const GamePathPickerPage(this.canGoBack, {super.key});

  void _pickPath(BuildContext context) async {
    String? selectedDirectory = await FilePicker.platform.getDirectoryPath();
    if (selectedDirectory == null) return;

    // Do something with the selected directory
    App.preferences.gameRootPath = selectedDirectory;
    App.showToast(
        "Game path set to: $selectedDirectory\nRestart the app to apply the change");
    if (context.mounted) {
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
          title: const Text('Select game path'),
          automaticallyImplyLeading: canGoBack),
      body: Center(
        child: Column(
          children: [
            const Text(
                "Please select the root directory of your Beat Saber installation"),
            const Text(
                "It is the folder that contains the main beatsaber.exe file"),
            const SizedBox(height: 20),
            ElevatedButton(
                onPressed: () => _pickPath(context),
                child: const Text("Pick path")),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}

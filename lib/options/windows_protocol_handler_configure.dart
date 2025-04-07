import 'package:bsaberquest/main.dart';
import 'package:bsaberquest/rpc/rpc_manager.dart';
import 'package:bsaberquest/util/list_item_picker_page.dart';
import 'package:flutter/material.dart';

class ProtocolHandlerConfiguration {
  static Future _removeRpcHandler() async {
    try {
      await RpcManager.removeRpcHandler();
      App.showToast("OneClick protocol handler removed");
    } catch (e) {
      App.showToast("Error: $e");
    }
  }

  static Future _installRpcHandler() async {
    try {
      await RpcManager.installRpcHandler();
      App.showToast("OneClick protocol handler installed");
    } catch (e) {
      App.showToast("Error: $e");
    }
  }

  static Future configure(BuildContext context) async {
    var add = _ConfigEntry(
        title: "Install the OneClick protocol handler",
        description:
            "Click here to install or reset the OneClick protocol handler.\nBy installing the protocol handler, you can click on installation links on BeatSaver and other webistes in your browsers and they will automatically be handled by this application. You can disable this feature at any time.",
        callback: _installRpcHandler,
        icon: const Icon(Icons.install_desktop));

    var remove = _ConfigEntry(
        title: "Uninstall the OneClick protocol handler",
        description:
            "Click here to uninstall the protocol handler. This app will not handle OneClick installs anymore until you reinstall it.",
        callback: _removeRpcHandler,
        icon: const Icon(Icons.delete_outline));

    var entries = [add, remove];

    var picked = await CommonPickers.pick(
        context,
        ListItemPickerPage<_ConfigEntry>(
          title: "OneClick install configuration",
          items: entries,
          showListHeading: false,
          itemBuilder: (context, confirm, entry) => ListTile(
            title: Text(entry.title),
            subtitle: Text(entry.description),
            leading: entry.icon,
            onTap: () {
              confirm(entry);
            },
          ),
        ));

    if (picked != null) {
      await picked.callback();
    }
  }
}

class _ConfigEntry {
  final String title;
  final String description;
  final Future Function() callback;
  final Icon icon;

  _ConfigEntry(
      {required this.title,
      required this.description,
      required this.callback,
      required this.icon});
}

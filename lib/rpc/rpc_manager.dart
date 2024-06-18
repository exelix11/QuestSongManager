// ignore_for_file: curly_braces_in_flow_control_structures

import 'dart:async';
import 'dart:convert';
import 'dart:ffi';
import 'dart:io';
import 'package:bsaberquest/download_manager/oauth_config.dart';
import 'package:ffi/ffi.dart';
import 'package:flutter/services.dart';

typedef NativeRpcCallback = Void Function(Pointer<Utf8>);

enum InitResult { fail, parent, child }

enum RpcCommandType {
  ping,
  getSongById,
  getPlaylistByUrl,
  beatSaverOauthLogin,
}

class RpcCommand {
  final RpcCommandType name;
  final List<String> args;

  RpcCommand._(this.name, this.args);

  Map<String, dynamic> toJson() => {"name": name.toString(), "args": args};

  factory RpcCommand.fromJson(Map<String, dynamic> json) {
    var name = json["name"] as String;
    var args = (json["args"] as List<dynamic>).map((e) => e as String).toList();

    var type = RpcCommandType.values
        .firstWhere((element) => element.toString() == name);

    return RpcCommand._(type, args);
  }

  factory RpcCommand.ping() => RpcCommand._(RpcCommandType.ping, []);

  factory RpcCommand.downloadSong(String songId) =>
      RpcCommand._(RpcCommandType.getSongById, [songId]);

  factory RpcCommand.downloadPlaylist(String fullUrl) =>
      RpcCommand._(RpcCommandType.getPlaylistByUrl, [fullUrl]);

  factory RpcCommand.beatSaverOauthLogin(String code) =>
      RpcCommand._(RpcCommandType.beatSaverOauthLogin, [code]);
}

class RpcManager {
  final platform = const MethodChannel('songmanager/rpc');
  late NativeCallable<NativeRpcCallback> _rpcCallback;

  final StreamController<RpcCommand> _commandQueue =
      StreamController<RpcCommand>.broadcast();

  final List<RpcCommand> pendingCommands = [];

  bool get hasPendingOperations => pendingCommands.isNotEmpty;

  InitResult? _initResult;

  RpcManager() {
    _rpcCallback = NativeCallable<NativeRpcCallback>.listener(_onMessage);
  }

  static Future _registerRegFile(String name, String content) async {
    if (!Platform.isWindows) {
      return;
    }

    var rpc = File(name);
    await rpc.writeAsString(content);

    var res = await Process.run("reg.exe", ["import", rpc.absolute.path]);

    if (res.exitCode != 0) {
      throw Exception("Failed to register rpc handler: ${res.stderr}");
    }
  }

  static Future removeRpcHandler() async {
    String reg = "";
    reg += r'Windows Registry Editor Version 5.00' "\r\n";
    reg += r'[-HKEY_CURRENT_USER\SOFTWARE\Classes\bsplaylist]' "\r\n";
    reg += r'[-HKEY_CURRENT_USER\SOFTWARE\Classes\beatsaver]' "\r\n";

    await _registerRegFile("rpc_remove.reg", reg);
  }

  static String _rpcHandlerFor(String protocol, String exepath) {
    exepath = exepath.replaceAll("\\", "\\\\");

    String reg = "";
    reg += "Windows Registry Editor Version 5.00\r\n";
    reg += "[HKEY_CURRENT_USER\\SOFTWARE\\Classes\\$protocol]\r\n";
    reg += r'"URL Protocol"=""' "\r\n";
    reg += "[HKEY_CURRENT_USER\\SOFTWARE\\Classes\\$protocol\\shell]\r\n";
    reg += "[HKEY_CURRENT_USER\\SOFTWARE\\Classes\\$protocol\\shell\\open]\r\n";
    reg +=
        "[HKEY_CURRENT_USER\\SOFTWARE\\Classes\\$protocol\\shell\\open\\command]\r\n";
    // ignore: prefer_interpolation_to_compose_strings
    reg += r'@="\"' + exepath + r'\" \"%1\""' "\r\n";
    reg += "\r\n";

    return reg;
  }

  static Future installOauthLoginHandler() async {
    var exepath = Platform.resolvedExecutable;
    if (!File(exepath).existsSync()) {
      throw Exception("The main executable could not be found");
    }

    String reg = "";
    reg += _rpcHandlerFor(BeatSaverOauthConfig.oauthProtocol, exepath);

    await _registerRegFile("rpc_registration.reg", reg);
  }

  static Future removeOauthHandler() async {
    String reg = "";
    reg += r'Windows Registry Editor Version 5.00' "\r\n";
    reg +=
        "[-HKEY_CURRENT_USER\\SOFTWARE\\Classes\\${BeatSaverOauthConfig.oauthProtocol}] \r\n";

    await _registerRegFile("rpc_remove.reg", reg);
  }

  static Future installRpcHandler() async {
    var exepath = Platform.resolvedExecutable;
    if (!File(exepath).existsSync()) {
      throw Exception("The main executable could not be found");
    }

    String reg = "";
    reg += _rpcHandlerFor("bsplaylist", exepath);
    reg += _rpcHandlerFor("beatsaver", exepath);

    await _registerRegFile("rpc_registration.reg", reg);
  }

  Future<InitResult> initialize() async {
    if (_initResult != null) throw Exception("Already initialized");

    var res = await platform.invokeMethod<int>("initializeMultiInstance",
        [4 * 1024, _rpcCallback.nativeFunction.address]);

    if (res == 1)
      _initResult = InitResult.fail;
    else if (res == 2)
      _initResult = InitResult.parent;
    else if (res == 3)
      _initResult = InitResult.child;
    else
      throw Exception("Invalid init result");

    return _initResult!;
  }

  Future terminate() async {
    await platform.invokeMethod<int>("terminateMultiInstance");
  }

  Future _sendRpcMessage(String message) async {
    await platform.invokeMethod<int>("sendRpcMessage", [message]);
  }

  Future sendCommand(RpcCommand command) async {
    // If we are the parent just pretend we received the command
    if (_initResult == InitResult.parent) {
      _onParsedMessage(command);
      return;
    }

    await _sendRpcMessage(jsonEncode(command.toJson()));
  }

  StreamSubscription<RpcCommand> subscribeEvents(
      Function(RpcCommand) callback) {
    var subs = _commandQueue.stream.listen(callback);

    for (var pending in pendingCommands) {
      _commandQueue.sink.add(pending);
    }

    pendingCommands.clear();
    return subs;
  }

  void _onParsedMessage(RpcCommand cmd) {
    if (_commandQueue.hasListener) {
      _commandQueue.add(cmd);
    } else {
      pendingCommands.add(cmd);
    }
  }

  void _onMessage(Pointer<Utf8> str) {
    var s = str.toDartString();
    try {
      var cmd = RpcCommand.fromJson(jsonDecode(s));
      _onParsedMessage(cmd);
    } catch (e) {
      print("Error $e: invalid rpc command $s");
    }
  }
}

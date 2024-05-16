// ignore_for_file: curly_braces_in_flow_control_structures

import 'dart:async';
import 'dart:convert';
import 'dart:ffi';
import 'package:ffi/ffi.dart';
import 'package:flutter/services.dart';

typedef NativeRpcCallback = Void Function(Pointer<Utf8>);

enum InitResult { fail, parent, child }

class RpcCommand {
  String name;
  List<String> args;

  bool get isSongDownload => name == "getSongById";
  bool get isPlaylistDownload => name == "getPlaylistByUrl";

  RpcCommand._(this.name, this.args);

  Map<String, dynamic> toJson() => {"name": name, "args": args};

  factory RpcCommand.fromJson(Map<String, dynamic> json) {
    var name = json["name"] as String;
    var args = (json["args"] as List<dynamic>).map((e) => e as String).toList();
    return RpcCommand._(name, args);
  }

  factory RpcCommand.ping() => RpcCommand._("ping", []);

  factory RpcCommand.downloadSong(String songId) =>
      RpcCommand._("getSongById", [songId]);

  factory RpcCommand.downloadPlaylist(String fullUrl) =>
      RpcCommand._("getPlaylistByUrl", [fullUrl]);
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

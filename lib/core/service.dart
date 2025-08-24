import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/core/core.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/models/core.dart';

import 'interface.dart';

class CoreService extends CoreHandlerInterface {
  static CoreService? _instance;

  Completer<ServerSocket> serverCompleter = Completer();

  Completer<Socket> socketCompleter = Completer();

  Map<String, Completer> callbackCompleterMap = {};

  Process? process;

  factory CoreService() {
    _instance ??= CoreService._internal();
    return _instance!;
  }

  CoreService._internal() {
    _initServer();
  }

  Future<void> handleResult(ActionResult result) async {
    final completer = callbackCompleterMap[result.id];
    final data = await parasResult(result);
    if (result.id?.isEmpty == true) {
      coreEventManager.sendEvent(CoreEvent.fromJson(result.data));
    }
    completer?.complete(data);
  }

  void _initServer() {
    ServerSocket? server;
    runZonedGuarded(
      () async {
        final address = !system.isWindows
            ? InternetAddress(unixSocketPath, type: InternetAddressType.unix)
            : InternetAddress(localhost, type: InternetAddressType.IPv4);
        await _deleteSocketFile();
        server = await ServerSocket.bind(address, 0, shared: true);
        serverCompleter.complete(server);
        await for (final socket in server!) {
          await _destroySocket();
          socketCompleter.complete(socket);
          socket
              .transform(uint8ListToListIntConverter)
              .transform(utf8.decoder)
              .transform(LineSplitter())
              .listen((data) {
                handleResult(ActionResult.fromJson(json.decode(data.trim())));
              });
        }
      },
      (error, stack) async {
        commonPrint.log('Service error: $error ${stack.toString()}');
        if (error is SocketException) {
          _handleInvokeCrashEvent();
        }
      },
    );
  }

  void _handleInvokeCrashEvent() {
    coreEventManager.sendEvent(CoreEvent(type: CoreEventType.crash));
  }

  Future<Socket> get socket => socketCompleter.future;

  Future<void> start() async {
    if (process != null) {
      await shutdown();
    }
    final serverSocket = await serverCompleter.future;
    final arg = system.isWindows
        ? '${serverSocket.port}'
        : serverSocket.address.address;
    if (system.isWindows && await system.checkIsAdmin()) {
      final isSuccess = await request.startCoreByHelper(arg);
      if (isSuccess) {
        return;
      }
    }
    process = await Process.start(appPath.corePath, [arg]);
    process?.stdout.listen((_) {});
    process?.stderr.listen((e) {
      final error = utf8.decode(e);
      if (error.isNotEmpty) {
        commonPrint.log(error);
      }
    });
  }

  @override
  destroy() async {
    final server = await serverCompleter.future;
    await server.close();
    await _deleteSocketFile();
    return true;
  }

  Future<void> sendMessage(String message) async {
    final socket = await socketCompleter.future;
    socket.writeln(message);
  }

  Future<void> _deleteSocketFile() async {
    if (!system.isWindows) {
      final file = File(unixSocketPath);
      if (await file.exists()) {
        await file.delete();
      }
    }
  }

  Future<void> _destroySocket() async {
    if (socketCompleter.isCompleted) {
      final lastSocket = await socketCompleter.future;
      socketCompleter = Completer();
      lastSocket.close();
    }
  }

  @override
  shutdown() async {
    await _destroySocket();
    if (system.isWindows) {
      await request.stopCoreByHelper();
    }
    process?.kill();
    process = null;
    return true;
  }

  // void _clearCompleter() {
  //   for (final completer in callbackCompleterMap.values) {
  //     completer.safeCompleter(null);
  //   }
  // }

  @override
  Future<bool> preload() async {
    await serverCompleter.future;
    await start();
    return true;
  }

  @override
  Future<T?> invoke<T>({
    required ActionMethod method,
    dynamic data,
    Duration? timeout,
  }) async {
    final id = '${method.name}#${utils.id}';

    callbackCompleterMap[id] = Completer<T?>();

    sendMessage(json.encode(Action(id: id, method: method, data: data)));

    return (callbackCompleterMap[id] as Completer<T?>).future.withTimeout(
      timeout: timeout,
      onLast: () {
        final completer = callbackCompleterMap[id];
        completer?.safeCompleter(null);
        callbackCompleterMap.remove(id);
      },
      tag: id,
      onTimeout: () => null,
    );
  }
}

final coreService = system.isDesktop ? CoreService() : null;

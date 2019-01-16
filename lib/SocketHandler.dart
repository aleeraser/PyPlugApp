import 'dart:io';

import 'package:flutter/material.dart';

import 'MessageHandler.dart';

const SOCKET_TIMEOUT = 5;

enum Commands { ATON, ATOFF, ATPRINT, ATZERO, ATRESET, ATPOWER, ATREAD, ATSTATE }
enum Priority { LOW, MID, HIGH }

class SocketHandler {
  static final SocketHandler _sh = SocketHandler._internal();

  Socket _s;
  bool socketIsFree = true;
  Priority currentSocketPriority = Priority.LOW;

  SocketHandler._internal();

  factory SocketHandler() {
    return _sh;
  }

  void destroySocket() {
    if (_s != null) {
      _s.close();
      _s.destroy();
      _s = null;
    }
    socketIsFree = true;
  }

  void sendCommand(
      {@required Commands command,
      String url,
      int port,
      Function onDataCallback,
      Function onErrorCallback,
      Function onDoneCallback,
      bool showMessages = true,
      Priority priority = Priority.LOW}) {
    final _commandStr = command.toString().replaceAll('Commands.', '');
    send(
        data: _commandStr,
        url: url,
        port: port,
        onDataCallback: onDataCallback,
        onErrorCallback: onErrorCallback,
        onDoneCallback: onDoneCallback,
        showMessages: showMessages,
        priority: priority);
  }

  void send(
      {@required String data,
      String url,
      int port,
      Function onDataCallback,
      Function onErrorCallback,
      Function onDoneCallback,
      bool showMessages = true,
      Priority priority = Priority.LOW}) {
    final _url = url != null ? url : '192.168.4.1';
    final _port = port != null ? port : 8888;

    if (!socketIsFree && priority.index <= currentSocketPriority.index) {
      return;
    }

    destroySocket();

    socketIsFree = false;
    currentSocketPriority = priority;

    Socket.connect(_url, _port, timeout: Duration(seconds: SOCKET_TIMEOUT))
        .then((Socket _newSocket) {
          _s = _newSocket;
          _s.write('$data\n');
          _s.listen(onDataCallback != null ? onDataCallback : null,
              onError: (exception) {
                destroySocket();

                if (showMessages) MessageHandler.getHandler().showError('Error.');

                if (exception is SocketException) {
                  debugPrint('Error: $exception');
                } else {
                  debugPrint('Error: $exception');
                }

                if (onErrorCallback != null) onErrorCallback();
              },
              cancelOnError: true,
              onDone: () {
                destroySocket();

                if (onDoneCallback != null) onDoneCallback();
                debugPrint('$data completed');
              });
        })
        .timeout(Duration(seconds: SOCKET_TIMEOUT))
        .catchError((exception) {
          destroySocket();

          debugPrint('Error: $exception');

          if (showMessages) {
            String errorMsg = 'Error';
            // FIXME: is there really no other way?
            if (exception is SocketException && exception.message.toLowerCase().contains('timed out')) {
              errorMsg = 'Error: timeout.';
            }
            MessageHandler.getHandler().showError(errorMsg);
          }

          if (onErrorCallback != null) onErrorCallback();
        });
  }
}

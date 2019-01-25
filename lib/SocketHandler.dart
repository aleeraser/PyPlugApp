import 'dart:convert';
import 'dart:io';
import 'package:connectivity/connectivity.dart';

import 'package:flutter/material.dart';

import 'MessageHandler.dart';

const TCP_SOCKET_TIMEOUT = 5; // seconds
const UDP_SOCKET_TIMEOUT = 10; // seconds

enum Commands { ATON, ATOFF, ATPRINT, ATZERO, ATRESET, ATPOWER, ATREAD, ATSTATE }
enum Priority { LOW, MID, HIGH }

class SocketHandler {
  static final SocketHandler _sh = SocketHandler._internal();

  Socket _s;
  bool socketIsFree = true;
  Priority currentSocketPriority = Priority.LOW;

  SocketHandler._internal();

  factory SocketHandler.getInstance() {
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

  void broadcast({String command, String url, int port, Function onDataCallback}) {
    RawDatagramSocket.bind(InternetAddress.anyIPv4, 8889).then((RawDatagramSocket udpSocket) {
      udpSocket.broadcastEnabled = true;
      udpSocket.listen((event) {
        Datagram dg = udpSocket.receive();
        if (dg != null) {
          String data = String.fromCharCodes(dg.data);
          if (data.startsWith('SOCKET')) {
            List<String> splitData = data.split(',');
            String addr;
            String macAddr;
            String port;
            try {
              addr = splitData[1];
            } catch (e) {
              addr = null;
            }
            try {
              macAddr = splitData[2];
            } catch (e) {
              macAddr = null;
            }
            try {
              port = splitData[3];
            } catch (e) {
              port = null;
            }
            debugPrint('addr: $addr, mac: $macAddr');
            if (onDataCallback != null) onDataCallback(addr, macAddr, port);
          }
        }
      });
      udpSocket.send(utf8.encode(command != null ? command : 'ATLOOKUP'), InternetAddress(url != null ? url : '192.168.1.255'), port != null ? port : 8889);
    });
  }

  void sendCommand(
      {@required Commands command,
      String address,
      int port,
      Function onDataCallback,
      Function onErrorCallback,
      Function onDoneCallback,
      bool showMessages = true,
      Priority priority = Priority.LOW}) {
    final _commandStr = command.toString().replaceAll('Commands.', '');
    send(
        data: _commandStr,
        address: address,
        port: port,
        onDataCallback: onDataCallback,
        onErrorCallback: onErrorCallback,
        onDoneCallback: onDoneCallback,
        showMessages: showMessages,
        priority: priority);
  }

  void send(
      {@required String data,
      String address,
      int port,
      Function onDataCallback,
      Function onErrorCallback,
      Function onDoneCallback,
      bool showMessages = true,
      Priority priority = Priority.LOW}) {
    final _url = address != null ? address : '192.168.1.8';
    final _port = port != null ? port : 8888;

    if (!socketIsFree && priority.index <= currentSocketPriority.index) {
      debugPrint('Couldn\'t perform socket operation since another socket operation with equal or higher priority is still in progress.');
      return;
    }

    destroySocket();

    socketIsFree = false;
    currentSocketPriority = priority;

    Socket.connect(_url, _port, timeout: Duration(seconds: TCP_SOCKET_TIMEOUT))
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
                // debugPrint('$data completed');
              });
        })
        .timeout(Duration(seconds: TCP_SOCKET_TIMEOUT))
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

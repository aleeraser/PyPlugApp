import 'dart:io';

import 'package:flutter/material.dart';

import 'customImageCircularButton.dart';
import 'settingsView.dart';

const SOCKET_TIMEOUT = 5;

Socket s;

enum Commands { ATON, ATOFF, ATPRINT, ATZERO, ATRESET, ATPOWER, ATREAD, ATSTATE }

void main() => runApp(MyApp());

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Smart Socket',
      theme: ThemeData(
        primaryColor: Color.fromARGB(255, 0, 51, 50),
      ),
      home: SmartSocketHomePage(),
    );
  }
}

class SmartSocketHomePage extends StatefulWidget {
  @override
  _SmartSocketHomePageState createState() => _SmartSocketHomePageState();
}

class _SmartSocketHomePageState extends State<SmartSocketHomePage> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  bool _status;
  String get statusText {
    if (_status == null) {
      return 'Loading...';
    } else if (_status) {
      return 'Socket is on';
    } else {
      return 'Socket is off';
    }
  }

  void _navigateToSettings() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (BuildContext context) {
          return SettingsView().build(context);
        },
      ),
    );
  }

  void _destroySocket() {
    if (s != null) {
      s.close();
      s.destroy();
      s = null;
      // debugPrint("Destroyed socket.");
    } else {
      debugPrint("Socket wasn't opened.");
    }
  }

  void _socketConnection({Commands command, String url, int port, Function onDataCallback, Function onErrorCallback, Function onDoneCallback}) {
    final _url = url != null ? url : '192.168.4.1';
    final _port = port != null ? port : 8888;
    final _commandStr = command.toString().replaceAll('Commands.', '');

    Socket.connect(_url, _port, timeout: Duration(seconds: SOCKET_TIMEOUT)).then((Socket _s) {
      s = _s;
      s.write('$_commandStr\n');
      s.listen(onDataCallback != null ? onDataCallback : null, onError: onErrorCallback != null ? onErrorCallback : (error) => _showMessage('Error'), cancelOnError: true,
          onDone: () {
        _destroySocket();

        if (onDoneCallback != null) onDoneCallback();
        debugPrint('$_commandStr completed');
      });
    }).catchError((error) {
      final e = error as SocketException;
      debugPrint(e.message);

      // FIXME: is there really no other way?
      if (e.message.toLowerCase().contains('timed out')) {
        _showMessage('Error: timeout.', error: true);
      } else {
        _showMessage('Error.', error: true);
      }
    });
  }

  void _updateStatus({Function onDoneCallback}) {
    _socketConnection(command: Commands.ATSTATE, onDataCallback: (data) => _status = String.fromCharCodes(data) == '1', onDoneCallback: onDoneCallback);
  }

  void _showMessage(String msg, {bool error = false}) {
    _scaffoldKey.currentState.showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: error ? Colors.red[900] : null,
    ));
  }

  @override
  void initState() {
    if (_status == null) {
      _updateStatus(onDoneCallback: () {
        debugPrint('Status: ${_status ? 'on' : 'off'}');
        setState(() => null);
      });
    }
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      appBar: AppBar(
        title: const Text('Smart Socket'),
        centerTitle: true,
        actions: <Widget>[
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: _navigateToSettings,
          ),
        ],
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: <Widget>[
            CustomImageCircularButton(
                sideLength: MediaQuery.of(context).size.width / 2,
                assetImage: _status != null && _status ? const AssetImage('assets/images/btn_on.png') : const AssetImage('assets/images/btn_off.png'),
                onTap: () {
                  _socketConnection(
                      command: _status ? Commands.ATOFF : Commands.ATON,
                      onDoneCallback: () {
                        final _oldStatus = _status;

                        _updateStatus(
                            onDoneCallback: () => setState(() {
                                  if (_oldStatus == _status) {
                                    _showMessage('Error');
                                  }
                                }));
                      });
                }),
            Text(statusText),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: <Widget>[
                IconButton(
                  icon: const Icon(Icons.adb),
                  onPressed: () {
                    _updateStatus();
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.cancel),
                  onPressed: () {
                    _destroySocket();
                  },
                )
              ],
            ),
          ],
        ),
      ),
      backgroundColor: _status != null && _status ? Colors.white : const Color.fromARGB(255, 49, 58, 73),
    );
  }
}

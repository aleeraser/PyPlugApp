import 'dart:io';

import 'package:flutter/material.dart';

import 'customImageCircularButton.dart';
import 'settingsView.dart';

const SOCKET_TIMEOUT = 5;

Socket s;

enum Commands { ATON, ATOFF, ATPRINT, ATZERO, ATRESET, ATPOWER, ATREAD, ATSTATE }
enum Status { ON, OFF, UNKNOWN }

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
  Status _status = Status.UNKNOWN;
  String _statusText = 'Status unknown';

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
      // debugPrint('Destroyed socket.');
    } else {
      debugPrint('Socket wasn\'t opened.');
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

      setState(() {
        _statusText = 'Status unknown';
      });
    });
  }

  void _updateStatus({Function onDoneCallback}) {
    _socketConnection(
        command: Commands.ATSTATE,
        onDataCallback: (data) {
          _status = String.fromCharCodes(data) == '1' ? Status.ON : Status.OFF;
          _statusText = 'Socket is ${_status == Status.ON ? 'on' : 'off'}';
        },
        onDoneCallback: onDoneCallback);
  }

  void _showMessage(String msg, {bool error = false}) {
    _scaffoldKey.currentState.showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: error ? Colors.red[900] : null,
    ));
  }

  @override
  void initState() {
    if (_status == Status.UNKNOWN) {
      _statusText = 'Loading...';
      _updateStatus(onDoneCallback: () {
        debugPrint('Status: ${_status == Status.ON ? 'on' : 'off'}');
        setState(() => null);
      });
    }
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    IconButton retryButton = IconButton(
      icon: const Icon(Icons.refresh),
      onPressed: () {
        setState(() {
          _statusText = 'Loading...';
        });
        _updateStatus(onDoneCallback: () {
          debugPrint('Status: ${_status == Status.ON ? 'on' : 'off'}');
          setState(() => null);
        });
      },
    );

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
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: <Widget>[
            Column(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: <Widget>[
                CustomImageCircularButton(
                    sideLength: MediaQuery.of(context).size.width / 2,
                    assetImage: _status == Status.ON ? const AssetImage('assets/images/btn_on.png') : const AssetImage('assets/images/btn_off.png'),
                    onTap: () {
                      _socketConnection(
                          command: _status == Status.ON ? Commands.ATOFF : Commands.ATON,
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
                Padding(
                  padding: EdgeInsets.only(top: 40),
                  child: Text(_statusText),
                ),
                _status == Status.UNKNOWN && _statusText != 'Loading...'
                    ? retryButton
                    : Container(), // empty container as a workaround, since 'null' is not supported for a child tree
              ],
            ),
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
      backgroundColor: _status == Status.ON ? Colors.white : const Color.fromARGB(255, 49, 58, 73),
    );
  }
}

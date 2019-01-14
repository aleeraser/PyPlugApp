import 'dart:io';

import 'package:audioplayers/audio_cache.dart';
import 'package:flutter/material.dart';

import 'customImageCircularButton.dart';
import 'settingsView.dart';
import 'dart:async';

const SOCKET_TIMEOUT = 5;

Socket _s;
Timer _timer;

enum Commands { ATON, ATOFF, ATPRINT, ATZERO, ATRESET, ATPOWER, ATREAD, ATSTATE }
enum Status { ON, OFF, UNKNOWN, LOADING }
enum DataType { CURRENT, POWER }

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

  Status __status = Status.UNKNOWN;
  Status _prevStatus = Status.UNKNOWN;
  get _status => __status;
  set _status(Status newStatus) {
    _prevStatus = __status;
    __status = newStatus;

    if (newStatus == Status.UNKNOWN) {
      _current = _power = 'Unknown';
      _statusText = 'Status unknown';
    }
  }

  String _current = 'Unknown', _power = 'Unknown';

  String _statusText = 'Status unknown';
  Color _dynamicColor;

  bool _socketIsFree = true;

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
    if (_s != null) {
      _s.close();
      _s.destroy();
      _s = null;
      // debugPrint('Destroyed socket.');
    } else {
      debugPrint('Socket wasn\'t opened.');
    }
    _socketIsFree = true;
  }

  void _socketConnection({@required Commands command, bool showMessages = true, String url, int port, Function onDataCallback, Function onErrorCallback, Function onDoneCallback}) {
    final _url = url != null ? url : '192.168.4.1';
    final _port = port != null ? port : 8888;
    final _commandStr = command.toString().replaceAll('Commands.', '');

    if (!_socketIsFree) {
      return;
    }

    _socketIsFree = false;

    Socket.connect(_url, _port, timeout: Duration(seconds: SOCKET_TIMEOUT)).then((Socket _newSocket) {
      _s = _newSocket;
      _s.write('$_commandStr\n');
      _s.listen(onDataCallback != null ? onDataCallback : null,
          onError: (exception) {
            _destroySocket();
            if (showMessages) _showMessage('Error.', error: true);

            if (exception is SocketException) {
              debugPrint(exception.message);
            } else {
              debugPrint(exception.toString());
            }

            if (onErrorCallback != null) onErrorCallback();
          },
          cancelOnError: true,
          onDone: () {
            _destroySocket();

            if (onDoneCallback != null) onDoneCallback();
            debugPrint('$_commandStr completed');
          });
    }).catchError((exception) {
      _destroySocket();
      if (exception is SocketException) {
        debugPrint(exception.message);

        // FIXME: is there really no other way?
        if (exception.message.toLowerCase().contains('timed out')) {
          if (showMessages) _showMessage('Error: timeout.', error: true);
        }
      } else {
        if (showMessages) _showMessage('Error.', error: true);
        debugPrint(exception.toString());
      }

      if (onErrorCallback != null) onErrorCallback();
    });
  }

  void _updateStatus({bool showLoading = false, bool showMessages = true, Function onDoneCallback}) {
    if (showLoading) {
      setState(() {
        _statusText = 'Loading...';
        _status = Status.LOADING;
      });
    }

    _socketConnection(
        command: Commands.ATSTATE,
        showMessages: showMessages,
        onDataCallback: (data) {
          _status = String.fromCharCodes(data) == '1' ? Status.ON : Status.OFF;
          _statusText = 'Socket is ${_status == Status.ON ? 'on' : 'off'}';
        },
        onDoneCallback: () => _updateStats(onDoneCallback: onDoneCallback),
        onErrorCallback: () => setState(() {
              _status = Status.UNKNOWN;
            }));
  }

  void _updateStats({Function onDoneCallback}) {
    Function _powerStatUpdate = () {
      _socketConnection(
          command: Commands.ATPOWER,
          onDataCallback: (data) {
            _power = String.fromCharCodes(data);
          },
          onDoneCallback: onDoneCallback,
          onErrorCallback: () => setState(() {
                _status = Status.UNKNOWN;
              }));
    };
    _socketConnection(
        command: Commands.ATREAD,
        onDataCallback: (data) {
          _current = String.fromCharCodes(data);
        },
        onDoneCallback: _powerStatUpdate,
        onErrorCallback: () => setState(() {
              _status = Status.UNKNOWN;
            }));
  }

  void _resetPowerStat({Function onDoneCallback}) {
    _socketConnection(
        command: Commands.ATZERO,
        onDataCallback: (data) {
          _current = String.fromCharCodes(data);
        },
        onDoneCallback: onDoneCallback,
        onErrorCallback: () => setState(() {
              _status = Status.UNKNOWN;
            }));
  }

  void _showMessage(String msg, {bool error = false}) {
    _scaffoldKey.currentState.showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: error ? Colors.red[900] : null,
      action: SnackBarAction(
        label: 'CLOSE',
        textColor: error ? Colors.white : DefaultTextStyle,
        onPressed: () => _scaffoldKey.currentState.removeCurrentSnackBar(reason: SnackBarClosedReason.remove),
      ),
    ));
  }

  void _rescheduleUpdateTimer(Duration duration) {
    if (_timer != null) {
      _timer.cancel();
    }

    _timer = Timer.periodic(duration, (timer) {
      if (_socketIsFree) {
        debugPrint('Update');
        _updateStatus(showMessages: false, onDoneCallback: () => setState(() => null));
      }
    });
  }

  @override
  void initState() {
    if (_status == Status.UNKNOWN) {
      _updateStatus(onDoneCallback: () {
        debugPrint('Status: $_status');
        setState(() => null);
      });
    }

    _rescheduleUpdateTimer(Duration(seconds: 5));

    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    Color _tableBorderColor, backgroundColor;
    AssetImage assetImage;
    Commands switchButtonCommand;

    if (_status == Status.LOADING) {
      _tableBorderColor = _prevStatus == Status.ON ? Colors.grey[200] : Colors.blueGrey[800];
      _dynamicColor = _prevStatus == Status.ON ? Colors.black : Colors.blueGrey[300];
      assetImage = _prevStatus == Status.ON ? const AssetImage('assets/images/btn_on.png') : const AssetImage('assets/images/btn_off.png');
      switchButtonCommand = _prevStatus == Status.ON ? Commands.ATOFF : Commands.ATON;
      backgroundColor = _prevStatus == Status.ON ? Colors.white : const Color.fromARGB(255, 49, 58, 73);
    } else {
      _tableBorderColor = _status == Status.ON ? Colors.grey[200] : Colors.blueGrey[800];
      _dynamicColor = _status == Status.ON ? Colors.black : Colors.blueGrey[300];
      assetImage = _status == Status.ON ? const AssetImage('assets/images/btn_on.png') : const AssetImage('assets/images/btn_off.png');
      switchButtonCommand = _status == Status.ON ? Commands.ATOFF : Commands.ATON;
      backgroundColor = _status == Status.ON ? Colors.white : const Color.fromARGB(255, 49, 58, 73);
    }

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
                    assetImage: assetImage,
                    onTap: () {
                      final AudioCache audioPlayer = AudioCache();
                      const switchAudioPath = 'sounds/switch.mp3';

                      _socketConnection(
                          command: switchButtonCommand,
                          onDoneCallback: () {
                            audioPlayer.play(switchAudioPath);

                            final _oldStatus = _status;

                            _updateStatus(
                                showLoading: false,
                                onDoneCallback: () => setState(() {
                                      if (_oldStatus == _status) {
                                        _showMessage('Error');
                                      }
                                    }));
                          });
                    }),
                Padding(
                  padding: EdgeInsets.only(top: 40),
                  child: Text(_statusText, style: TextStyle(color: _dynamicColor), textScaleFactor: 1.3),
                ),
                IconButton(
                  icon: const Icon(Icons.refresh),
                  onPressed: _status != Status.LOADING ? () => _updateStatus(onDoneCallback: () => setState(() => null)) : null,
                ),
              ],
            ),
            Column(
              children: <Widget>[
                Text('Statistics', style: TextStyle(fontStyle: FontStyle.italic)),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: MediaQuery.of(context).size.width / 8, vertical: 10),
                  child: Table(
                    defaultVerticalAlignment: TableCellVerticalAlignment.middle,
                    border: TableBorder.symmetric(inside: BorderSide(color: _tableBorderColor), outside: BorderSide(color: _tableBorderColor)),
                    children: <TableRow>[
                      TableRow(children: <TableCell>[
                        TableCell(
                            child: Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: Text('Current (A)\n$_current', style: TextStyle(color: _dynamicColor), textScaleFactor: 1.1, textAlign: TextAlign.center),
                        )),
                        TableCell(
                            child: GestureDetector(
                                onTap: () => showDialog(
                                    context: context,
                                    builder: (_) => AlertDialog(
                                          title: Text('Reset \'Power\' value?'),
                                          actions: <Widget>[
                                            FlatButton(
                                                child: const Text('Back'),
                                                onPressed: () {
                                                  Navigator.of(context).pop();
                                                }),
                                            FlatButton(
                                                child: Text(
                                                  'Reset value',
                                                  style: TextStyle(color: Colors.red[800]),
                                                ),
                                                onPressed: () {
                                                  _resetPowerStat(onDoneCallback: () {
                                                    setState(() {
                                                      _power = '0.000';
                                                    });
                                                  });
                                                  Navigator.of(context).pop();
                                                }),
                                          ],
                                        )),
                                child: Padding(
                                  padding: const EdgeInsets.all(8.0),
                                  child: Text('Power (W)\n$_power', style: TextStyle(color: _dynamicColor), textScaleFactor: 1.1, textAlign: TextAlign.center),
                                ))),
                      ]),
                    ],
                  ),
                ),
              ],
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: <Widget>[
                IconButton(
                  icon: const Icon(Icons.adb),
                  onPressed: () {
                    _updateStatus(onDoneCallback: () => setState(() => null));
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
      backgroundColor: backgroundColor,
    );
  }
}

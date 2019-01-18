import 'dart:async';

import 'package:audioplayers/audio_cache.dart';
import 'package:flutter/material.dart';
import 'package:preferences/preferences.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'CustomImageCircularButton.dart';
import 'MessageHandler.dart';
import 'SettingsView.dart';
import 'SocketHandler.dart';

const COLOR_ON = Color.fromARGB(255, 255, 255, 255);
const COLOR_OFF = Color.fromARGB(255, 49, 58, 73);

enum Status { ON, OFF, UNKNOWN, LOADING }

SharedPreferences _persistanceService;

main() async {
  await PrefService.init(prefix: 'pref_');
  _persistanceService = await SharedPreferences.getInstance();
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Smart Socket',
      theme: ThemeData(
        primaryColor: COLOR_OFF,
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
    if (newStatus != __status) {
      _prevStatus = __status;
      __status = newStatus;

      if (newStatus == Status.UNKNOWN) {
        _current = _power = 'Unknown';
        _statusText = 'Status unknown';
      }
    }
  }

  String _current = 'Unknown', _power = 'Unknown';

  String _statusText = 'Status unknown';
  Color _dynamicColor;

  SocketHandler _sh = SocketHandler.getInstance();
  Timer _timer;

  int _updateInterval = _persistanceService.getString('refresh_interval') != null ? int.parse(_persistanceService.getString('refresh_interval')) : 10;
  set updateInterval(int newInterval) {
    if (newInterval != _updateInterval) {
      _updateInterval = newInterval;
      _rescheduleUpdateTimer(Duration(seconds: _updateInterval));
      debugPrint(_updateInterval > 0 ? 'Rescheduled periodic update routine every ${_updateInterval}s' : 'Periodic update routine canceled');
    }
  }

  void _navigateToSettings() {
    final Map<Object, Object> prevPrefValues = Map.fromIterable(_persistanceService.getKeys(), key: (key) => key, value: (key) => _persistanceService.get(key));

    Navigator.of(context)
        .push(MaterialPageRoute(
            builder: (BuildContext context) => SettingsView(
                  prevPrefValues: prevPrefValues,
                  persistanceService: _persistanceService,
                )))
        .then((returnedValue) {
      updateInterval = int.parse(_persistanceService.get('refresh_interval'));
    });
  }

  void _updateStatus({Function onDoneCallback, bool showLoading = false, bool showMessages = true, Priority priority = Priority.LOW}) {
    // if called updateStatus cancel current timer and re-schedule it later
    _rescheduleUpdateTimer(Duration(seconds: _updateInterval));

    if (showLoading) {
      setState(() {
        _statusText = 'Loading...';
        _status = Status.LOADING;
      });
    }

    _sh.send(
        data: 'ATALL',
        showMessages: showMessages,
        priority: priority,
        onDataCallback: (data) {
          final List<String> sData = String.fromCharCodes(data).split(',');
          _status = sData[0] == '1' ? Status.ON : Status.OFF;
          _statusText = 'Socket is ${_status == Status.ON ? 'on' : 'off'}';

          _current = sData[1];
          _power = sData[2];
        },
        onDoneCallback: () => setState(() {
              if (onDoneCallback != null) onDoneCallback();
            }),
        onErrorCallback: () => setState(() {
              _status = Status.UNKNOWN;
            }));
  }

  void _resetPowerStat({Function onDoneCallback}) {
    _sh.sendCommand(
        command: Commands.ATZERO,
        priority: Priority.HIGH,
        showMessages: true,
        onDataCallback: (data) {
          _current = String.fromCharCodes(data);
        },
        onDoneCallback: onDoneCallback,
        onErrorCallback: () => setState(() {
              _status = Status.UNKNOWN;
            }));
  }

  void _rescheduleUpdateTimer(Duration duration) {
    if (_timer != null) {
      _timer.cancel();
      if (duration == Duration.zero) {
        return;
      }
    }

    _timer = Timer.periodic(duration, (timer) {
      if (_sh.socketIsFree) {
        // debugPrint('Update');
        _updateStatus(showMessages: false);
      }
    });
  }

  @override
  void initState() {
    MessageHandler.getHandler().setScaffoldKey(_scaffoldKey);

    if (_status == Status.UNKNOWN) {
      _updateStatus(onDoneCallback: () {
        debugPrint('Initial status: $_status');
      });
    }

    _rescheduleUpdateTimer(Duration(seconds: _updateInterval));

    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    Color _tableBorderColor, backgroundColor;
    AssetImage assetImage;
    Commands switchButtonCommand;

    if (_status == Status.LOADING || _status == Status.UNKNOWN) {
      _tableBorderColor = _prevStatus == Status.ON ? Colors.grey[200] : Colors.blueGrey[800];
      _dynamicColor = _prevStatus == Status.ON ? Colors.black : Colors.blueGrey[300];
      assetImage = _prevStatus == Status.ON ? const AssetImage('assets/images/btn_on.png') : const AssetImage('assets/images/btn_off.png');
      switchButtonCommand = _prevStatus == Status.ON ? Commands.ATOFF : Commands.ATON;
      backgroundColor = _prevStatus == Status.ON ? COLOR_ON : COLOR_OFF;
    } else {
      _tableBorderColor = _status == Status.ON ? Colors.grey[200] : Colors.blueGrey[800];
      _dynamicColor = _status == Status.ON ? Colors.black : Colors.blueGrey[300];
      assetImage = _status == Status.ON ? const AssetImage('assets/images/btn_on.png') : const AssetImage('assets/images/btn_off.png');
      switchButtonCommand = _status == Status.ON ? Commands.ATOFF : Commands.ATON;
      backgroundColor = _status == Status.ON ? COLOR_ON : COLOR_OFF;
    }

    return Scaffold(
      key: _scaffoldKey,
      appBar: AppBar(
        title: const Text('Smart Socket'),
        centerTitle: true,
        elevation: 0.0,
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
                      const String switchAudioPath = 'sounds/switch.mp3';

                      _sh.sendCommand(
                          command: switchButtonCommand,
                          priority: Priority.HIGH,
                          onDoneCallback: () {
                            audioPlayer.play(switchAudioPath);

                            final Status _oldStatus = _status;

                            _updateStatus(
                                showLoading: false,
                                onDoneCallback: () {
                                  if (_oldStatus == _status) {
                                    MessageHandler.getHandler().showError('Error: inconsistent status');
                                  }
                                });
                          });
                    }),
                Padding(
                  padding: const EdgeInsets.only(top: 40),
                  child: Text(_statusText, style: TextStyle(color: _dynamicColor), textScaleFactor: 1.3),
                ),
                IconButton(
                  icon: const Icon(Icons.refresh),
                  color: _dynamicColor,
                  onPressed: _status != Status.LOADING ? () => _updateStatus() : null, // if onPressed is 'null' the button will appear as disabled
                ),
              ],
            ),
            Column(
              children: <Widget>[
                Text(
                  'Statistics',
                  style: TextStyle(color: _dynamicColor, fontStyle: FontStyle.italic),
                  textAlign: TextAlign.center,
                ),
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
                    _updateStatus();
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.cancel),
                  onPressed: () {
                    _sh.destroySocket();
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

  @override
  void dispose() {
    _sh.destroySocket();
    _timer.cancel();
    super.dispose();
  }
}

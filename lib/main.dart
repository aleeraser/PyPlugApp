import 'dart:async';

import 'package:audioplayers/audio_cache.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'CustomImageCircularButton.dart';
import 'DurationPicker.dart';
import 'MessageHandler.dart';
import 'SettingsView.dart';
import 'SocketHandler.dart';

const COLOR_ON = Color.fromARGB(255, 255, 255, 255);
const COLOR_OFF = Color.fromARGB(255, 49, 58, 73);

enum Status { ON, OFF, UNKNOWN, LOADING }

SharedPreferences _persistanceService;

main() async {
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

  final TextEditingController _deviceNameEditingController =
      TextEditingController(text: _persistanceService.getString('device_name') != null ? _persistanceService.getString('device_name') : 'device_name');
  bool _editingTitle = false;
  FocusNode _deviceNameFocusNode;

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
  int __timerSeconds = 0;
  get _timerSeconds => __timerSeconds;
  set _timerSeconds(int seconds) {
    if (seconds > 0 && seconds != __timerSeconds)
    __timerSeconds = seconds;

    // TODO: funzione che mostra il countdown dei secondi
    // TODO: all'avvio controlla se c'e' un timer attivo
    // TODO: possibilita' di cancellare un timer attivo
  }

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
      MessageHandler.getHandler().setScaffoldKey(_scaffoldKey);

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

  bool canI() {
    // progressively add any blocking condition
    return _editingTitle == false;
  }

  @override
  void initState() {
    MessageHandler.getHandler().setScaffoldKey(_scaffoldKey);

    _deviceNameFocusNode = FocusNode();

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

    DurationPicker durationPicker = DurationPicker(darkTheme: true);

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

    // the callback gets called every time this function completes
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_editingTitle) {
        // if editing title give focus to the TextField
        FocusScope.of(context).requestFocus(_deviceNameFocusNode);
      }
    });

    return Scaffold(
      key: _scaffoldKey,
      resizeToAvoidBottomPadding: false,
      appBar: AppBar(
        title: Container(
          width: MediaQuery.of(context).size.width / 2,
          child: _editingTitle
              ? TextField(
                  autofocus: true,
                  focusNode: _deviceNameFocusNode,
                  style: Theme.of(context).textTheme.title.merge(TextStyle(color: COLOR_ON)),
                  controller: _deviceNameEditingController,
                  // maxLength: 20,
                  textAlign: TextAlign.center,
                  decoration: InputDecoration.collapsed(
                      hintText: 'Enter device name', hintStyle: Theme.of(context).textTheme.title.merge(TextStyle(fontWeight: FontWeight.normal, color: Colors.grey))),
                  onSubmitted: (val) {
                    if (val == '') {
                      _deviceNameEditingController.text = _persistanceService.getString('device_name');
                    } else {
                      _persistanceService.setString('device_name', val);
                    }
                    setState(() {
                      _editingTitle = false;
                    });
                  },
                  onEditingComplete: () {
                    // close keyboard
                    FocusScope.of(context).requestFocus(new FocusNode());

                    setState(() {
                      _editingTitle = false;
                    });
                  },
                )
              : Text(
                  _deviceNameEditingController.text,
                  textAlign: TextAlign.center,
                ),
        ),
        centerTitle: true,
        elevation: 0.0,
        actions: <Widget>[
          _editingTitle
              ? IconButton(
                  icon: const Icon(Icons.check),
                  onPressed: _deviceNameEditingController.text.length > 0
                      ? () {
                          // close keyboard
                          FocusScope.of(context).requestFocus(new FocusNode());

                          setState(() {
                            _editingTitle = false;
                          });
                        }
                      : null,
                )
              : IconButton(
                  icon: const Icon(Icons.edit),
                  onPressed: () {
                    setState(() => _editingTitle = true);
                  },
                ),
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: canI() ? _navigateToSettings : null,
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
                    onTap: _status == Status.UNKNOWN || _status == Status.LOADING || !canI()
                        ? null
                        : () {
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
                  onPressed: _status != Status.LOADING && canI() ? () => _updateStatus() : null, // if onPressed is 'null' the button will appear as disabled
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
                                onTap: _status == Status.UNKNOWN || _status == Status.LOADING || !canI()
                                    ? null
                                    : () => showDialog(
                                        context: context,
                                        builder: (_) => AlertDialog(
                                              title: Text('Reset \'Power\' value?'),
                                              actions: <Widget>[
                                                FlatButton(
                                                    child: Text(
                                                      'Back',
                                                      style: TextStyle(color: Colors.lightBlue[900]),
                                                    ),
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
                                                        _updateStatus();
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
                Column(
                  children: <Widget>[
                    IconButton(
                      icon: const Icon(Icons.timer),
                      onPressed: _status == Status.UNKNOWN || !canI()
                          ? null
                          : () {
                              showDialog(
                                  context: context,
                                  builder: (_) {
                                    return Theme(
                                      data: Theme.of(context).copyWith(dialogBackgroundColor: COLOR_OFF),
                                      child: AlertDialog(
                                        // title: Text('Set timer', style: TextStyle(color: Colors.blueGrey[100])),
                                        content: durationPicker,
                                        actions: <Widget>[
                                          FlatButton(
                                              child: Text(
                                                'Cancel',
                                                style: TextStyle(color: Colors.red[800]),
                                              ),
                                              onPressed: () {
                                                Navigator.of(context).pop();
                                              }),
                                          FlatButton(
                                              child: Text(
                                                'Set',
                                                style: TextStyle(color: Colors.blueGrey[200]),
                                              ),
                                              onPressed: () {
                                                _sh.send(
                                                    data: 'ATTIMER,SET,${durationPicker.getSeconds()},${_status == Status.ON ? 'ATOFF' : 'ATON'}',
                                                    showMessages: true,
                                                    priority: Priority.HIGH,
                                                    onDoneCallback: () => setState(() {
                                                          Navigator.of(context).pop();
                                                          _timerSeconds = durationPicker.getSeconds();
                                                        }),
                                                    onErrorCallback: () => setState(() {
                                                          Navigator.of(context).pop();
                                                          _status = Status.UNKNOWN;
                                                        }));
                                              }),
                                        ],
                                      ),
                                    );
                                  });
                            },
                    ),
                    Text(
                        '${Duration(seconds: _timerSeconds).inHours}:${Duration(seconds: _timerSeconds).inMinutes - Duration(seconds: _timerSeconds).inHours * 60}:${Duration(seconds: _timerSeconds - Duration(seconds: _timerSeconds).inMinutes * 60).inSeconds}')
                  ],
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
    _deviceNameFocusNode.dispose();
    _sh.destroySocket();
    _timer.cancel();
    super.dispose();
  }
}

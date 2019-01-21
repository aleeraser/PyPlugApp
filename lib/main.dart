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
  Timer _updateStatusTimer;

  Timer _countdownTimer;
  Commands _timerCommand;
  int __timerSeconds = 0;
  get _timerSeconds => __timerSeconds;
  set _timerSeconds(int seconds) {
    if (seconds < 0) {
      return;
    }

    if (_countdownTimer != null) {
      _countdownTimer.cancel();
    }

    if (seconds == 0) {
      setState(() {
        __timerSeconds = 0;
      });
      return;
    }

    __timerSeconds = seconds;

    _countdownTimer = Timer.periodic(Duration(seconds: 1), (timer) {
      if (_timerSeconds <= 0) {
        _countdownTimer.cancel();
        _timerCommand = null;
        return;
      }

      setState(() {
        __timerSeconds -= 1;
      });
    });
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

          _timerSeconds = int.parse(sData[3]);
          if (_timerSeconds >= 0) _timerCommand = sData[4] == 'ATON' ? Commands.ATON : Commands.ATOFF;

          _persistanceService.setString('ssid', sData[5]);
          _persistanceService.setString('password', sData[6]);

          debugPrint(sData.toString());
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
    if (_updateStatusTimer != null) {
      _updateStatusTimer.cancel();
      if (duration == Duration.zero) {
        return;
      }
    }

    _updateStatusTimer = Timer.periodic(duration, (timer) {
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

  Widget buildTimerCountdownLabel() {
    int hours = Duration(seconds: _timerSeconds).inHours;
    int minutes = Duration(seconds: _timerSeconds).inMinutes - Duration(seconds: _timerSeconds).inHours * 60;
    int seconds = Duration(seconds: _timerSeconds - Duration(seconds: _timerSeconds).inMinutes * 60).inSeconds;

    if (hours == 0 && minutes == 0 && seconds == 0) {
      return Container();
    } else {
      return Text('${hours < 10 ? '0' + hours.toString() : hours}:${minutes < 10 ? '0' + minutes.toString() : minutes}:${seconds < 10 ? '0' + seconds.toString() : seconds}');
    }
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
                    _persistanceService.setString('device_name', _deviceNameEditingController.text);

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
                          _persistanceService.setString('device_name', _deviceNameEditingController.text);

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
                                      data: Theme.of(context).copyWith(dialogBackgroundColor: COLOR_OFF, canvasColor: COLOR_OFF),
                                      child: AlertDialog(
                                        content: Column(
                                          mainAxisSize: MainAxisSize.min,
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: <Widget>[
                                            durationPicker,
                                            TimerCommandDropdown(
                                              timerCommand: _timerCommand,
                                              status: _status,
                                              onChanged: (val) => _timerCommand = val,
                                            )
                                          ],
                                        ),
                                        actions: <Widget>[
                                          FlatButton(
                                              child: Text('Close', style: TextStyle(color: Colors.blueGrey[200])),
                                              onPressed: () {
                                                Navigator.of(context).pop();
                                              }),
                                          _timerSeconds <= 0
                                              ? null
                                              : FlatButton(
                                                  child: Text(
                                                    'Delete current timer',
                                                    style: TextStyle(color: Colors.red[800]),
                                                  ),
                                                  onPressed: () {
                                                    _sh.send(
                                                        data: 'ATTIMER,DEL',
                                                        showMessages: true,
                                                        priority: Priority.HIGH,
                                                        onDoneCallback: () {
                                                          _countdownTimer.cancel();
                                                          _timerCommand = null;
                                                          _timerSeconds = 0;
                                                          Navigator.of(context).pop();
                                                        },
                                                        onErrorCallback: () => setState(() {
                                                              _status = Status.UNKNOWN;
                                                            }));
                                                  }),
                                          FlatButton(
                                              child: Text('Set'),
                                              onPressed: () {
                                                _sh.send(
                                                    data: 'ATTIMER,SET,${durationPicker.getSeconds()},${_timerCommand.toString().split('.')[1]}',
                                                    showMessages: true,
                                                    priority: Priority.HIGH,
                                                    onDoneCallback: () {
                                                      setState(() {
                                                        _timerSeconds = durationPicker.getSeconds();
                                                      });
                                                      Navigator.of(context).pop();
                                                    },
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
                    buildTimerCountdownLabel()
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
    _updateStatusTimer.cancel();
    super.dispose();
  }
}

class TimerCommandDropdown extends StatefulWidget {
  TimerCommandDropdown({
    Key key,
    @required this.timerCommand,
    @required this.status,
    @required this.onChanged,
  }) : super(key: key);

  final Commands timerCommand;
  final Status status;
  final Function onChanged;

  @override
  State<StatefulWidget> createState() => TimerCommandDropdownState(timerCommand);
}

class TimerCommandDropdownState extends State<TimerCommandDropdown> {
  TimerCommandDropdownState(this.timerCommand);

  Commands timerCommand;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: <Widget>[
        Text('Action to execute', style: TextStyle(color: Colors.blueGrey[200])),
        DropdownButton<Commands>(
          items: [
            DropdownMenuItem(
              child: Text('Turn off', style: TextStyle(color: Colors.blueGrey[200])),
              value: Commands.ATOFF,
            ),
            DropdownMenuItem(
              child: Text('Turn on', style: TextStyle(color: Colors.blueGrey[200])),
              value: Commands.ATON,
            ),
          ],
          value: timerCommand == null ? widget.status == Status.ON ? Commands.ATOFF : Commands.ATON : timerCommand,
          onChanged: (val) {
            if (widget.onChanged != null) widget.onChanged(val);
            setState(() {
              timerCommand = val;
            });
          },
        ),
      ],
    );
  }
}

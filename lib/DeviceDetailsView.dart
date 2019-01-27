import 'dart:async';

import 'package:audioplayers/audio_cache.dart';
import 'package:flutter/material.dart';

import 'Common.dart';
import 'CustomImageCircularButton.dart';
import 'DurationPicker.dart';
import 'MessageHandler.dart';
import 'PersistanceHandler.dart';
import 'SettingsView.dart';
import 'SocketHandler.dart';

class DeviceDetailsView extends StatefulWidget {
  final String deviceID;
  DeviceDetailsView({this.deviceID}) {
    final PersistanceHandler persistanceHandler = PersistanceHandler.getHandler();

    if (persistanceHandler.get(deviceID) == null) {
      persistanceHandler.setString(deviceID, '{}');
    }
  }

  @override
  _DeviceDetailsViewState createState() => _DeviceDetailsViewState(deviceID);
}

class _DeviceDetailsViewState extends State<DeviceDetailsView> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  final PersistanceHandler _persistanceHandler = PersistanceHandler.getHandler();

  final AudioCache audioPlayer = AudioCache();
  final String switchAudioPath = 'sounds/switch.mp3';

  final String deviceID;
  String _deviceAddress;
  int _devicePort;

  TextEditingController _deviceNameEditingController;
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

  final SocketHandler _sh = SocketHandler.getInstance();
  Timer _updateStatusTimer;

  Timer _countdownTimer;
  Commands _countdownTimerCommand = Commands.ATOFF;
  int __countdownTimerSeconds = -1;
  get _countdownTimerSeconds => __countdownTimerSeconds;
  set _countdownTimerSeconds(int seconds) {
    if (_countdownTimer != null) {
      _countdownTimer.cancel();
    }

    if (seconds < 0) {
      __countdownTimerSeconds = -1;
      _countdownTimerCommand = null;
      return;
    }

    __countdownTimerSeconds = seconds;

    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_countdownTimerSeconds < 0) {
        _countdownTimer.cancel();
        final Status targetStatus = _countdownTimerCommand == Commands.ATON ? Status.ON : Status.OFF;
        _countdownTimerCommand = null;
        _updateStatus(onDoneCallback: () {
          while (_status != targetStatus) {
            Timer.run(() {
              Future.delayed(const Duration(seconds: 1), () => _updateStatus());
            });
          }
          if (_status == targetStatus) {
            audioPlayer.play(switchAudioPath);
          }
        });
        return;
      }

      setState(() {
        __countdownTimerSeconds -= 1;
      });
    });
  }

  int __updateInterval;
  get _updateInterval => __updateInterval;
  set _updateInterval(int newInterval) {
    if (newInterval != _updateInterval) {
      __updateInterval = newInterval;
      _rescheduleUpdateTimer(Duration(seconds: _updateInterval));
      debugPrint(_updateInterval > 0 ? '(Re)scheduled periodic update routine every ${_updateInterval}s' : 'Periodic update routine canceled');
    }
  }

  _DeviceDetailsViewState(this.deviceID) {
    debugPrint('Opened details of device \'$deviceID\': ${_persistanceHandler.getString(deviceID).toString()}');
    if (_persistanceHandler.getFromDevice(deviceID, 'device_name') == null) {
      _persistanceHandler.setForDevice(deviceID, 'device_name', 'Socket Device');
    }
    _deviceNameEditingController = TextEditingController(text: _persistanceHandler.getFromDevice(deviceID, 'device_name'));
    _deviceAddress = _persistanceHandler.getFromDevice(deviceID, 'address');
    _devicePort = int.parse(_persistanceHandler.getFromDevice(deviceID, 'port'));

    String _refreshInterval = _persistanceHandler.getFromDevice(deviceID, 'refresh_interval');
    if (_refreshInterval != null) {
      _updateInterval = int.parse(_refreshInterval);
    } else {
      _persistanceHandler.setForDevice(deviceID, 'refresh_interval', '10');
      _updateInterval = DEFAULT_REFRESH_INTERVAL;
    }
  }

  void _navigateToSettings() {
    final Map<String, String> prevPrefValues =
        Map.fromIterable(_persistanceHandler.getDevice(deviceID).keys, key: (key) => key, value: (key) => _persistanceHandler.getFromDevice(deviceID, key));

    Navigator.of(context)
        .push(MaterialPageRoute(
            builder: (BuildContext context) => SettingsView(
                deviceID: deviceID,
                prevPrefValues: prevPrefValues,
                onUpdateIntervalChange: () => _updateInterval = int.parse(_persistanceHandler.getFromDevice(deviceID, 'refresh_interval')))))
        .then((returnedValue) {
      MessageHandler.getHandler().setScaffoldKey(_scaffoldKey);
    });
  }

  void _updateStatus({Function onDoneCallback, bool showLoading = true, bool showMessages = true, Priority priority = Priority.LOW, bool delayNext = true}) {
    // schedule next _updateStatus (if _updateInterval > 0). If _updateStatus was called
    // from outside the polling routine, this also delays the next status update in order
    // to avoid unnecessary repeated requests.
    if (delayNext) _rescheduleUpdateTimer(Duration(seconds: _updateInterval));

    if (showLoading) {
      setState(() {
        _statusText = 'Loading...';
        _status = Status.LOADING;
      });
    }

    _sh.send(
        address: _deviceAddress,
        port: _devicePort,
        data: 'ATALL',
        showMessages: showMessages,
        priority: priority,
        onDataCallback: (data) {
          final List<String> sData = String.fromCharCodes(data).split(',');
          try {
            _status = sData[0] == '1' ? Status.ON : Status.OFF;
            _statusText = 'Socket is ${_status == Status.ON ? 'on' : 'off'}';

            _current = sData[1];
            _power = sData[2];

            _countdownTimerSeconds = int.parse(sData[3]);
            if (_countdownTimerSeconds >= 0) _countdownTimerCommand = sData[4] == 'ATON' ? Commands.ATON : Commands.ATOFF;

            _persistanceHandler.setForDevice(deviceID, 'ssid', sData[5]);
            _persistanceHandler.setForDevice(deviceID, 'password', sData[6]);
          } catch (e) {
            debugPrint(e);
            setState(() {
              _status = Status.UNKNOWN;
            });
          }
        },
        onDoneCallback: () => setState(() {
              if (_status == Status.LOADING) {
                debugPrint('Warning: status was \'LOADING\'');
                _updateStatus(onDoneCallback: () {
                  if (_status == Status.LOADING) {
                    _status = Status.UNKNOWN;
                  }
                });
              }
              if (onDoneCallback != null) onDoneCallback();
            }),
        onErrorCallback: () => setState(() {
              _status = Status.UNKNOWN;
            }));
  }

  void _resetPowerStat({Function onDoneCallback}) {
    _sh.sendCommand(
        address: _deviceAddress,
        port: _devicePort,
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
        _updateStatus(showMessages: false, delayNext: false, showLoading: false);
      }
    });
  }

  bool canI() {
    // progressively add any blocking condition
    return _editingTitle == false;
  }

  Widget buildTimerCountdownLabel() {
    if (_countdownTimerSeconds < 0) {
      return Text('Timer');
    } else {
      int hours = Duration(seconds: _countdownTimerSeconds).inHours;
      int minutes = Duration(seconds: _countdownTimerSeconds).inMinutes - Duration(seconds: _countdownTimerSeconds).inHours * 60;
      int seconds = Duration(seconds: _countdownTimerSeconds - Duration(seconds: _countdownTimerSeconds).inMinutes * 60).inSeconds;
      return Text('${hours < 10 ? '0' + hours.toString() : hours}:${minutes < 10 ? '0' + minutes.toString() : minutes}:${seconds < 10 ? '0' + seconds.toString() : seconds}');
    }
  }

  @override
  void initState() {
    MessageHandler.getHandler().setScaffoldKey(_scaffoldKey);

    _deviceNameFocusNode = FocusNode();

    if (_status == Status.UNKNOWN) {
      _updateStatus(
          showLoading: true,
          onDoneCallback: () {
            debugPrint('Initial status: $_status');
          });
    }

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
                      _deviceNameEditingController.text = _persistanceHandler.getFromDevice(deviceID, 'device_name');
                    } else {
                      _persistanceHandler.setForDevice(deviceID, 'device_name', val);
                    }
                    setState(() {
                      _editingTitle = false;
                    });
                  },
                  onEditingComplete: () {
                    _persistanceHandler.setForDevice(deviceID, 'device_name', _deviceNameEditingController.text);

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
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: canI()
              ? () {
                  // close keyboard
                  FocusScope.of(context).requestFocus(new FocusNode());

                  Navigator.of(context).pop();
                }
              : null,
        ),
        actions: <Widget>[
          _editingTitle
              ? IconButton(
                  icon: const Icon(Icons.check),
                  onPressed: _deviceNameEditingController.text.length > 0
                      ? () {
                          _persistanceHandler.setForDevice(deviceID, 'device_name', _deviceNameEditingController.text);

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
                            _sh.sendCommand(
                                address: _deviceAddress,
                                port: _devicePort,
                                command: switchButtonCommand,
                                priority: Priority.HIGH,
                                onDoneCallback: () {
                                  audioPlayer.play(switchAudioPath);

                                  final Status _oldStatus = _status;

                                  _updateStatus(onDoneCallback: () {
                                    if (_oldStatus == _status) {
                                      MessageHandler.getHandler().showError('Error: inconsistent status');
                                    }
                                  });
                                },
                                onErrorCallback: () => setState(() {
                                      _status = Status.UNKNOWN;
                                    }));
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
                                    _countdownTimerCommand = Commands.ATOFF;
                                    return Theme(
                                      data: Theme.of(context).copyWith(dialogBackgroundColor: COLOR_OFF, canvasColor: COLOR_OFF),
                                      child: AlertDialog(
                                        content: Column(
                                          mainAxisSize: MainAxisSize.min,
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: <Widget>[
                                            durationPicker,
                                            TimerCommandDropdown(
                                              timerCommand: _countdownTimerCommand,
                                              onChanged: (val) => _countdownTimerCommand = val,
                                            )
                                          ],
                                        ),
                                        actions: <Widget>[
                                          FlatButton(
                                              child: Text('Close', style: TextStyle(color: Colors.blueGrey[200])),
                                              onPressed: () {
                                                Navigator.of(context).pop();
                                              }),
                                          _countdownTimerSeconds < 0
                                              ? null
                                              : FlatButton(
                                                  child: Text(
                                                    'Delete current timer',
                                                    style: TextStyle(color: Colors.red[800]),
                                                  ),
                                                  onPressed: () {
                                                    _sh.send(
                                                        address: _deviceAddress,
                                                        port: _devicePort,
                                                        data: 'ATTIMER,DEL',
                                                        showMessages: true,
                                                        priority: Priority.HIGH,
                                                        onDoneCallback: () {
                                                          _countdownTimer.cancel();
                                                          _countdownTimerCommand = null;
                                                          _countdownTimerSeconds = -1;
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
                                                    address: _deviceAddress,
                                                    port: _devicePort,
                                                    data: 'ATTIMER,SET,${durationPicker.getSeconds()},${_countdownTimerCommand.toString().split('.')[1]}',
                                                    showMessages: true,
                                                    priority: Priority.HIGH,
                                                    onDoneCallback: () {
                                                      setState(() {
                                                        _countdownTimerSeconds = durationPicker.getSeconds();
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
    @required this.onChanged,
  }) : super(key: key);

  final Commands timerCommand;
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
          value: timerCommand == null ? Commands.ATOFF : timerCommand,
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

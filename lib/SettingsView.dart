import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'MessageHandler.dart';
import 'PersistanceHandler.dart';
import 'SocketHandler.dart';

final Map<String, Object> preferences = Map();

class SettingsView extends StatefulWidget {
  final String deviceID;
  final Map<String, String> prevPrefValues;
  final Function onUpdateIntervalChange;

  SettingsView({@required this.prevPrefValues, @required this.deviceID, @required this.onUpdateIntervalChange}) : super();

  @override
  _SettingsViewState createState() => _SettingsViewState(prevPrefValues: prevPrefValues, deviceID: deviceID);
}

class _SettingsViewState extends State<SettingsView> {
  final Map<String, String> prevPrefValues;
  final String deviceID;
  final PersistanceHandler _persistanceHandler = PersistanceHandler.getHandler();
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  bool _saveEnabled = false;

  TextEditingController _ssidTextEditingController = new TextEditingController();
  TextEditingController _passwordTextEditingController = new TextEditingController();

  _SettingsViewState({@required this.prevPrefValues, @required this.deviceID}) : super();

  @override
  void initState() {
    MessageHandler.getHandler().setScaffoldKey(_scaffoldKey);
    _persistanceHandler.getDevice(deviceID).keys.forEach((key) => preferences[key] = _persistanceHandler.getFromDevice(deviceID, key));

    _ssidTextEditingController.text = preferences['ssid'];
    _passwordTextEditingController.text = preferences['password'];

    super.initState();
  }

  void _persistData() {
    preferences.keys.forEach((key) {
      _persistanceHandler.setForDevice(deviceID, key, preferences[key]);
    });

    // NOTE: check if you must/can do something while inside this view with the updated preferences

    String ssid = _persistanceHandler.getFromDevice(deviceID, 'ssid');
    String password = _persistanceHandler.getFromDevice(deviceID, 'password');
    if (prevPrefValues['ssid'] != ssid || prevPrefValues['password'] != password) {
      final SocketHandler _sh = SocketHandler.getInstance();

      _sh.send(
          data: 'ATNET,SET,${_persistanceHandler.getFromDevice(deviceID, 'ssid')},${_persistanceHandler.getFromDevice(deviceID, 'password')}',
          address: _persistanceHandler.getFromDevice(deviceID, 'address'),
          port: int.parse(_persistanceHandler.getFromDevice(deviceID, 'port')),
          showMessages: true,
          priority: Priority.HIGH,
          onDoneCallback: () => debugPrint('SSID and password updated.'),
          onErrorCallback: () {
            MessageHandler.getHandler().showError('Error');
          });
    }

    widget.onUpdateIntervalChange();

    setState(() {
      _saveEnabled = false;
    });

    // update preferences before returning
    prevPrefValues.clear();
    prevPrefValues.addAll(Map.fromIterable(_persistanceHandler.getDevice(deviceID).keys, key: (key) => key, value: (key) => _persistanceHandler.getFromDevice(deviceID, key)));
  }

  void _launchURL(String url) async {
    if (await canLaunch(url)) {
      await launch(url);
    } else {
      throw 'Could not launch $url';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        key: _scaffoldKey,
        resizeToAvoidBottomPadding: false,
        appBar: AppBar(
          title: const Text('Settings'),
          centerTitle: true,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () {
              // workaround for closing the keyboard
              FocusScope.of(context).requestFocus(new FocusNode());

              if (_saveEnabled) {
                showDialog(
                    context: context,
                    builder: (_) => AlertDialog(
                          title: const Text('Unsaved changes'),
                          content: const Text('Do you want to save your changes?'),
                          actions: <Widget>[
                            FlatButton(
                                child: Text('NO', style: TextStyle(color: Colors.red[800])),
                                onPressed: () {
                                  Navigator.of(context).pop();
                                  Navigator.of(context).pop();
                                }),
                            FlatButton(
                                child: const Text('YES'),
                                onPressed: () {
                                  _persistData();
                                  Navigator.of(context).pop();
                                  Navigator.of(context).pop();
                                }),
                          ],
                        ));
              } else {
                Navigator.of(context).pop();
              }
            },
          ),
          actions: <Widget>[
            IconButton(
              icon: const Icon(Icons.save),
              onPressed: _saveEnabled ? _persistData : null,
            ),
          ],
        ),
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            PreferenceHeader(text: 'Network'),
            PreferenceInputText(
              text: 'SSID',
              textEditingController: _ssidTextEditingController,
              hint: 'Enter SSID',
              preferenceKey: 'ssid',
              onChanged: (val) {
                preferences['ssid'] = val;
                setState(() {
                  _saveEnabled = true;
                });
              },
            ),
            PreferenceInputText(
              text: 'Password',
              textEditingController: _passwordTextEditingController,
              hint: 'Enter Password',
              preferenceKey: 'password',
              obscureText: true,
              onChanged: (val) {
                preferences['password'] = val;
                setState(() {
                  _saveEnabled = true;
                });
              },
            ),
            PreferenceText(
                textWidget: const Text('Warning: changing one of the values above will cause the device to be temporary unavailable for about 10s/20s.',
                    textScaleFactor: 1.1, textAlign: TextAlign.left, style: TextStyle(fontStyle: FontStyle.italic))),
            PreferenceHeader(text: 'Others'),
            PreferenceDropdownButton(
              text: 'Refresh Interval',
              items: [
                DropdownMenuItem(
                  value: '0',
                  child: const Text('Never'),
                ),
                DropdownMenuItem(
                  value: '5',
                  child: const Text('5 seconds'),
                ),
                DropdownMenuItem(
                  value: '10',
                  child: const Text('10 seconds'),
                ),
                DropdownMenuItem(
                  value: '30',
                  child: const Text('30 seconds'),
                )
              ],
              defaultValue: preferences['refresh_interval'],
              onChanged: (val) => setState(() {
                    if (val != preferences['refresh_interval']) {
                      preferences['refresh_interval'] = val;
                      _saveEnabled = true;
                    }
                  }),
            ),
            PreferenceHeader(
              text: 'Danger zone',
              textColor: Colors.red[700],
            ),
            PreferenceButton(
              text: 'Enter (Web)REPL mode',
              onPressed: () {
                showDialog(
                    context: context,
                    builder: (_) => AlertDialog(
                          title: const Text('Confirm'),
                          content: RichText(
                              text: TextSpan(children: <TextSpan>[
                            TextSpan(
                                text: 'Do you really want to enter (Web)REPL mode? You will be unable to use the device without rebooting it.\n\nFor further informations, visit the ',
                                style: TextStyle(color: Colors.black)),
                            TextSpan(
                              text: 'Micropython docs',
                              style: TextStyle(color: Colors.blue),
                              recognizer: TapGestureRecognizer()
                                ..onTap = () {
                                  _launchURL('https://docs.micropython.org/en/latest/esp8266/tutorial/repl.html');
                                },
                            ),
                            TextSpan(text: '.', style: TextStyle(color: Colors.black)),
                          ])),
                          actions: <Widget>[
                            FlatButton(
                                child: Text('NO'),
                                onPressed: () {
                                  Navigator.of(context).pop();
                                }),
                            FlatButton(
                                child: Text('YES', style: TextStyle(color: Colors.red[800])),
                                onPressed: () {
                                  final SocketHandler _sh = SocketHandler.getInstance();

                                  _sh.send(
                                      data: 'ATREPL',
                                      showMessages: true,
                                      priority: Priority.HIGH,
                                      onDoneCallback: () {
                                        debugPrint('Entered (Web)REPL mode.');
                                        Navigator.of(context).pop();
                                      },
                                      onErrorCallback: () {
                                        MessageHandler.getHandler().showError('Error');
                                      });
                                }),
                          ],
                        ));
              },
            ),
            PreferenceButton(
              text: 'Reboot device',
              onPressed: () {
                showDialog(
                    context: context,
                    builder: (_) => AlertDialog(
                          title: Text('Confirm'),
                          content: Text('Do you really want to reboot the device? Rebooting will take around 15s-20s.'),
                          actions: <Widget>[
                            FlatButton(
                                child: Text('NO'),
                                onPressed: () {
                                  Navigator.of(context).pop();
                                }),
                            FlatButton(
                                child: Text('YES', style: TextStyle(color: Colors.red[800])),
                                onPressed: () {
                                  final SocketHandler _sh = SocketHandler.getInstance();

                                  _sh.send(
                                      data: 'ATREBOOT',
                                      showMessages: true,
                                      priority: Priority.HIGH,
                                      onDoneCallback: () {
                                        debugPrint('Rebooted.');
                                        Navigator.of(context).pop();
                                      },
                                      onErrorCallback: () {
                                        MessageHandler.getHandler().showError('Error');
                                      });
                                }),
                          ],
                        ));
              },
            )
          ],
        ));
  }
}

class PreferenceButton extends StatelessWidget {
  final String text;
  final Function onPressed;
  final double width;
  final Color textColor;

  const PreferenceButton({Key key, @required this.text, @required this.onPressed, this.width, this.textColor}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 15.0),
      child: Center(
        child: Container(
          width: width != null ? width : MediaQuery.of(context).size.width * 1 / 2,
          child: MaterialButton(
            color: Colors.blueGrey[50],
            child: Text(text),
            textColor: textColor != null ? textColor : null,
            onPressed: onPressed,
          ),
        ),
      ),
    );
  }
}

class PreferenceDropdownButton extends StatelessWidget {
  const PreferenceDropdownButton({Key key, @required this.text, @required this.defaultValue, this.onChanged, @required this.items}) : super(key: key);

  final String text;
  final String defaultValue;
  final Function onChanged;
  final List<DropdownMenuItem> items;

  final double _horizontalPadding = 16.0;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: _horizontalPadding),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: <Widget>[
          Container(
              width: (MediaQuery.of(context).size.width - _horizontalPadding) * 3 / 6,
              child: Text(
                text,
                textScaleFactor: 1.2,
              )),
          Container(
            width: (MediaQuery.of(context).size.width - _horizontalPadding) * 2 / 6,
            child: DropdownButton(
              onChanged: (val) {
                if (onChanged != null) onChanged(val);
              },
              items: items,
              value: defaultValue,
            ),
          )
        ],
      ),
    );
  }
}

class PreferenceInputText extends StatelessWidget {
  PreferenceInputText({Key key, @required this.text, @required this.preferenceKey, @required this.textEditingController, this.hint, this.obscureText = false, this.onChanged})
      : super(key: key);

  final TextEditingController textEditingController;
  final Function onChanged;
  final String text;
  final String preferenceKey;
  final String hint;
  final bool obscureText;

  final double _horizontalPadding = 16.0;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: _horizontalPadding, vertical: 7),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: <Widget>[
          Container(
              width: (MediaQuery.of(context).size.width - _horizontalPadding) * 2 / 6,
              child: Text(
                text,
                textScaleFactor: 1.1,
              )),
          Container(
            width: (MediaQuery.of(context).size.width - _horizontalPadding) * 3 / 6,
            child: TextField(
              controller: textEditingController,
              textAlign: TextAlign.end,
              obscureText: obscureText,
              decoration: InputDecoration(border: InputBorder.none, hintText: hint),
              onChanged: (val) {
                if (onChanged != null) onChanged(val);
              },
              onSubmitted: (val) {
                // close keyboard
                FocusScope.of(context).requestFocus(new FocusNode());

                preferences[preferenceKey] = val;
              },
              onEditingComplete: () => preferences[preferenceKey] = textEditingController.text,
            ),
          )
        ],
      ),
    );
  }
}

class PreferenceText extends StatelessWidget {
  const PreferenceText({Key key, this.text, this.textWidget}) : super(key: key);

  final String text;
  final Text textWidget;

  @override
  Widget build(BuildContext context) {
    assert(text != null || textWidget != null);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
      child: textWidget != null ? textWidget : Text(text),
    );
  }
}

class PreferenceHeader extends StatelessWidget {
  const PreferenceHeader({
    Key key,
    @required this.text,
    this.textColor,
  }) : super(key: key);

  final String text;
  final Color textColor;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 10.0, bottom: 0.0, top: 20.0),
      child: Text(
        text,
        textAlign: TextAlign.left,
        style: TextStyle(color: textColor != null ? textColor : Colors.lightBlue[900], fontWeight: FontWeight.bold),
      ),
    );
  }
}

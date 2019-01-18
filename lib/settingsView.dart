import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'MessageHandler.dart';
import 'SocketHandler.dart';

final Map<String, Object> preferences = Map();

class SettingsView extends StatelessWidget {
  final Map<Object, Object> prevPrefValues;
  final SharedPreferences persistanceService;

  SettingsView({@required this.prevPrefValues, @required this.persistanceService}) : super() {
    // debugPrint('[start] prevPref: $prevPrefValues');

    persistanceService.getKeys().forEach((key) {
      var val = persistanceService.get(key);
      if (val is String) {
        preferences[key] = persistanceService.getString(key);
      } else if (val is int) {
        preferences[key] = persistanceService.getInt(key);
      } else if (val is double) {
        preferences[key] = persistanceService.getDouble(key);
      } else if (val is bool) {
        preferences[key] = persistanceService.getBool(key);
      }

      // debugPrint('[start] key: $key, val: ${preferences[key]}');
    });
  }

  void _clearPersistance() {
    preferences.keys.forEach((key) {
      debugPrint('[clear] key: $key, val: ${persistanceService.get(key)}');

      var val = preferences[key];
      if (val is String) {
        persistanceService.setString(key, null);
        preferences.remove(key);
      } else if (val is int) {
        persistanceService.setInt(key, null);
        preferences.remove(key);
      } else if (val is double) {
        persistanceService.setDouble(key, null);
        preferences.remove(key);
      } else if (val is bool) {
        persistanceService.setBool(key, null);
        preferences.remove(key);
      }
    });
    debugPrint('[start] preferences: $preferences');
    debugPrint('[start] persistanceService.getKeys(): ${persistanceService.getKeys()}');
  }

  void persistData() {
    debugPrint('[persist] prevPref: $prevPrefValues');

    preferences.keys.forEach((key) {
      var val = preferences[key];
      if (val is String) {
        persistanceService.setString(key, preferences[key]);
      } else if (val is int) {
        persistanceService.setInt(key, preferences[key]);
      } else if (val is double) {
        persistanceService.setDouble(key, preferences[key]);
      } else if (val is bool) {
        persistanceService.setBool(key, preferences[key]);
      }

      debugPrint('[persist] persistanceService.get($key): ${persistanceService.get(key)}');
    });

    // NOTE: check if you must/can do something while inside this view with the updated preferences

    String ssid = persistanceService.getString('ssid');
    String password = persistanceService.getString('password');
    if (prevPrefValues['ssid'] != ssid || prevPrefValues['password'] != password) {
      debugPrint('Must update ssid and/or password');
      SocketHandler _sh = SocketHandler();

      _sh.send(
          data: 'ATNET,${persistanceService.getString('ssid')},${persistanceService.getString('password')}',
          showMessages: true,
          priority: Priority.HIGH,
          onDoneCallback: () => debugPrint('SSID and password updated.'),
          onErrorCallback: () {
            MessageHandler.getHandler().showError('Error');
          });
    }

    // update preferences before returning
    prevPrefValues.clear();
    prevPrefValues.addAll(Map.fromIterable(persistanceService.getKeys(), key: (key) => key, value: (key) => persistanceService.get(key)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
          title: const Text('Settings'),
          centerTitle: true,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () {
              // workaround for closing the keyboard
              FocusScope.of(context).requestFocus(new FocusNode());

              persistData();

              // Navigator.of(context).pop(res);
              Navigator.of(context).pop();
            },
          ),
          actions: <Widget>[
            IconButton(
              icon: const Icon(Icons.save),
              onPressed: persistData,
            ),
          ],
        ),
        body: SettingsViewBody(
          currentRefreshInterval: preferences['refresh_interval'],
        ));
  }
}

class SettingsViewBody extends StatefulWidget {
  final String currentRefreshInterval;

  SettingsViewBody({this.currentRefreshInterval}) : super();

  @override
  _SettingsViewBodyState createState() => _SettingsViewBodyState(currentRefreshInterval: currentRefreshInterval);
}

class _SettingsViewBodyState extends State<SettingsViewBody> {
  final TextStyle headerStyle = TextStyle(color: Colors.lightBlue[900], fontWeight: FontWeight.bold);
  String currentRefreshInterval;

  TextEditingController _ssidTextEditingController = new TextEditingController();
  TextEditingController _passwordTextEditingController = new TextEditingController();

  _SettingsViewBodyState({this.currentRefreshInterval}) : super() {
    _ssidTextEditingController.text = preferences['ssid'];
    _passwordTextEditingController.text = preferences['password'];
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        PreferencesHeader(text: 'Network', headerStyle: headerStyle),
        PreferencesInputText(
          text: 'SSID',
          textEditingController: _ssidTextEditingController,
          hint: 'Enter SSID',
          preferenceKey: 'ssid',
        ),
        PreferencesInputText(
          text: 'Password',
          textEditingController: _passwordTextEditingController,
          hint: 'Enter Password',
          preferenceKey: 'password',
          obscureText: true,
        ),
        PreferencesText('Warning: changing one of the values above will cause the socket to reboot and be temporary unavailable for about 10s/20s.'),
        PreferencesHeader(text: 'Others', headerStyle: headerStyle),
        PreferencesDropdownButton(
          currentRefreshInterval: currentRefreshInterval,
          onChanged: (val) => setState(() {
                currentRefreshInterval = val;
              }),
        )
      ],
    );
  }
}

class PreferencesDropdownButton extends StatelessWidget {
  const PreferencesDropdownButton({Key key, @required this.currentRefreshInterval, this.onChanged}) : super(key: key);

  final String currentRefreshInterval;
  final Function onChanged;

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
                'Refresh Interval',
                textScaleFactor: 1.2,
              )),
          Container(
            width: (MediaQuery.of(context).size.width - _horizontalPadding) * 2 / 6,
            child: DropdownButton(
              onChanged: (val) {
                preferences['refresh_interval'] = val;
                if (onChanged != null) onChanged(val);
              },
              items: [
                DropdownMenuItem(
                  value: '0',
                  child: Text('Never'),
                ),
                DropdownMenuItem(
                  value: '5',
                  child: Text('5 seconds'),
                ),
                DropdownMenuItem(
                  value: '10',
                  child: Text('10 seconds'),
                ),
                DropdownMenuItem(
                  value: '30',
                  child: Text('30 seconds'),
                )
              ],
              value: currentRefreshInterval,
            ),
          )
        ],
      ),
    );
  }
}

class PreferencesInputText extends StatelessWidget {
  PreferencesInputText({Key key, @required this.text, @required this.preferenceKey, @required this.textEditingController, this.hint, this.obscureText = false}) : super(key: key);

  final TextEditingController textEditingController;
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
              onChanged: (val) => preferences[preferenceKey] = val,
              onSubmitted: (val) => preferences[preferenceKey] = val,
              onEditingComplete: () => preferences[preferenceKey] = textEditingController.text,
            ),
          )
        ],
      ),
    );
  }
}

class PreferencesText extends StatelessWidget {
  const PreferencesText(this.text, {Key key}) : super(key: key);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
      child: Text(text, textScaleFactor: 1.1, textAlign: TextAlign.left, style: TextStyle(fontStyle: FontStyle.italic)),
    );
  }
}

class PreferencesHeader extends StatelessWidget {
  const PreferencesHeader({
    Key key,
    @required this.headerStyle,
    @required this.text,
  }) : super(key: key);

  final TextStyle headerStyle;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 10.0, bottom: 0.0, top: 20.0),
      child: Text(
        text,
        textAlign: TextAlign.left,
        style: headerStyle,
        // textScaleFactor: 1.1,
      ),
    );
  }
}

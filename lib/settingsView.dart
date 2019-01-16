import 'package:flutter/material.dart';
import 'package:preferences/preferences.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'MessageHandler.dart';
import 'PreferenceInputText.dart';
import 'SocketHandler.dart';

class SettingsView extends StatelessWidget {
  final Map<Object, Object> prevPrefValues;
  final SharedPreferences persistanceService;

  SettingsView({@required this.prevPrefValues, @required this.persistanceService}) : super() {
    debugPrint('prevPref: $prevPrefValues');
  }

  void _clearPersistance() {
    PrefService.getKeys().forEach((key) {
      debugPrint('key: $key, val: ${persistanceService.get(key)}');

      var val = PrefService.get(key);
      if (val is String) {
        persistanceService.setString(key, null);
        PrefService.setString(key, null);
      } else if (val is int) {
        persistanceService.setInt(key, null);
        PrefService.setInt(key, null);
      } else if (val is double) {
        persistanceService.setDouble(key, null);
        PrefService.setDouble(key, null);
      } else if (val is bool) {
        persistanceService.setBool(key, null);
        PrefService.setBool(key, null);
      }
    });
  }

  void persistData() {
    debugPrint('prevPref: $prevPrefValues');

    PrefService.getKeys().forEach((key) {
      var val = PrefService.get(key);
      if (val is String) {
        persistanceService.setString(key, PrefService.getString(key));
      } else if (val is int) {
        persistanceService.setInt(key, PrefService.getInt(key));
      } else if (val is double) {
        persistanceService.setDouble(key, PrefService.getDouble(key));
      } else if (val is bool) {
        persistanceService.setBool(key, PrefService.getBool(key));
      }

      debugPrint('key: $key, val: ${persistanceService.get(key)}');
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
              persistData();

              // workaround for closing the keyboard
              FocusScope.of(context).requestFocus(new FocusNode());

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
          currentRefreshInterval: persistanceService.getString('refresh_interval'),
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
  final String currentRefreshInterval;

  _SettingsViewBodyState({this.currentRefreshInterval}) : super();

  @override
  Widget build(BuildContext context) {
    return PreferencePage([
      PreferenceTitle(
        'Network',
        style: headerStyle,
      ),
      PreferenceInputText(
        'SSID',
        'ssid',
        hint: 'Enter SSID',
        // onSubmitted: (val) => res['ssid'] = val,
      ),
      PreferenceInputText(
        'Password',
        'password',
        hint: 'Enter password',
        obscureText: true,
        // onSubmitted: (val) => res['password'] = val,
      ),
      PreferenceText(
        'Warning: changing one of the values above will cause the socket to reboot and be temporary unavailable for about 10s/20s.',
        style: TextStyle(fontStyle: FontStyle.italic),
      ),
      PreferenceTitle(
        'Others',
        style: headerStyle,
      ),
      DropdownPreference(
        'Refresh Interval (seconds)',
        'refresh_interval',
        desc: '\'0\' means disabled',
        defaultVal: currentRefreshInterval,
        values: ['0', '5', '10', '30'],
        // onChange: (val) => PrefService.setInt('refresh_interval', INTERVAL_MAP[val]),
        // onChange: (val) => res['refresh_interval'] = val,
        // onChange: (val) {
        //   switch (val) {
        //     case 'Never':
        //       res['interval'] = -1;
        //       break;
        //     case '5s':
        //       res['interval'] = 5;
        //       break;
        //     case '10s':
        //       res['interval'] = 10;
        //       break;
        //     case '30s':
        //       res['interval'] = 30;
        //       break;
        //     default:
        //       throw Exception('Unhandled interval value $val.');
        //   }
        // },
      ),
    ]);
  }
}

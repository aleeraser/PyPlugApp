import 'package:flutter/material.dart';
import 'package:preferences/preferences.dart';

import 'MessageHandler.dart';
import 'PreferenceInputText.dart';
import 'SocketHandler.dart';

class SettingsView extends StatelessWidget {
  final Map<Object, Object> prevPrefValues;

  SettingsView({Key key, @required this.prevPrefValues}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
          title: const Text('Settings'),
          centerTitle: true,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () {
              FocusScope.of(context).requestFocus(new FocusNode());
              // Navigator.of(context).pop(res);
              Navigator.of(context).pop();
            },
          ),
          actions: <Widget>[
            IconButton(
              icon: const Icon(Icons.save),
              onPressed: () {
                // NOTE: check if you must/can do something while inside this view with the other updated preferences

                String ssid = PrefService.getString('ssid');
                String password = PrefService.getString('password');
                if (prevPrefValues['ssid'] != ssid || prevPrefValues['password'] != password) {
                  debugPrint('Must updated ssid and/or password');
                  SocketHandler _sh = SocketHandler();

                  _sh.send(
                      data: 'ATNET,${PrefService.getString('ssid')},${PrefService.getString('password')}',
                      showMessages: true,
                      priority: Priority.HIGH,
                      onDoneCallback: () => debugPrint('SSID and password updated.'),
                      onErrorCallback: () {
                        MessageHandler.getHandler().showError('Error');
                      });
                }
              },
            ),
          ],
        ),
        body: SettingsViewBody());
  }
}

class SettingsViewBody extends StatefulWidget {
  @override
  _SettingsViewBodyState createState() => _SettingsViewBodyState();
}

class _SettingsViewBodyState extends State<SettingsViewBody> {
  @override
  Widget build(BuildContext context) {
    return PreferencePage([
      PreferenceTitle('Network'),
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
        'Warning: changing one of the values above will cause the socket to reboot and be temporary unavailable for about 5s/10s.',
        style: TextStyle(fontStyle: FontStyle.italic),
      ),
      PreferenceTitle('Others'),
      DropdownPreference(
        'Refresh Interval',
        'refresh_interval',
        defaultVal: '5s',
        values: ['Never', '5s', '10s', '30s'],
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

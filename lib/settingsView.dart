import 'package:flutter/material.dart';
import 'package:preferences/preferences.dart';

import 'PreferenceInputText.dart';

// final Map<Object, Object> res = {};

class SettingsView extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    // res.clear();

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
        // onSubmitted: (val) => res['psw'] = val,
      ),
      PreferenceTitle('Others'),
      DropdownPreference(
        'Refresh Interval',
        'refresh_interval',
        defaultVal: '5s',
        values: ['Never', '5s', '10s', '30s'],
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

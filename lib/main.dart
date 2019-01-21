import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'DeviceDetailsView.dart';

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
      home: DeviceDetailsView(_persistanceService),
    );
  }
}

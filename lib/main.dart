import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'Common.dart';
import 'DevicesListView.dart';
import 'DeviceDetailsView.dart';
import 'SettingsView.dart';
import 'PersistanceHandler.dart';

main() {
  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]).whenComplete(() {
    PersistanceHandler.getHandler().init().whenComplete(() {
      // debugPrint(PersistanceHandler.getHandler().getKeys().toString());

      // PersistanceHandler.getHandler().clear();
      // PersistanceHandler.getHandler().setForDevice('30:ae:a4:bf:39:68', 'address', '192.168.1.8');
      // PersistanceHandler.getHandler().setForDevice('30:ae:a4:bf:39:68', 'port', '8888');
      // PersistanceHandler.getHandler().setForDevice('30:ae:a4:bf:39:68', 'device_name', 'Hell yeah');
      // PersistanceHandler.getHandler().setForDevice('30:ae:a4:bf:39:68', 'refresh_interval', '0');
      // PersistanceHandler.getHandler().setForDevice('30:ae:a4:bf:39:68', 'ssid', 'HoLaCaccaWiFi');
      // PersistanceHandler.getHandler().setForDevice('30:ae:a4:bf:39:68', 'password', 'ciaociao');

      runApp(MyApp());
    });
  });
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Smart Socket',
      theme: ThemeData(
        primaryColor: COLOR_OFF,
      ),
      home: DevicesListView(),
      // home: DeviceDetailsView(
      //   deviceID: '30:ae:a4:bf:39:68',
      // ),
      // home: SettingsView(
      //   deviceID: '30:ae:a4:bf:39:68',
      //   prevPrefValues: {'address': '192.168.1.8', 'port': '8888', 'device_name': 'Hell yeah', 'refresh_interval': '0', 'ssid': 'HoLaCaccaWiFi', 'password': 'ciaociao'},
      // ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'Common.dart';
import 'DevicesListView.dart';
import 'PersistanceHandler.dart';

main() {
  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]).whenComplete(() {
    PersistanceHandler.getHandler().init().whenComplete(() {
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
    );
  }
}

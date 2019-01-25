import 'package:flutter/material.dart';

import 'Common.dart';
import 'DevicesListView.dart';
import 'PersistanceHandler.dart';

main() {
  PersistanceHandler.getHandler().init();
  // ..whenComplete(() {
  //   debugPrint(PersistanceHandler.getHandler().getKeys().toString());
  // });
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
      home: DevicesListView(),
      // home: Text('CACCA'),
    );
  }
}

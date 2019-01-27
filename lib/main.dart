import 'package:flutter/foundation.dart';
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

  LicenseRegistry.addLicense(() {
    return Stream<LicenseEntry>.fromIterable(<LicenseEntry>[
      const LicenseEntryWithLineBreaks(<String>[
        'PyPlug'
      ], 'Copyright @ 2019 Alessandro Zini, Mattia Maldini.\n\nLicensed under the GNU General Public License v3.0.\n\nYou may obtain a copy of the license at\n\n\thttps://www.gnu.org/licenses/gpl-3.0.html')
    ]);
  });
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Smart Socket',
      theme: ThemeData(primaryColor: COLOR_OFF, accentColor: Colors.lightBlue[900]),
      home: DevicesListView(),
    );
  }
}

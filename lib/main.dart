import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'settingsView.dart';
import 'customImageButton.dart';

void main() => runApp(MyApp());

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Smart Socket',
      theme: ThemeData(
        primaryColor: Color.fromARGB(255, 0, 51, 50),
      ),
      home: SocketHomePage(),
    );
  }
}

class SocketHomePage extends StatefulWidget {
  @override
  _SocketHomePageState createState() => _SocketHomePageState();
}

class _SocketHomePageState extends State<SocketHomePage> {
  // String _socketStatus = 'Socket is off';
  bool _status = false;
  var _assetImage = AssetImage("assets/images/btn_off.png");
  var _image = new Image(image: AssetImage("assets/images/btn_off.png"));
  var _bgColor = new Color.fromARGB(255, 49, 58, 73);

  void _navigateToSettings() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (BuildContext context) {
          return SettingsView().build(context);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Smart Socket'),
        centerTitle: true,
        actions: <Widget>[
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: _navigateToSettings,
          ),
        ],
      ),
      body: new Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            CustomImageButton(
                assetImage: _assetImage,
                onTap: () {
                  setState(() {
                    _status = !_status;
                    if (_status) {
                      _assetImage = new AssetImage("assets/images/btn_on.png");
                      _bgColor = Colors.white;
                    } else {
                      _assetImage = new AssetImage("assets/images/btn_off.png");
                      _bgColor = new Color.fromARGB(255, 49, 58, 73);
                    }
                  });
                }),
            Text("data")
          ],
        ),
      ),
      backgroundColor: _bgColor,
    );
  }
}

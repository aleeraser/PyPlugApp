import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;

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
  var _image = new Image(image: AssetImage("assets/images/btn_off.png"));
  var _bgColor = new Color.fromARGB(255, 49, 58, 73);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Smart Socket'),
        centerTitle: true,
      ),
      body: new Center(
        child: new FlatButton(
          highlightColor: Colors.transparent,
          splashColor: Colors.transparent,
          onPressed: () {
            setState(() {
              _status = !_status;
              if (_status) {
                _image = new Image(image: AssetImage("assets/images/btn_on.png"));
                _bgColor = Colors.white;
              } else {
                _image = new Image(image: AssetImage("assets/images/btn_off.png"));
                _bgColor = new Color.fromARGB(255, 49, 58, 73);
              }
            });
          },
          child: new ConstrainedBox(
            constraints: new BoxConstraints.expand(),
            child: _image,
          ),
        ),
      ),
      backgroundColor: _bgColor,
    );
  }
}

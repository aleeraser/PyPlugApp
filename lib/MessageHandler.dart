import 'package:flutter/material.dart';

class MessageHandler {
  static final MessageHandler _mg = MessageHandler._internal();

  GlobalKey<ScaffoldState> _scaffoldKey;

  MessageHandler._internal();

  factory MessageHandler() {
    return _mg;
  }

  static MessageHandler getHandler() {
    return _mg;
  }

  void setScaffoldKey(GlobalKey<ScaffoldState> scaffoldKey) {
    _scaffoldKey = scaffoldKey;
  }

  void showError(String msg) {
    showMessage(msg, error: true);
  }

  void showMessage(String msg, {bool error = false}) {
    if (_scaffoldKey == null) {
      throw Exception('You must first set a Key for the Scaffold state. Use \'MessageHandler.getHandler().setScaffoldKey(key)\' method.');
    }
    _scaffoldKey.currentState.showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: error ? Colors.red[900] : Colors.grey[850],
      action: SnackBarAction(
        label: 'CLOSE',
        textColor: Colors.white,
        onPressed: () => _scaffoldKey.currentState.removeCurrentSnackBar(reason: SnackBarClosedReason.remove),
      ),
    ));
  }
}

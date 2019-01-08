import 'package:flutter/material.dart';

/**
 * ciao
 */
class SettingsView extends StatelessWidget {
  // SettingsView(this._savedPairs);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
          title: const Text('Settings'),
        ),
        body: new Center(
          child: Text("Many settings here."),
        ));
  }
}

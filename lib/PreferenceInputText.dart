import 'package:flutter/material.dart';
import 'package:preferences/preference_service.dart';

class PreferenceInputText extends StatefulWidget {
  final String title;
  final String desc;
  final String hint;
  final String localKey;
  final bool obscureText;

  final Function onSubmitted;

  PreferenceInputText(this.title, this.localKey, {this.desc, this.hint, this.onSubmitted, this.obscureText = false});

  _PreferenceInputTextState createState() => _PreferenceInputTextState();
}

class _PreferenceInputTextState extends State<PreferenceInputText> {
  TextEditingController _textEditingController = new TextEditingController();

  @override
  Widget build(BuildContext context) {
    _textEditingController.text = PrefService.getString(widget.localKey);
    return ListTile(
      title: Text(widget.title),
      subtitle: widget.desc == null ? null : Text(widget.desc),
      trailing: Container(
        width: MediaQuery.of(context).size.width * 1/2,
        child: TextField(
          controller: _textEditingController,
          textAlign: TextAlign.end,
          obscureText: widget.obscureText,
          decoration: InputDecoration(border: InputBorder.none, hintText: widget.hint),
          onSubmitted: (data) {
            PrefService.setString(widget.localKey, data);
            if (widget.onSubmitted != null) widget.onSubmitted(data);
          },
        ),
      ),
    );
  }
}

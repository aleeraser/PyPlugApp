import 'package:flutter/material.dart';

class DurationPicker extends StatefulWidget {
  DurationPicker({
    Key key,
    this.darkTheme,
  }) : super(key: key);

  final bool darkTheme;
  final Map<String, Map<String, int>> _values = {
    'h': {'val': 0, 'count': 0},
    'm': {'val': 0, 'count': 0},
    's': {'val': 0, 'count': 0},
  };

  int getSeconds() {
    return _values['s']['val'] + _values['m']['val'] * 60 + _values['h']['val'] * 60 * 60;
  }

  @override
  DurationPickerState createState() => DurationPickerState();
}

class DurationPickerState extends State<DurationPicker> {
  String _toEdit = 's';

  final TextStyle _selectedStyle = TextStyle(color: Colors.teal[300]);

  final _digitButtonHeight = 60.0;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height / 2,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: <Widget>[
          Column(
            children: <Widget>[
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: <Widget>[
                  _buildTimerVal('h'),
                  _buildTimerVal(':'),
                  _buildTimerVal('m'),
                  _buildTimerVal(':'),
                  _buildTimerVal('s'),
                ],
              ),
            ],
          ),
          Padding(
            padding: EdgeInsets.only(top: 30),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                _buildTimerDigit('1'),
                _buildTimerDigit('2'),
                _buildTimerDigit('3'),
              ],
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              _buildTimerDigit('4'),
              _buildTimerDigit('5'),
              _buildTimerDigit('6'),
            ],
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              _buildTimerDigit('7'),
              _buildTimerDigit('8'),
              _buildTimerDigit('9'),
            ],
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: <Widget>[
              _buildTimerDigit('0'),
              MaterialButton(
                height: _digitButtonHeight,
                // highlightColor: Colors.transparent,
                // splashColor: Colors.transparent,
                child: Icon(Icons.backspace, color: Colors.blueGrey[100]),
                onPressed: () {
                  int val = widget._values[_toEdit]['val'];
                  int count = widget._values[_toEdit]['count'];

                  if (count == 0) return;

                  int newVal = count == 0 ? 0 : (val / 10).truncate();

                  widget._values[_toEdit]['count'] -= 1;

                  setState(() {
                    widget._values[_toEdit]['val'] = newVal;
                  });
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTimerVal(String unit) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: unit == ':'
          ? <Widget>[Text(unit, textScaleFactor: 3, style: TextStyle(color: Colors.blueGrey[100])), Text('')]
          : <Widget>[
              GestureDetector(
                onTap: () => setState(() {
                      _toEdit = unit;
                    }),
                child: Text(
                  0 <= widget._values[unit]['val'] && widget._values[unit]['val'] < 10 ? '0${widget._values[unit]['val']}' : widget._values[unit]['val'].toString(),
                  textAlign: TextAlign.center,
                  textScaleFactor: 4,
                  style: _toEdit == unit ? _selectedStyle : TextStyle(color: Colors.blueGrey[100]),
                ),
              ),
              Text(unit.toUpperCase(), style: TextStyle(color: Colors.grey[700]))
            ],
    );
  }

  MaterialButton _buildTimerDigit(String digit) {
    return MaterialButton(
      height: _digitButtonHeight,
      // highlightColor: Colors.transparent,
      // splashColor: Colors.transparent,
      child: Text(digit, textScaleFactor: 1.4, style: TextStyle(color: Colors.blueGrey[100])),
      onPressed: () {
        int val = widget._values[_toEdit]['val'];
        int count = widget._values[_toEdit]['count'];

        if (count == 2) return;

        int newVal = count == 0 ? int.parse(digit) : int.parse(digit) + val * 10;

        if (_toEdit != 'h' && newVal >= 60) return;

        widget._values[_toEdit]['count'] += 1;

        setState(() {
          widget._values[_toEdit]['val'] = newVal;
        });
      },
    );
  }
}

import 'package:flutter/material.dart';
import 'package:meta/meta.dart';

// Thanks to https://stackoverflow.com/questions/53641053/create-a-button-with-an-image-in-flutter

class CustomImageButton extends StatelessWidget {
  final AssetImage assetImage;
  final Function onTap;

  CustomImageButton({@required this.assetImage, @required this.onTap});

  @override
  Widget build(BuildContext context) {

    return Container(
      child: ConstrainedBox(
        constraints: BoxConstraints.tightFor(height: 300),
        child: Ink.image(
          image: assetImage,
          fit: BoxFit.fitWidth,
          child: InkWell(
            highlightColor: Colors.transparent,
            splashColor: Colors.transparent,
            onTap: onTap,
          ),
        ),
      ),
    );

    // new FloatingActionButton(
    //   isExtended: true,
    //   onPressed: () {
    //     setState(() {
    //       _status = !_status;
    //       if (_status) {
    //         _image = new Image(image: AssetImage("assets/images/btn_on.png"));
    //         _bgColor = Colors.white;
    //       } else {
    //         _image = new Image(image: AssetImage("assets/images/btn_off.png"));
    //         _bgColor = new Color.fromARGB(255, 49, 58, 73);
    //       }
    //     });
    //   },
    //   child: new ConstrainedBox(
    //     constraints: new BoxConstraints.expand(),
    //     child: _image,
    //   ),
    // ),
  }
}

import 'package:flutter/material.dart';
import 'package:meta/meta.dart';

// Thanks to https://stackoverflow.com/questions/53641053/create-a-button-with-an-image-in-flutter

class CustomImageButton extends StatelessWidget {
  final AssetImage assetImage;
  final Function onTap;

  CustomImageButton({@required this.assetImage, @required this.onTap});

  // TODO: the button is rectangular shaped even if the image is circular. Make the 'tappable-area' circular too.

  @override
  Widget build(BuildContext context) {
    // return Container(
    //   child: ConstrainedBox(
    //     constraints: BoxConstraints.tightFor(height: 300),
    //     child: Ink.image(
    //       // padding: EdgeInsets.symmetric(horizontal: 60.0),
    //       image: assetImage,
    //       fit: BoxFit.fitWidth,
    //       child: InkWell(
    //         highlightColor: Colors.transparent,
    //         splashColor: Colors.transparent,
    //         onTap: onTap,
    //       ),
    //     ),
    //   ),
    // );

    // Using a FloatingActionButton since it is naturally a circle.
    return Container(
        width: double.infinity,
        child: FittedBox(
            child: FloatingActionButton(
                onPressed: null, // tap is handled below
                backgroundColor: Colors.transparent,
                elevation: 0, // grounded
                child: Container(
                  child: Ink.image(
                    // padding: EdgeInsets.symmetric(horizontal: 60.0),
                    image: assetImage,
                    fit: BoxFit.fitWidth,
                    child: InkWell(
                      highlightColor: Colors.transparent,
                      splashColor: Colors.transparent,
                      onTap: onTap,
                    ),
                  ),
                ))));
  }
}

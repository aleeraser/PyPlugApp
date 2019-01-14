import 'package:flutter/material.dart';
import 'package:meta/meta.dart';

class CustomImageCircularButton extends StatelessWidget {
  final AssetImage assetImage;
  final Function onTap;
  final double sideLength;

  CustomImageCircularButton({@required this.assetImage, @required this.onTap, this.sideLength});

  @override
  Widget build(BuildContext context) {
    // Using a FloatingActionButton instead since it is naturally a circle.
    return Ink.image(
      image: assetImage,
      fit: BoxFit.fitWidth,
      child: ClipOval(
        child: Container(
          width: this.sideLength,
          height: this.sideLength,
          child: GestureDetector(
            onTap: onTap,
          ),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';

class SpendWiseDoodle extends StatelessWidget {
  final double height;
  
  const SpendWiseDoodle({super.key, this.height = 40});

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      'assets/doodle.png', // Your custom drawn text logo
      height: height,
      fit: BoxFit.contain,
    );
  }
}
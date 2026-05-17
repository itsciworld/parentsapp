import 'package:flutter/material.dart';

class AppBackButton extends StatelessWidget {
  final Color? color;
  final double size;

  const AppBackButton({super.key, this.color, this.size = 24});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () {
        if (Navigator.canPop(context)) {
          Navigator.pop(context);
        }
      },
      borderRadius: BorderRadius.circular(50),
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Icon(
          Icons.arrow_back_ios_new_rounded,
          size: size,
          color: Colors.black,
        ),
      ),
    );
  }
}

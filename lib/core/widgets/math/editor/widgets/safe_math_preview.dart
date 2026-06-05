import 'package:flutter/material.dart';
import 'package:easy_latex/easy_latex.dart';

class SafeMathPreview extends StatelessWidget {
  final String latex;
  final Color textColor;
  final double mathSize;

  const SafeMathPreview({
    super.key,
    required this.latex,
    required this.textColor,
    this.mathSize = 18,
  });

  @override
  Widget build(BuildContext context) {
    if (latex.isEmpty) {
      return Text(
        'اكتب معادلة رياضية...',
        style: TextStyle(
          color: textColor.withOpacity(0.4),
          fontSize: 14,
          fontStyle: FontStyle.italic,
        ),
      );
    }

    try {
      return EasyLatex(
        latex,
        mathStyle: const TextStyle(fontSize: 18), // We'll keep it consistent
      );
    } catch (e) {
      return Text(
        latex,
        style: TextStyle(color: textColor, fontSize: mathSize),
      );
    }
  }
}

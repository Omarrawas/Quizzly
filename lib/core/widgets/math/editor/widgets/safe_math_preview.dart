import 'package:flutter/material.dart';
import 'package:flutter_math_fork/flutter_math.dart' as math_fork;

/// Inline math preview widget used inside the RichTextEditor embed.
/// Uses flutter_math_fork (same renderer as the QuizzlyMathEditor)
/// to guarantee consistent rendering between editing and display.
class SafeMathPreview extends StatelessWidget {
  final String latex;
  final Color textColor;
  final double mathSize;
  final TextDirection? textDirection;

  const SafeMathPreview({
    super.key,
    required this.latex,
    required this.textColor,
    this.mathSize = 18,
    this.textDirection,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveDirection = textDirection ?? TextDirection.ltr;

    if (latex.isEmpty) {
      return Text(
        'معادلة...',
        style: TextStyle(
          color: textColor.withValues(alpha: 0.4),
          fontSize: 14,
          fontStyle: FontStyle.italic,
        ),
        textDirection: effectiveDirection,
      );
    }

    return Directionality(
      textDirection: effectiveDirection,
      child: math_fork.Math.tex(
        latex,
        textStyle: TextStyle(fontSize: mathSize, color: textColor),
        onErrorFallback: (err) => Text(
          latex,
          style: TextStyle(
            color: textColor.withValues(alpha: 0.7),
            fontSize: mathSize * 0.8,
            fontFamily: 'monospace',
          ),
          textDirection: effectiveDirection,
        ),
      ),
    );
  }
}

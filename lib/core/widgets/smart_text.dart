import 'package:flutter/material.dart';
import 'package:flutter_math_fork/flutter_math.dart';
import 'package:google_fonts/google_fonts.dart';

class SmartText extends StatelessWidget {
  final String text;
  final TextStyle? style;
  final TextAlign textAlign;
  final Color? mathColor;

  const SmartText({
    super.key,
    required this.text,
    this.style,
    this.textAlign = TextAlign.right,
    this.mathColor,
  });

  @override
  Widget build(BuildContext context) {
    // استخدام r قبل النص لضمان عدم حدوث Interpolation
    final RegExp regex = RegExp(r'(\$\$.*?\$\$|\$.*?\$)');
    final List<String> parts = text.split(regex);
    final List<RegExpMatch> matches = regex.allMatches(text).toList();

    if (matches.isEmpty) {
      return Text(
        text,
        style: style ?? GoogleFonts.cairo(),
        textAlign: textAlign,
      );
    }

    final List<InlineSpan> spans = [];

    for (int i = 0; i < parts.length; i++) {
      final String part = parts[i];
      if (part.isNotEmpty) {
        spans.add(TextSpan(
          text: part,
          style: style ?? GoogleFonts.cairo(),
        ));
      }

      if (i < matches.length) {
        final RegExpMatch match = matches[i];
        final String? fullMatch = match.group(0);
        
        if (fullMatch != null) {
          // استخدام r'$$' لتجنب مشاكل الرموز الخاصة
          final bool isDisplayMode = fullMatch.startsWith(r'$$');
          final String mathContent = isDisplayMode 
              ? fullMatch.substring(2, fullMatch.length - 2)
              : fullMatch.substring(1, fullMatch.length - 1);

          spans.add(WidgetSpan(
            alignment: PlaceholderAlignment.middle,
            child: Padding(
              padding: EdgeInsets.symmetric(
                vertical: isDisplayMode ? 12 : 0,
                horizontal: 4,
              ),
              child: Math.tex(
                mathContent,
                textStyle: (style ?? GoogleFonts.cairo()).copyWith(
                  color: mathColor ?? style?.color,
                  fontSize: (style?.fontSize ?? 16) * (isDisplayMode ? 1.2 : 1.0),
                ),
                mathStyle: isDisplayMode ? MathStyle.display : MathStyle.text,
                onErrorFallback: (err) => Text(
                  fullMatch,
                  style: (style ?? GoogleFonts.cairo()).copyWith(color: Colors.red),
                ),
              ),
            ),
          ));
        }
      }
    }

    return Text.rich(
      TextSpan(children: spans),
      textAlign: textAlign,
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_math_fork/flutter_math.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:quizzly/core/theme/app_colors.dart';

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
    // 1. معالجة النصوص المحاطة بـ $ أو $$ أولاً (أولوية قصوى)
    // 2. معالجة الرموز الكيميائية والرياضية التلقائية (مثل H_2O أو x^2)
    // النمط أدناه يبحث عن الكلمات التي تحتوي على ^ أو _ 
    final RegExp mathRegex = RegExp(r'(\$\$.*?\$\$|\$.*?\$|(?:\b[A-Za-z0-9\(\)\[\]]+[\^_][A-Za-z0-9\(\)\[\]\^_\+\-\*\/]*))');
    
    final List<String> parts = text.split(mathRegex);
    final List<RegExpMatch> matches = mathRegex.allMatches(text).toList();

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
        String fullMatch = match.group(0) ?? '';
        
        if (fullMatch.isNotEmpty) {
          bool isExplicit = fullMatch.startsWith(r'$');
          bool isDisplayMode = fullMatch.startsWith(r'$$');
          
          String mathContent;
          if (isExplicit) {
            if (isDisplayMode) {
              mathContent = fullMatch.substring(2, fullMatch.length - 2);
            } else {
              mathContent = fullMatch.substring(1, fullMatch.length - 1);
            }
          } else {
            // معالجة تلقائية (تنسيق بسيط مثل H_2O)
            mathContent = fullMatch;
          }

          spans.add(WidgetSpan(
            alignment: PlaceholderAlignment.middle,
            child: Padding(
              padding: EdgeInsets.symmetric(
                vertical: isDisplayMode ? 12 : 0,
                horizontal: 2,
              ),
              child: Math.tex(
                mathContent,
                textStyle: (style ?? GoogleFonts.cairo()).copyWith(
                  color: mathColor ?? style?.color,
                  fontSize: (style?.fontSize ?? 16) * (isDisplayMode ? 1.2 : (isExplicit ? 1.0 : 0.95)),
                ),
                mathStyle: isDisplayMode ? MathStyle.display : MathStyle.text,
                onErrorFallback: (err) => Text(
                  fullMatch,
                  style: (style ?? GoogleFonts.cairo()).copyWith(color: AppColors.textPrimary),
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

import 'package:flutter/material.dart';
import 'package:flutter_math_fork/flutter_math.dart';
import 'package:flutter_widget_from_html/flutter_widget_from_html.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:quizzly/features/settings/domain/services/settings_service.dart';

import '../theme/app_colors.dart';
import '../utils/math_utils.dart';

class TexViewWidget extends StatelessWidget {
  final String text;
  final TextStyle? style;
  final bool isTitle;
  final double? fontSize;
  final FontWeight? fontWeight;
  final Color? color;

  const TexViewWidget({
    super.key,
    required this.text,
    this.style,
    this.isTitle = false,
    this.fontSize,
    this.fontWeight,
    this.color,
  });

  static final RegExp _latexRegex = MathUtils.latexRegex;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final defaultTextColor = isDark ? Colors.white : AppColors.textPrimary;

    double scaleFactor = 1.0;
    try {
      final settings = Provider.of<SettingsService>(context);
      switch (settings.textSize) {
        case 'smaller':
          scaleFactor = 0.85;
          break;
        case 'larger':
          scaleFactor = 1.15;
          break;
        case 'very_large':
          scaleFactor = 1.35;
          break;
        case 'default':
        default:
          scaleFactor = 1.0;
          break;
      }
    } catch (_) {}

    final double baseSize = fontSize ?? 16.0;
    final double finalFontSize = baseSize * scaleFactor;
    
    final defaultStyle = style?.copyWith(
          fontFamily: GoogleFonts.cairo().fontFamily,
          height: 1.5,
          color: color ?? style?.color ?? defaultTextColor,
          fontSize: finalFontSize,
          fontWeight: fontWeight ?? style?.fontWeight,
        ) ??
        GoogleFonts.cairo(
          fontSize: finalFontSize,
          fontWeight: fontWeight ?? FontWeight.normal,
          height: 1.5,
          color: color ?? defaultTextColor,
        );

    final normalizedContent = MathUtils.normalizeMathContent(text);
    final hasLatex = _latexRegex.hasMatch(normalizedContent);
    final hasHtml =
        normalizedContent.contains('<') && normalizedContent.contains('>');

    if (!hasHtml) {
      if (!hasLatex) {
        return Text(
          normalizedContent,
          style: defaultStyle,
          textAlign: isTitle ? TextAlign.center : TextAlign.start,
          textDirection: TextDirection.rtl,
        );
      }
      return _buildMathText(context, normalizedContent, defaultStyle);
    }

    // ── HTML path ──────────────────────────────────────────────────────────
    final htmlBaseStyle = defaultStyle.copyWith(color: null);
    final defaultCssColor = _colorToCss(defaultStyle.color ?? defaultTextColor);

    // Wrap LaTeX formulas in <math-tex> so they can be parsed as standalone elements by HtmlWidget.
    final String processedHtml = normalizedContent.replaceAllMapped(_latexRegex, (match) {
      return '<math-tex>${match.group(0)}</math-tex>';
    });

    return Directionality(
      textDirection: TextDirection.rtl,
      child: HtmlWidget(
        processedHtml,
        textStyle: htmlBaseStyle,
        renderMode: RenderMode.column,
        customStylesBuilder: (element) {
          final inlineStyle = element.attributes['style'] ?? '';
          if (!inlineStyle.contains('color')) {
            return {'color': defaultCssColor};
          }
          return null;
        },
        customWidgetBuilder: (element) {
          if (element.localName == 'math-tex') {
            return _buildMathText(context, element.text, defaultStyle);
          }
          
          if (element.children.isEmpty) {
            final text = element.text;
            if (_latexRegex.hasMatch(text)) {
              return _buildMathText(context, text, defaultStyle);
            }
          }
          return null;
        },
      ),
    );
  }

  static String _colorToCss(Color color) {
    final rgb = color.toARGB32() & 0x00FFFFFF;
    return '#${rgb.toRadixString(16).padLeft(6, '0')}';
  }

  Widget _buildMathText(
    BuildContext context,
    String mathAwareText,
    TextStyle baseStyle,
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = baseStyle.color ?? (isDark ? Colors.white : AppColors.textPrimary);
    final matches = _latexRegex.allMatches(mathAwareText).toList();

    if (matches.isEmpty) {
      return Text(
        mathAwareText,
        style: baseStyle,
        textAlign: isTitle ? TextAlign.center : TextAlign.start,
        textDirection: TextDirection.rtl,
      );
    }

    final children = <Widget>[];
    var cursor = 0;

    for (final match in matches) {
      if (match.start > cursor) {
        final textSegment = mathAwareText.substring(cursor, match.start).trim();
        if (textSegment.isNotEmpty) {
          children.add(
            Text(
              textSegment,
              style: baseStyle,
              textAlign: isTitle ? TextAlign.center : TextAlign.start,
              textDirection: TextDirection.rtl,
            ),
          );
        }
      }

      final token = match.group(0)!;
      final latex = _stripMathDelimiters(token);
      children.add(
        Directionality(
          textDirection: TextDirection.ltr,
          child: Math.tex(
            latex,
            mathStyle:
                _isDisplayMath(token) ? MathStyle.display : MathStyle.text,
            textStyle: TextStyle(
              color: textColor,
              fontSize: (baseStyle.fontSize ?? 16) + 2,
            ),
            onErrorFallback: (error) => Text(
              token,
              style: baseStyle.copyWith(
                color: Colors.redAccent,
                fontFamily: 'monospace',
                fontSize: 13,
              ),
              textDirection: TextDirection.ltr,
            ),
          ),
        ),
      );

      cursor = match.end;
    }

    if (cursor < mathAwareText.length) {
      final trailing = mathAwareText.substring(cursor).trim();
      if (trailing.isNotEmpty) {
        children.add(
          Text(
            trailing,
            style: baseStyle,
            textAlign: isTitle ? TextAlign.center : TextAlign.start,
            textDirection: TextDirection.rtl,
          ),
        );
      }
    }

    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      alignment: isTitle ? WrapAlignment.center : WrapAlignment.start,
      runSpacing: 4,
      spacing: 4,
      children: children,
    );
  }

  static bool _isDisplayMath(String token) {
    return token.startsWith(r'\[') ||
        token.startsWith('\$\$') ||
        (token.startsWith(r'\(') == false && token.startsWith('\$') == false);
  }

  static String _stripMathDelimiters(String token) {
    if (token.startsWith(r'\[') && token.endsWith(r'\]')) {
      return token.substring(2, token.length - 2);
    }
    if (token.startsWith(r'\(') && token.endsWith(r'\)')) {
      return token.substring(2, token.length - 2);
    }
    if (token.startsWith('\$\$') && token.endsWith('\$\$')) {
      return token.substring(2, token.length - 2);
    }
    if (token.startsWith('\$') && token.endsWith('\$')) {
      return token.substring(1, token.length - 1);
    }
    return token;
  }
}

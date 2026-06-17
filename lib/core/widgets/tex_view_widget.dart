import 'package:flutter/material.dart';
import 'package:flutter_math_fork/flutter_math.dart';
import 'package:flutter_widget_from_html/flutter_widget_from_html.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:quizzly/features/settings/domain/services/settings_service.dart';

import '../theme/app_colors.dart';
import '../utils/math_utils.dart';
import 'zoomable_image.dart';

class TexViewWidget extends StatelessWidget {
  final String text;
  final TextStyle? style;
  final bool isTitle;
  final double? fontSize;
  final FontWeight? fontWeight;
  final Color? color;
  final TextDirection? textDirection;

  const TexViewWidget({
    super.key,
    required this.text,
    this.style,
    this.isTitle = false,
    this.fontSize,
    this.fontWeight,
    this.color,
    this.textDirection,
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
          textDirection: textDirection ?? MathUtils.getDirection(normalizedContent),
        );
      }
      return _buildMathText(context, normalizedContent, defaultStyle);
    }

    // ── HTML path ──────────────────────────────────────────────────────────
    final htmlBaseStyle = defaultStyle.copyWith(color: null);
    final defaultCssColor = _colorToCss(defaultStyle.color ?? defaultTextColor);

    final effectiveDirection = textDirection ?? MathUtils.getDirection(normalizedContent);
    final String htmlDir = effectiveDirection == TextDirection.rtl ? 'rtl' : 'ltr';

    // Inject dir attribute into block tags (p, li, div) to force direct block directionality
    var directedHtml = normalizedContent;
    directedHtml = directedHtml.replaceAllMapped(RegExp(r'<p(\s+[^>]*|)>', caseSensitive: false), (match) {
      final attrs = match.group(1) ?? '';
      if (attrs.contains('dir=')) return match.group(0)!;
      return '<p dir="$htmlDir"$attrs>';
    });
    directedHtml = directedHtml.replaceAllMapped(RegExp(r'<li(\s+[^>]*|)>', caseSensitive: false), (match) {
      final attrs = match.group(1) ?? '';
      if (attrs.contains('dir=')) return match.group(0)!;
      return '<li dir="$htmlDir"$attrs>';
    });
    directedHtml = directedHtml.replaceAllMapped(RegExp(r'<div(\s+[^>]*|)>', caseSensitive: false), (match) {
      final attrs = match.group(1) ?? '';
      if (attrs.contains('dir=')) return match.group(0)!;
      return '<div dir="$htmlDir"$attrs>';
    });

    // Wrap in a div with correct direction attribute as a fallback
    final String wrappedHtml = '<div dir="$htmlDir">$directedHtml</div>';

    // Wrap LaTeX formulas in <math-tex> so they can be parsed as standalone elements by HtmlWidget.
    // Wrap in \u200F (RTL marker) for RTL layout to prevent visual swapping of equations.
    final String processedHtml = wrappedHtml.replaceAllMapped(_latexRegex, (match) {
      if (effectiveDirection == TextDirection.rtl) {
        return '\u200F<math-tex>${match.group(0)}</math-tex>\u200F';
      }
      return '<math-tex>${match.group(0)}</math-tex>';
    });
    
    return Directionality(
      textDirection: effectiveDirection,
      child: HtmlWidget(
        processedHtml,
        textStyle: htmlBaseStyle,
        renderMode: RenderMode.column,
        customStylesBuilder: (element) {
          final Map<String, String> styles = {};
          
          if (element.localName != 'math-tex') {
            styles['direction'] = htmlDir;
          }
          
          final inlineStyle = element.attributes['style'] ?? '';
          if (!inlineStyle.contains('color')) {
            styles['color'] = defaultCssColor;
          }
          
          return styles;
        },
        customWidgetBuilder: (element) {
          if (element.localName == 'math-tex') {
            return InlineCustomWidget(
              child: _buildMathText(context, element.text, defaultStyle),
            );
          }
          
          if (element.localName == 'img') {
            final src = element.attributes['src'] ?? '';
            if (src.isNotEmpty) {
              return ZoomableImage(
                imageUrl: src,
                fit: BoxFit.contain,
              );
            }
          }
          
          if (element.children.isEmpty) {
            final text = element.text;
            if (_latexRegex.hasMatch(text)) {
              return InlineCustomWidget(
                child: _buildMathText(context, text, defaultStyle),
              );
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
    final resolvedDirection = textDirection ?? MathUtils.getDirection(mathAwareText);
    final matches = _latexRegex.allMatches(mathAwareText).toList();

    if (matches.isEmpty) {
      return Text(
        mathAwareText,
        style: baseStyle,
        textAlign: isTitle ? TextAlign.center : TextAlign.start,
        textDirection: resolvedDirection,
      );
    }

    final spans = <InlineSpan>[];
    var cursor = 0;

    for (final match in matches) {
      // 1. إضافة النص الذي يسبق المعادلة
      if (match.start > cursor) {
        final textSegment = mathAwareText.substring(cursor, match.start);
        if (textSegment.isNotEmpty) {
          spans.add(TextSpan(
            text: textSegment,
            style: baseStyle,
          ));
        }
      }

      // 2. معالجة المعادلة
      final token = match.group(0)!;
      final latex = _stripMathDelimiters(token);
      final isDisplay = _isDisplayMath(token);

      if (isDisplay) {
        // إذا كانت معادلة منفصلة (Display Mode)، نضعها في WidgetSpan يأخذ عرض السطر بالكامل
        spans.add(const TextSpan(text: '\n'));
        spans.add(WidgetSpan(
          child: Container(
            width: double.infinity,
            alignment: Alignment.center,
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Directionality(
              textDirection: TextDirection.ltr,
              child: Math.tex(
                latex,
                mathStyle: MathStyle.display,
                textStyle: TextStyle(
                  color: textColor,
                  fontSize: (baseStyle.fontSize ?? 16) + 2,
                ),
                onErrorFallback: (error) {
                  final cleanLatex = latex.replaceAll(RegExp(r'\\\(|\\\)|\$'), '');
                  return Text(
                    cleanLatex,
                    style: baseStyle.copyWith(
                      color: textColor.withValues(alpha: 0.9),
                      fontFamily: 'Cairo',
                    ),
                    textAlign: TextAlign.center,
                  );
                },
              ),
            ),
          ),
        ));
        spans.add(const TextSpan(text: '\n'));
      } else {
        // معادلة ضمن السطر (Inline)
        if (resolvedDirection == TextDirection.rtl) {
          spans.add(const TextSpan(text: '\u200F'));
        }
        spans.add(WidgetSpan(
          alignment: PlaceholderAlignment.middle,
          child: Directionality(
            textDirection: TextDirection.ltr,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: Math.tex(
                latex,
                mathStyle: MathStyle.text,
                textStyle: TextStyle(
                  color: textColor,
                  fontSize: (baseStyle.fontSize ?? 16),
                ),
                onErrorFallback: (error) {
                  // If failing, let's try to remove any problematic characters like leading/trailing delimiters
                  final cleanLatex = latex.replaceAll(RegExp(r'\\\(|\\\)|\$'), '');
                  return Text(
                    cleanLatex,
                    style: baseStyle.copyWith(
                      color: textColor.withValues(alpha: 0.9),
                      fontFamily: 'Cairo', // Fallback to Cairo
                    ),
                  );
                },
              ),
            ),
          ),
        ));
        if (resolvedDirection == TextDirection.rtl) {
          spans.add(const TextSpan(text: '\u200F'));
        }
      }

      cursor = match.end;
    }

    // 3. إضافة النص المتبقي بعد آخر معادلة
    if (cursor < mathAwareText.length) {
      final trailing = mathAwareText.substring(cursor);
      if (trailing.isNotEmpty) {
        spans.add(TextSpan(
          text: trailing,
          style: baseStyle,
        ));
      }
    }

    return Text.rich(
      TextSpan(children: spans),
      textAlign: isTitle ? TextAlign.center : TextAlign.start,
      textDirection: resolvedDirection,
    );
  }

  static bool _isDisplayMath(String token) {
    return token.startsWith(r'\[') ||
        token.startsWith('\$\$') ||
        (token.startsWith(r'\(') == false && token.startsWith('\$') == false);
  }

  static String _stripMathDelimiters(String token) {
    String t = token.trim();
    
    // 1. Force remove any leading/trailing math delimiters
    if (t.startsWith(r'\\\\[')) t = t.substring(4);
    if (t.startsWith(r'\\[')) t = t.substring(2);
    if (t.startsWith(r'\[')) t = t.substring(2);
    if (t.startsWith(r'\\\\(')) t = t.substring(4);
    if (t.startsWith(r'\\(')) t = t.substring(2);
    if (t.startsWith(r'\(')) t = t.substring(2);
    if (t.startsWith(r'$$')) t = t.substring(2);
    if (t.startsWith(r'$')) t = t.substring(1);

    if (t.endsWith(r'\\\\]')) t = t.substring(0, t.length - 4);
    if (t.endsWith(r'\\]')) t = t.substring(0, t.length - 2);
    if (t.endsWith(r'\]')) t = t.substring(0, t.length - 2);
    if (t.endsWith(r'\\\\)')) t = t.substring(0, t.length - 4);
    if (t.endsWith(r'\\)')) t = t.substring(0, t.length - 2);
    if (t.endsWith(r'\)')) t = t.substring(0, t.length - 2);
    if (t.endsWith(r'$$')) t = t.substring(0, t.length - 2);
    if (t.endsWith(r'$')) t = t.substring(0, t.length - 1);

    t = t.trim();
    
    // Clean up chemical arrows and common linear notations
    t = t.replaceAll('->', r' \to ');
    t = t.replaceAll('<-', r' \gets ');
    t = t.replaceAll('=>', r' \implies ');
    t = t.replaceAll('<=', r' \Leftarrow ');
    
    return t;
  }
}

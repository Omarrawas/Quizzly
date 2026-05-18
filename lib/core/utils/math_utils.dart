import 'math_parser.dart';

class MathUtils {
  static final RegExp latexRegex = RegExp(
    r'(\$\$.*?\$\$|\$.*?\$|\\\(.*?\\\)|\\\[.*?\\\])',
    dotAll: true,
  );

  /// Standard normalization for HTML content containing math
  static String normalizeMathContent(String raw) {
    if (raw.trim().isEmpty) return raw;

    // 1. Fix color hex codes (8-digit to 6-digit)
    var processed = _normalizeColors(raw);
    
    // 2. Decode HTML entities for safe parsing
    final decodedRaw = decodeHtmlEntities(processed);
    
    // 3. Process segments (avoiding HTML tags)
    final combinedRegex = RegExp(r'(<[^>]+>|[^<]+)');
    final matches = combinedRegex.allMatches(decodedRaw);

    final buffer = StringBuffer();
    for (final match in matches) {
      final part = match.group(0)!;
      if (part.startsWith('<') && part.endsWith('>')) {
        buffer.write(part);
      } else {
        buffer.write(_processTextSegment(part));
      }
    }

    return buffer.toString();
  }

  static String _normalizeColors(String raw) {
    return raw.replaceAllMapped(
      RegExp(r'#([0-9a-fA-F]{2})([0-9a-fA-F]{6})\b'),
      (match) {
        final alpha = match.group(1)!.toLowerCase();
        final rgb = match.group(2)!;
        if (alpha == 'ff') return '#$rgb';
        return match.group(0)!;
      }
    );
  }

  static String _processTextSegment(String input) {
    if (latexRegex.hasMatch(input)) return input;

    return input.splitMapJoin(
      RegExp(r'\S+'),
      onMatch: (Match match) {
        final token = match.group(0)!;
        if (isMathLike(token)) {
          final latex = MathParser.convertToLatex(token);
          return '\\($latex\\)';
        }
        return token;
      },
      onNonMatch: (String nonMatch) {
        return nonMatch;
      },
    );
  }

  /// Detects if a string looks like a mathematical equation
  static bool isMathLike(String text) {
    if (text.trim().length < 3) return false;
    
    final mathPatterns = [
      r'[πλωσΔΩαβγθδσΦ]',
      r'\^',
      r'_',
      r'[=<>≤≥≠≈]',
      r'/',
      r'[×÷±√∞²³]',
      r'〖|〗|【|】',
      r'\(.*\/.*\)',
      r'\d+(\.\d+)?\s*[×*]\s*10',
      r'[²³⁴⁵⁶⁷⁸⁹⁰]',
      r'\\[a-zA-Z]+',
      r'[⟹⇒°´′″]',
    ];

    final combinedRegex = RegExp(mathPatterns.join('|'));
    
    int hits = 0;
    if (text.contains('/')) hits++;
    if (text.contains('^')) hits++;
    if (text.contains('_')) hits++;
    if (text.contains('=')) hits++;
    if (text.contains('⟹') || text.contains('⇒')) hits += 2;
    if (text.contains('°')) hits++;
    if (text.contains('´') || text.contains('′')) hits++;
    if (text.contains('〖')) hits += 2;
    if (RegExp(r'[a-zA-Z]').hasMatch(text) && hits > 0) hits++;

    return hits >= 2 || combinedRegex.hasMatch(text);
  }

  static String decodeHtmlEntities(String input) {
    return input
        .replaceAll('&#47;', '/')
        .replaceAll('&#92;', r'\')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&amp;', '&')
        .replaceAll('&nbsp;', ' ')
        .replaceAll('&quot;', '"')
        .replaceAll('&#39;', "'");
  }
}

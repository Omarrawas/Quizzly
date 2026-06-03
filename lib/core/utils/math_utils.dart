import 'math_parser.dart';

class MathUtils {
  // Matches single-backslash delimiters: \(...\)  \[...\]  $...$  $$...$$
  static final RegExp latexRegex = RegExp(
    r'(\$\$.*?\$\$|\$.*?\$|\\\(.*?\\\)|\\\[.*?\\\])',
    dotAll: true,
  );

  /// Standard normalization for HTML content containing math
  static String normalizeMathContent(String raw) {
    if (raw.trim().isEmpty) return raw;

    // 1. Fix color hex codes (8-digit to 6-digit)
    var processed = _normalizeColors(raw);

    // 2. EMERGENCY PATCH: Clean up garbled "$1 $2" from previous bug
    processed = processed.replaceAll(RegExp(r'\$(\\)?1 \$(\\)?2'), ' ');

    // 2. Normalize legacy double-backslash delimiters \\( \\) → \( \)
    //    This fixes old data saved with r'\\(' instead of '\\('
    processed = _normalizeLegacyDelimiters(processed);

    // 3. Decode HTML entities for safe parsing
    final decodedRaw = decodeHtmlEntities(processed);

    // 4. Process segments (avoiding HTML tags)
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

    var result = buffer.toString();
    
    // 5. Merge adjacent math blocks: \(seg1\) \(seg2\) → \(seg1 seg2\)
    // This ensures equations with spaces are rendered as a single unit on one line.
    result = result.replaceAllMapped(
      RegExp(r'\\\)([\s\t]*)\\\('), 
      (m) => '${m[1]}'
    );

    // 6. Merge trailing punctuation/brackets into the math block
    // e.g., \(x = y\) )  → \(x = y )\)
    result = result.replaceAllMapped(
      RegExp(r'\\\)\s*([\)\],.;!]+)'), 
      (m) => '${m[1]}\\)'
    );

    return result;
  }

  /// Converts \\( ... \\) and \\[ ... \\] (double backslash, legacy format)
  /// into \( ... \) and \[ ... \] (single backslash, current format)
  static String _normalizeLegacyDelimiters(String input) {
    // Replace \\( ... \\) with \( ... \)
    // In the actual string, legacy data has two backslashes before ( and )
    var result = input;

    // Pattern: two literal backslashes then ( or [
    // We use replaceAll with explicit strings to avoid regex complexity
    if (result.contains('\\\\(')) {
      result = result.replaceAll('\\\\(', '\\(');
    }
    if (result.contains('\\\\)')) {
      result = result.replaceAll('\\\\)', '\\)');
    }
    if (result.contains('\\\\[')) {
      result = result.replaceAll('\\\\[', '\\[');
    }
    if (result.contains('\\\\]')) {
      result = result.replaceAll('\\\\]', '\\]');
    }
    return result;
  }

  static String _normalizeColors(String raw) {
    return raw.replaceAllMapped(
      RegExp(r'#([0-9a-fA-F]{2})([0-9a-fA-F]{6})\b'),
      (match) {
        final alpha = match.group(1)!.toLowerCase();
        final rgb = match.group(2)!;
        if (alpha == 'ff') return '#$rgb';
        return match.group(0)!;
      },
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
    final trimmed = text.trim();
    if (trimmed.isEmpty) return false;
    
    // Arabic characters are never math in this context
    if (RegExp(r'[\u0600-\u06FF]').hasMatch(trimmed)) return false;

    // Single character detection
    if (trimmed.length == 1) {
      // Allow operators, common math symbols, and single variables even if single character
      return RegExp(r'[a-zA-ZπλωσΔΩαβγθδσΦ\^/_=<>≤≥≠≈×÷±√∞²³〖〗【】()\[\]{}λπαβγ+*-]').hasMatch(trimmed);
    }

    // If it starts with a number but has no operators, don't treat as math (e.g. "22.4")
    if (RegExp(r'^\d+\.?\d*$').hasMatch(trimmed)) return false;

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
        .replaceAll('&#92;', String.fromCharCode(92)) // single backslash \
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&amp;', '&')
        .replaceAll('&nbsp;', ' ')
        .replaceAll('&quot;', '"')
        .replaceAll('&#39;', "'");
  }
}

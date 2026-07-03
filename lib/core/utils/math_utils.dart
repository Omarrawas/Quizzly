import 'package:flutter/material.dart';

class MathUtils {
  // Matches: $$...$$ | $...$ | \\(...\\) | \\[...\\] | \(...\) | \[...\]
  static final RegExp latexRegex = RegExp(
    r'\$\$.*?\$\$'                          // $$...$$ block math
    r'|\$[^\$\s](?:[^\$]*?[^\$\s])?\$'     // $...$ inline math (no spaces at edges)
    r'|\\\\\\(.*?\\\\\\)'                  // \\(...\\) double-backslash inline
    r'|\\\\\\[.*?\\\\\\]'                  // \\[...\\] double-backslash block
    r'|\\\(.*?\\\)'                         // \(...\) single-backslash inline
    r'|\\\[.*?\\\]',                        // \[...\] single-backslash block
    dotAll: true,
  );

  /// Standard normalization for HTML content containing math
  static String normalizeMathContent(String raw) {
    if (raw.trim().isEmpty) return raw;

    // 1. Fix common thermodynamic and chemical symbols that cause issues
    var processed = raw
        .replaceAll(r'^{\circ}', r'^\circ')
        .replaceAll(r'^{\circ}C', r'^\circ\text{C}')
        .replaceAll(r'\Delta G^{\circ}', r'\Delta G^\circ')
        .replaceAll(r'\Delta H^{\circ}', r'\Delta H^\circ')
        .replaceAll(r'\Delta S^{\circ}', r'\Delta S^\circ')
        .replaceAll(r'\delta G', r'\Delta G')
        .replaceAll(r'\delta H', r'\Delta H')
        .replaceAll(r'\delta S', r'\Delta S')
        .replaceAll(r'\longrightarrow', r'\to')
        .replaceAll(r'\longleftarrow', r'\gets')
        .replaceAll(r' \rightarrow ', r' \to ')
        .replaceAll(r' \leftarrow ', r' \gets ');

    // 2. Fix color hex codes (8-digit to 6-digit)
    processed = _normalizeColors(processed);

    // 2. EMERGENCY PATCH: Clean up garbled "$1 $2" from previous bug
    processed = processed.replaceAll(RegExp(r'\$(\\)?1 \$(\\)?2'), ' ');

    // 2. Normalize legacy double-backslash delimiters \\( \\) → \( \)
    //    This fixes old data saved with r'\\(' instead of '\\('
    processed = _normalizeLegacyDelimiters(processed);

    // 2b. Convert dollar-sign math delimiters to backslash format
    //     $$...$$ → \[...\]  and  $...$ → \(...\)
    processed = _convertDollarDelimiters(processed);


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

  /// Converts $$ ... $$ → \[ ... \] and $ ... $ → \( ... \)
  /// so all math uses a single backslash-delimiter format.
  static String _convertDollarDelimiters(String input) {
    if (!input.contains(r'$')) return input;

    // 1. Block math: $$...$$ → \[...\]
    var result = input.replaceAllMapped(
      RegExp(r'\$\$(.*?)\$\$', dotAll: true),
      (m) => '\\[${m.group(1)}\\]',
    );

    // 2. Inline math: $...$ → \(...\) — only non-whitespace at edges
    result = result.replaceAllMapped(
      RegExp(r'\$([^\$\s](?:[^\$]*?[^\$\s])?)\$'),
      (m) => '\\(${m.group(1)}\\)',
    );

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
    if (input.trim().isEmpty) return input;

    // Use splitMapJoin to isolate already-existing LaTeX blocks
    return input.splitMapJoin(
      latexRegex,
      onMatch: (Match match) {
        return match.group(0)!;
      },
      onNonMatch: (String nonMathPart) {
        return nonMathPart;
      },
    );
  }

  static bool isMathExpression(String text) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return false;

    // Arabic characters are never math in this context
    if (RegExp(r'[\u0600-\u06FF]').hasMatch(trimmed)) return false;

    // Single character detection:
    // Only treat as math if it's a Greek letter, math operator, or superscript/subscript digit.
    // Do NOT match plain English letters (like a, b, c, x, y, z) or brackets/parentheses here.
    if (trimmed.length == 1) {
      return RegExp(r'[πλωστρηΔΦΩαβγθδσΦ\^/_=<>≤≥≠≈×÷±∓∓√∞²³⁴⁵⁶⁷⁸⁹⁰λπαβγ+*\-∀∃∈∉∋∇∆∩∪ø∂]').hasMatch(trimmed);
    }

    // If it starts with a number but has no operators or other indicators, don't treat as math (e.g. "22.4")
    if (RegExp(r'^\d+(\.\d+)?$').hasMatch(trimmed)) return false;

    // Math operators indicate a math expression
    final hasMathOperator = RegExp(r'[=+\-*/^_<≤≥≠±×÷√⟹⇒]|\\').hasMatch(trimmed);
    if (hasMathOperator) {
      // Exclude simple parenthesized options like "(a)", "(b)", "(1)"
      final isParenthesizedOption = RegExp(r'^\([a-zA-Z0-9]\)$').hasMatch(trimmed);
      if (!isParenthesizedOption) {
        return true;
      }
    }

    // Chemical formulas (e.g. H2O, CO2, NaCl, H2SO4)
    final isChemicalFormula = RegExp(r'^[A-Z][a-z]?\d+([A-Z][a-z]?\d*)*$').hasMatch(trimmed);
    if (isChemicalFormula) return true;

    // For short strings:
    if (trimmed.length <= 5) {
      // Exclude common English words
      final isCommonEnglishWord = RegExp(
        r'^(the|of|and|to|in|is|for|that|this|with|by|from|at|on|an|or|as|be|are|was|were|value|calculate|find|where|show|if|then|given|determine|solve|equation|formula|mass|ratio|constant|temperature|pressure|volume|moles|concentration|reacts|produces|formed|yields|which|what|how|many|each|following|select)$',
        caseSensitive: false,
      ).hasMatch(trimmed);
      
      if (!isCommonEnglishWord) {
        // Purely alphabetic strings of length 2-5 are only math if they match known functions
        final isPureAlpha = RegExp(r'^[a-zA-Z]+$').hasMatch(trimmed);
        if (isPureAlpha) {
          return RegExp(r'^(sin|cos|tan|log|ln|lim)$', caseSensitive: false).hasMatch(trimmed);
        }
        return RegExp(r'[a-zA-Z0-9()\[\]{}]+').hasMatch(trimmed);
      }
    }

    return isMathLike(trimmed);
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
      return RegExp(r'[a-zA-ZπλωστρηΔΦΩαβγθδσΦ\^/_=<>≤≥≠≈×÷±∓∓√∞²³⁴⁵⁶⁷⁸⁹⁰〖〗【】()\[\]{}λπαβγ+*-∀∃∈∉∋∇∆∩∪ø∂]').hasMatch(trimmed);
    }

    // If it starts with a number but has no operators, don't treat as math (e.g. "22.4")
    if (RegExp(r'^\d+\.?\d*$').hasMatch(trimmed)) return false;

    final mathPatterns = [
      r'[πλωστρηΔΦΩαβγθδσΦ∀∃∈∉∋∇∆∩∪ø∂]',
      r'\^',
      r'_',
      r'[=<>≤≥≠≈≅≡∝≫≪]',
      r'/',
      r'[×÷±∓√∞²³⁴⁵⁶⁷⁸⁹⁰]',
      r'〖|〗|【|】',
      r'\(.*\/.*\)',
      r'\d+(\.\d+)?\s*[×*]\s*10',
      r'\\[a-zA-Z]+',
      r'[⟹⇒∴¬°´′″↑↓←→↔…·]',
    ];

    final combinedRegex = RegExp(mathPatterns.join('|'));

    int hits = 0;
    if (text.contains('/')) hits++;
    if (text.contains('^')) hits++;
    if (text.contains('_')) hits++;
    if (text.contains('=')) hits++;
    if (text.contains('+')) hits++;
    if (text.contains('-')) hits++;
    if (text.contains('⟹') || text.contains('⇒')) hits += 2;
    if (text.contains('°')) hits++;
    if (text.contains('´') || text.contains('′')) hits++;
    if (text.contains('〖')) hits += 2;
    if (RegExp(r'[a-zA-Z]').hasMatch(text) && hits > 0) hits++;
    if (RegExp(r'[\d]').hasMatch(text) && hits > 1) hits++;

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

  /// Detects the text direction.
  /// For Quizzly, we return RTL direction always to comply with global dark fintech layout rules.
  static TextDirection getDirection(String text) {
    return TextDirection.rtl;
  }

  /// Strips all potential math delimiters from a matched token
  static String stripMathDelimiters(String token) {
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


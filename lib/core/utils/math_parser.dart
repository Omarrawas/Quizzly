import 'math_normalizer.dart';

class MathParser {
  /// Main entry point to convert linear math to LaTeX
  static String convertToLatex(String input) {
    if (input.isEmpty) return "";
    
    // 1. Normalize Unicode and Greek letters
    String normalized = MathNormalizer.normalize(input);
    
    // 2. Recursively parse structures
    return _parse(normalized);
  }

  static String _parse(String input) {
    String text = input.trim();
    if (text.isEmpty) {
      return "";
    }

    // Process Fractions (/)
    int slashIndex = _findNextOperator(text, '/');
    if (slashIndex != -1) {
      return _processOperator(text, slashIndex, (left, right) => "\\frac{$left}{$right}");
    }

    // Process Powers (^)
    int caretIndex = _findNextOperator(text, '^');
    if (caretIndex != -1) {
      return _processOperator(text, caretIndex, (left, right) => "$left^{$right}");
    }

    // Process Subscripts (_)
    int subIndex = _findNextOperator(text, '_');
    if (subIndex != -1) {
      return _processOperator(text, subIndex, (left, right) => "${left}_{$right}");
    }

    // Handle parentheses
    if (text.startsWith('(') && text.endsWith(')')) {
      String inner = text.substring(1, text.length - 1);
      if (_isBalanced(inner, '(', ')')) {
        return "\\left( ${_parse(inner)} \\right)";
      }
    }
    
    // Handle LaTeX groups
    if (text.startsWith('{') && text.endsWith('}')) {
       String inner = text.substring(1, text.length - 1);
       if (_isBalanced(inner, '{', '}')) {
         return "{${_parse(inner)}}";
       }
    }

    return _handleImplicitMultiplication(text);
  }

  static String _processOperator(String text, int index, String Function(String left, String right) formatter) {
    String leftPart = text.substring(0, index);
    String rightPart = text.substring(index + 1);

    String leftOp = _extractLeftOperand(leftPart);
    String rightOp = _extractRightOperand(rightPart);

    String remainingLeft = leftPart.substring(0, leftPart.length - leftOp.length);
    String remainingRight = rightPart.substring(rightOp.length);

    String cleanLeft = _stripOuterBrackets(leftOp);
    String cleanRight = _stripOuterBrackets(rightOp);

    return "${_parse(remainingLeft)}${formatter(_parse(cleanLeft), _parse(cleanRight))}${_parse(remainingRight)}";
  }

  static int _findNextOperator(String text, String op) {
    int bracketLevel = 0;
    for (int i = 0; i < text.length; i++) {
      if (text[i] == '{') {
        bracketLevel++;
      } else if (text[i] == '}') {
        bracketLevel--;
      } else if (bracketLevel == 0 && text[i] == op) {
        return i;
      }
    }
    return -1;
  }

  static String _extractLeftOperand(String text) {
    if (text.isEmpty) return "";
    String t = text.trimRight();
    if (t.endsWith('}') || t.endsWith(')')) {
      String open = t.endsWith('}') ? '{' : '(';
      String close = t.endsWith('}') ? '}' : ')';
      int level = 1;
      int i = t.length - 2;
      while (i >= 0 && level > 0) {
        if (t[i] == close) {
          level++;
        } else if (t[i] == open) {
          level--;
        }
        i--;
      }
      return t.substring(i + 1);
    } else {
      final regex = RegExp(r'(\\[a-zA-Z]+|[a-zA-Z]+|[0-9.]+|.)$');
      final match = regex.firstMatch(t);
      return match?.group(0) ?? t.substring(t.length - 1);
    }
  }

  static String _extractRightOperand(String text) {
    if (text.isEmpty) return "";
    String t = text.trimLeft();
    if (t.startsWith('{') || t.startsWith('(')) {
      String open = t.startsWith('{') ? '{' : '(';
      String close = t.startsWith('{') ? '}' : ')';
      int level = 1;
      int i = 1;
      while (i < t.length && level > 0) {
        if (t[i] == open) {
          level++;
        } else if (t[i] == close) {
          level--;
        }
        i++;
      }
      return t.substring(0, i);
    } else {
      final regex = RegExp(r'^(\\[a-zA-Z]+|[a-zA-Z]+|[0-9.]+)');
      final match = regex.firstMatch(t);
      return match?.group(0) ?? t.substring(0, 1);
    }
  }

  static String _stripOuterBrackets(String text) {
    String t = text.trim();
    if ((t.startsWith('(') && t.endsWith(')')) || (t.startsWith('{') && t.endsWith('}'))) {
      String open = t[0];
      String close = t[t.length - 1];
      String inner = t.substring(1, t.length - 1);
      if (_isBalanced(inner, open, close)) {
        return inner;
      }
    }
    return t;
  }

  static bool _isBalanced(String text, String open, String close) {
    int level = 0;
    for (int i = 0; i < text.length; i++) {
      if (text[i] == open) {
        level++;
      } else if (text[i] == close) {
        level--;
      }
      if (level < 0) return false;
    }
    return level == 0;
  }

  static String _handleImplicitMultiplication(String text) {
    String result = text.replaceAllMapped(RegExp(r'(\d)([\\a-zA-Z])'), (m) => '${m[1]} ${m[2]}');
    result = result.replaceAllMapped(RegExp(r'([\\a-zA-Z])(\d)'), (m) => '${m[1]} ${m[2]}');
    return result;
  }
}

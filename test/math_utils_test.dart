import 'package:flutter_test/flutter_test.dart';
import 'package:quizzly/core/utils/math_utils.dart';

void main() {
  group('MathUtils.normalizeMathContent Tests', () {
    test('should not wrap a plain text math expression with spaces in a math block', () {
      final input = 'x + y = 5';
      final expected = 'x + y = 5';
      expect(MathUtils.normalizeMathContent(input), expected);
    });

    test('should preserve already-formatted LaTeX blocks and not modify them', () {
      final input = r'هذه المعادلة \(x^2 + y^2 = 25\) جاهزة';
      final expected = r'هذه المعادلة \(x^2 + y^2 = 25\) جاهزة';
      expect(MathUtils.normalizeMathContent(input), expected);
    });

    test('should not parse mixed Arabic text and plain math expressions', () {
      final input = 'حل المعادلة التالية: a + b = c حيث a = 2';
      final expected = 'حل المعادلة التالية: a + b = c حيث a = 2';
      expect(MathUtils.normalizeMathContent(input), expected);
    });

    test('should not convert plain text chemical formulas with numbers to subscripts', () {
      final input = 'تفاعل H2O مع CO2 ينتج H2CO3';
      final expected = 'تفاعل H2O مع CO2 ينتج H2CO3';
      expect(MathUtils.normalizeMathContent(input), expected);
    });

    test('should not convert unicode subscripts copied from MS Word to LaTeX subscripts', () {
      final input = 'تفاعل H₂O مع CO₂';
      final expected = 'تفاعل H₂O مع CO₂';
      expect(MathUtils.normalizeMathContent(input), expected);
    });

    test('should not treat English words as math or modify them', () {
      final input = 'Calculate the value of x where x = 3';
      final expected = 'Calculate the value of x where x = 3';
      expect(MathUtils.normalizeMathContent(input), expected);
    });

    test('should process segments that consist entirely of punctuation or spaces without throwing RangeError', () {
      final input1 = ' : ';
      final input2 = ' :  : ';
      final input3 = ' ، ';
      expect(MathUtils.normalizeMathContent(input1), ' : ');
      expect(MathUtils.normalizeMathContent(input2), ' :  : ');
      expect(MathUtils.normalizeMathContent(input3), ' ، ');
    });
  });
}

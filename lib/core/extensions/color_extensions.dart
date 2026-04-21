import 'package:flutter/material.dart';

/// Extension لتجنب withOpacity المهمل
/// استبداله بـ withValues(alpha: ...) وفق أحدث إصدارات Flutter
extension ColorAlpha on Color {
  Color alpha(double opacity) =>
      withValues(alpha: (opacity.clamp(0.0, 1.0)));
}

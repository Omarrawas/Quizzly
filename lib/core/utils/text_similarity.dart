import 'dart:math';

class TextSimilarity {
  /// Cleans the string from HTML tags, diacritics, and normalize whitespace
  static String normalizeString(String text) {
    String normalized = text
        .replaceAll(RegExp(r'<[^>]*>'), '') // Strip HTML tags
        .replaceAll('&nbsp;', ' ')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&amp;', '&')
        .toLowerCase()
        .trim();

    // Remove Arabic diacritics (harakat)
    final diacritics = RegExp(r'[\u064B-\u0652\u0670]');
    normalized = normalized.replaceAll(diacritics, '');

    // Normalize Alif variations
    normalized = normalized
        .replaceAll(RegExp(r'[أإآ]'), 'ا')
        .replaceAll('ى', 'ي')
        .replaceAll('ة', 'ه');

    // Replace multiple spaces with a single space
    normalized = normalized.replaceAll(RegExp(r'\s+'), ' ');

    return normalized;
  }

  /// Calculates string similarity using Sørensen-Dice coefficient
  /// Returns a value between 0.0 (completely different) and 1.0 (identical)
  static double compare(String str1, String str2) {
    final s1 = normalizeString(str1);
    final s2 = normalizeString(str2);

    if (s1 == s2) return 1.0;
    if (s1.isEmpty || s2.isEmpty) return 0.0;

    final profile1 = _getBigramMap(s1);
    final profile2 = _getBigramMap(s2);

    int matches = 0;
    for (var key in profile1.keys) {
      if (profile2.containsKey(key)) {
        matches += min(profile1[key]!, profile2[key]!);
      }
    }

    int totalBigrams = s1.length - 1 + s2.length - 1;
    if (totalBigrams <= 0) return s1 == s2 ? 1.0 : 0.0;

    return (2.0 * matches) / totalBigrams;
  }

  static Map<String, int> _getBigramMap(String str) {
    final Map<String, int> bigrams = {};
    for (int i = 0; i < str.length - 1; i++) {
      final bigram = str.substring(i, i + 2);
      bigrams[bigram] = (bigrams[bigram] ?? 0) + 1;
    }
    return bigrams;
  }
}

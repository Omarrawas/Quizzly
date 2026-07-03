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

  /// Calculates string similarity using a hybrid of character bigrams and word-level Dice coefficient.
  /// This ensures better matching for full words of the question.
  static double compare(String str1, String str2) {
    final s1 = normalizeString(str1);
    final s2 = normalizeString(str2);

    if (s1 == s2) return 1.0;
    if (s1.isEmpty || s2.isEmpty) return 0.0;

    // 1. Calculate word-level similarity
    final words1 = s1.split(' ').where((w) => w.isNotEmpty).toList();
    final words2 = s2.split(' ').where((w) => w.isNotEmpty).toList();

    if (words1.isEmpty || words2.isEmpty) return 0.0;

    int wordMatches = 0;
    final usedIndices = <int>{};
    
    for (var w1 in words1) {
      double bestMatchSim = 0.0;
      int bestMatchIdx = -1;
      
      for (int j = 0; j < words2.length; j++) {
        if (usedIndices.contains(j)) continue;
        final w2 = words2[j];
        
        if (w1 == w2) {
          bestMatchSim = 1.0;
          bestMatchIdx = j;
          break;
        }
        
        // Check character-level similarity between individual words to allow minor typos
        final sim = _getBigramSimilarity(w1, w2);
        if (sim > bestMatchSim) {
          bestMatchSim = sim;
          bestMatchIdx = j;
        }
      }
      
      // If the word has a high similarity match (>= 0.75), count it as matched
      if (bestMatchSim >= 0.75) {
        wordMatches++;
        if (bestMatchIdx != -1) {
          usedIndices.add(bestMatchIdx);
        }
      }
    }

    // Word Dice coefficient: 2 * matches / (len1 + len2)
    final wordDice = (2.0 * wordMatches) / (words1.length + words2.length);

    // 2. Calculate full string character bigram similarity
    final charDice = _getBigramSimilarity(s1, s2);

    // Hybrid similarity: 75% word-level, 25% character-level bigrams
    return (0.75 * wordDice) + (0.25 * charDice);
  }

  static double _getBigramSimilarity(String s1, String s2) {
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

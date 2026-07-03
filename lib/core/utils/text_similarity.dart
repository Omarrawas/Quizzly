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

    // Strip LaTeX math commands & symbols to compare actual text/values
    normalized = normalized
        .replaceAll(RegExp(r'\\[a-zA-Z]+'), ' ') // Remove LaTeX commands like \text, \rightleftharpoons, \frac
        .replaceAll(RegExp(r'\\[()\[\]]'), ' ') // Remove \(, \), \[, \]
        .replaceAll(RegExp(r'[{}_^$()\]\[+\-=<>]'), ' '); // Remove math characters, subscript/superscript brackets

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

    return normalized.trim();
  }

  /// Calculates string similarity using a hybrid of character bigrams and word-level Jaccard coefficient.
  /// This ensures better matching for full words of the question, penalizing missing words strictly.
  static double compare(String str1, String str2) {
    final s1 = normalizeString(str1);
    final s2 = normalizeString(str2);

    if (s1 == s2) return 1.0;
    if (s1.isEmpty || s2.isEmpty) return 0.0;

    final words1 = s1.split(' ').where((w) => w.isNotEmpty).toList();
    final words2 = s2.split(' ').where((w) => w.isNotEmpty).toList();

    if (words1.isEmpty || words2.isEmpty) return 0.0;

    // Filter Arabic stop words to get core content words
    final stopWords = {
      'من', 'في', 'على', 'إلى', 'عن', 'ما', 'هل', 'هو', 'هي', 'أن', 'إن', 'فإن',
      'عند', 'ثم', 'أو', 'مع', 'حتى', 'إذا', 'هذا', 'هذه', 'ذلك', 'تلك', 'التي', 'الذي'
    };
    final content1 = words1.where((w) => !stopWords.contains(w)).toList();
    final content2 = words2.where((w) => !stopWords.contains(w)).toList();

    final finalWords1 = content1.isNotEmpty ? content1 : words1;
    final finalWords2 = content2.isNotEmpty ? content2 : words2;

    int wordMatches = 0;
    final usedIndices = <int>{};
    
    for (var w1 in finalWords1) {
      double bestMatchSim = 0.0;
      int bestMatchIdx = -1;
      
      for (int j = 0; j < finalWords2.length; j++) {
        if (usedIndices.contains(j)) continue;
        final w2 = finalWords2[j];
        
        if (w1 == w2) {
          bestMatchSim = 1.0;
          bestMatchIdx = j;
          break;
        }
        
        final sim = _getBigramSimilarity(w1, w2);
        if (sim > bestMatchSim) {
          bestMatchSim = sim;
          bestMatchIdx = j;
        }
      }
      
      // Strict threshold of 0.8 for a word match
      if (bestMatchSim >= 0.8) {
        wordMatches++;
        if (bestMatchIdx != -1) {
          usedIndices.add(bestMatchIdx);
        }
      }
    }

    // Jaccard similarity: matches / (len1 + len2 - matches)
    final wordJaccard = wordMatches / (finalWords1.length + finalWords2.length - wordMatches);

    // Character bigram similarity
    final charDice = _getBigramSimilarity(s1, s2);

    // Hybrid: 85% word Jaccard (strict word overlap), 15% character bigram (minor typos)
    return (0.85 * wordJaccard) + (0.15 * charDice);
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

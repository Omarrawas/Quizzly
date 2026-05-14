class MathNormalizer {
  static const Map<String, String> unicodeMap = {
    '⁄': '/',
    '×': r'\times',
    '−': '-',
    'π': r'\pi',
    'λ': r'\lambda',
    'α': r'\alpha',
    'β': r'\beta',
    'γ': r'\gamma',
    'θ': r'\theta',
    'δ': r'\delta',
    'σ': r'\sigma',
    'ω': r'\omega',
    'Δ': r'\Delta',
    'Ω': r'\Omega',
    'Φ': r'\Phi',
    '〖': '{',
    '〗': '}',
    '±': r'\pm',
    '÷': r'\div',
    '≤': r'\le',
    '≥': r'\ge',
    '≠': r'\ne',
    '≈': r'\approx',
    '∞': r'\infty',
    '²': '^2',
    '³': '^3',
    '⟹': r'\implies',
    '⇒': r'\Rightarrow',
    '°': r'^\circ',
    '´': "'",
    '′': "'",
    '″': "''",
    'Dmin': r'D_{min}',
    'Dmax': r'D_{max}',
  };

  static String normalize(String input) {
    if (input.isEmpty) return input;

    String result = input;

    // 1. Replace Unicode characters from map
    unicodeMap.forEach((unicode, replacement) {
      result = result.replaceAll(unicode, replacement);
    });

    // 2. Extra Word artifact cleanup
    result = result.replaceAll('〖', '{').replaceAll('〗', '}');
    result = result.replaceAll('【', '{').replaceAll('】', '}');

    // 3. Fix common typing errors in LaTeX
    result = result.replaceAllMapped(RegExp(r'\\ +([a-zA-Z])'), (match) => '\\${match.group(1)}');

    result = result.trim();
    
    return result;
  }
}

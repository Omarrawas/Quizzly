class MathNormalizer {
  static const Map<String, String> unicodeMap = {
    '⁄': '/',
    '×': r'\times',
    '÷': r'\div',
    '−': '-',
    '±': r'\pm',
    '∓': r'\mp',
    '≤': r'\le',
    '≥': r'\ge',
    '≠': r'\ne',
    '≈': r'\approx',
    '≅': r'\cong',
    '≡': r'\equiv',
    '∝': r'\propto',
    '≫': r'\gg',
    '≪': r'\ll',
    '∞': r'\infty',
    '√': r'\sqrt',
    '∛': r'\sqrt[3]',
    '∜': r'\sqrt[4]',
    '∂': r'\partial',
    '∇': r'\nabla',
    '∆': r'\Delta',
    '∀': r'\forall',
    '∃': r'\exists',
    '∈': r'\in',
    '∉': r'\notin',
    '∋': r'\ni',
    '∩': r'\cap',
    '∪': r'\cup',
    'ø': r'\phi',
    '°C': r'^\circ\text{C}',
    '°F': r'^\circ\text{F}',
    '°': r'^\circ',
    'π': r'\pi',
    'λ': r'\lambda',
    'α': r'\alpha',
    'β': r'\beta',
    'γ': r'\gamma',
    'δ': r'\delta',
    'ε': r'\epsilon',
    'θ': r'\theta',
    'σ': r'\sigma',
    'ρ': r'\rho',
    'τ': r'\tau',
    'μ': r'\mu',
    'ω': r'\omega',
    'φ': r'\phi',
    'ϑ': r'\vartheta',
    'Δ': r'\Delta',
    'Ω': r'\Omega',
    'Φ': r'\Phi',
    '↑': r'\uparrow',
    '↓': r'\downarrow',
    '←': r'\leftarrow',
    '→': r'\rightarrow',
    '↔': r'\leftrightarrow',
    '⟹': r'\implies',
    '⇒': r'\Rightarrow',
    '∴': r'\therefore',
    '¬': r'\neg',
    '·': r'\cdot',
    '…': r'\dots',
    '⋮': r'\vdots',
    '⋱': r'\ddots',
    '⋰': r'\iddots',
    '²': '^2',
    '³': '^3',
    '⁰': '^0',
    '¹': '^1',
    '⁴': '^4',
    '⁵': '^5',
    '⁶': '^6',
    '⁷': '^7',
    '⁸': '^8',
    '⁹': '^9',
    '₀': '_0',
    '₁': '_1',
    '₂': '_2',
    '₃': '_3',
    '₄': '_4',
    '₅': '_5',
    '₆': '_6',
    '₇': '_7',
    '₈': '_8',
    '₉': '_9',
    '₊': '_+',
    '₋': '_-',
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

    // 4. Cleanup degree/superscript formatting errors
    // Collapse double superscripts like ^^ or ^{^ which cause rendering errors
    result = result.replaceAll(RegExp(r'\^{2,}'), '^');
    result = result.replaceAll(r'^{^', '^{'); 
    
    // Ensure \circ is followed by a space to prevent merging with subsequent letters (e.g. \circC -> \circ C)
    result = result.replaceAll(r'\circ', r'\circ ');
    // Remove extra spaces created by above replacement
    result = result.replaceAll(r'\circ  ', r'\circ ');
    // Remove triple-backslashes or double-backslashes that might have been accidentally doubled during normalization
    result = result.replaceAll(r'\\\\', r'\\');

    // Convert letters followed by digits to subscripts (e.g. H2O -> H_2O, x1 -> x_1)
    result = result.replaceAllMapped(
      RegExp(r'([a-zA-Z])(\d+)'),
      (match) => '${match.group(1)}_${match.group(2)}'
    );

    result = result.trim();
    
    return result;
  }
}

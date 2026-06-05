import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart' as quill;
import 'package:vsc_quill_delta_to_html/vsc_quill_delta_to_html.dart';
import 'package:flutter_quill_delta_from_html/flutter_quill_delta_from_html.dart';
import 'package:file_picker/file_picker.dart';
import 'package:quizzly/core/services/firebase_storage_service.dart';
import '../theme/app_colors.dart';
import '../utils/math_utils.dart';
import 'math/visual_math_editor.dart';


// ═══════════════════════════════════════════════════════════════
// DATA: All math categories & items (Word-like)
// ═══════════════════════════════════════════════════════════════

class _MathItem {
  final String preview;   // LaTeX for preview display
  final String latex;     // LaTeX to insert
  final String label;     // Arabic label
  const _MathItem(this.preview, this.latex, this.label);
}

class _MathCategoryData {
  final String name;
  final IconData icon;
  final List<_MathItem> items;
  const _MathCategoryData(this.name, this.icon, this.items);
}

final List<_MathCategoryData> _allMathCategories = [
  // ── 1. كسور (Fractions) ──
  _MathCategoryData('كسور', Icons.view_agenda_outlined, [
    _MathItem(r'\frac{\Box}{\Box}', r'\frac{}{}', 'كسر'),
    _MathItem(r'\dfrac{\Box}{\Box}', r'\dfrac{}{}', 'كسر كبير'),
    _MathItem(r'\tfrac{\Box}{\Box}', r'\tfrac{}{}', 'كسر صغير'),
    _MathItem(r'\frac{d}{dx}', r'\frac{d}{dx}', 'اشتقاق'),
    _MathItem(r'\frac{\partial}{\partial x}', r'\frac{\partial}{\partial x}', 'اشتقاق جزئي'),
    _MathItem(r'\frac{dy}{dx}', r'\frac{dy}{dx}', 'dy/dx'),
    _MathItem(r'\binom{n}{k}', r'\binom{n}{k}', 'توافيق'),
  ]),

  // ── 2. أُسس وحدود (Scripts) ──
  _MathCategoryData('أُسس', Icons.superscript, [
    _MathItem(r'\Box^{\Box}', r'{}^{}', 'أُس (فوق)'),
    _MathItem(r'\Box_{\Box}', r'{}_{}', 'حد سفلي'),
    _MathItem(r'\Box^{\Box}_{\Box}', r'{}^{}_{}', 'أُس + حد'),
    _MathItem(r'x^2', r'x^{2}', 'تربيع'),
    _MathItem(r'x^n', r'x^{n}', 'أُس n'),
    _MathItem(r'e^{x}', r'e^{x}', 'أُسيّة'),
    _MathItem(r'a_n', r'a_{n}', 'متسلسلة'),
    _MathItem(r'x_i', r'x_{i}', 'عنصر i'),
  ]),

  // ── 3. جذور (Radicals) ──
  _MathCategoryData('جذور', Icons.square_foot, [
    _MathItem(r'\sqrt{\Box}', r'\sqrt{}', 'جذر تربيعي'),
    _MathItem(r'\sqrt[3]{\Box}', r'\sqrt[3]{}', 'جذر تكعيبي'),
    _MathItem(r'\sqrt[n]{\Box}', r'\sqrt[n]{}', 'جذر نوني'),
    _MathItem(r'\sqrt{a^2+b^2}', r'\sqrt{a^2+b^2}', 'فيثاغورث'),
    _MathItem(r'\sqrt[n]{x}', r'\sqrt[n]{x}', 'جذر n لـ x'),
  ]),

  // ── 4. تكاملات (Integrals) ──
  _MathCategoryData('تكامل', Icons.show_chart, [
    _MathItem(r'\int', r'\int ', 'تكامل'),
    _MathItem(r'\int_{}^{}', r'\int_{}^{} ', 'تكامل محدود'),
    _MathItem(r'\iint', r'\iint ', 'تكامل ثنائي'),
    _MathItem(r'\iiint', r'\iiint ', 'تكامل ثلاثي'),
    _MathItem(r'\oint', r'\oint ', 'تكامل مغلق'),
    _MathItem(r'\int_0^{\infty}', r'\int_0^{\infty} ', 'من 0 إلى ∞'),
    _MathItem(r'\int_a^b f(x)dx', r'\int_a^b f(x)\,dx', 'تكامل دالة'),
  ]),

  // ── 5. عمليات كبرى (Large Operators) ──
  _MathCategoryData('عمليات', Icons.functions, [
    _MathItem(r'\sum', r'\sum ', 'مجموع'),
    _MathItem(r'\sum_{i=1}^{n}', r'\sum_{i=1}^{n} ', 'مجموع محدود'),
    _MathItem(r'\prod', r'\prod ', 'جداء'),
    _MathItem(r'\prod_{i=1}^{n}', r'\prod_{i=1}^{n} ', 'جداء محدود'),
    _MathItem(r'\coprod', r'\coprod ', 'جداء مشترك'),
    _MathItem(r'\bigcup', r'\bigcup ', 'اتحاد كبير'),
    _MathItem(r'\bigcap', r'\bigcap ', 'تقاطع كبير'),
    _MathItem(r'\bigoplus', r'\bigoplus ', 'جمع مباشر'),
    _MathItem(r'\bigotimes', r'\bigotimes ', 'ضرب تنسوري'),
  ]),

  // ── 6. أقواس (Brackets & Delimiters) ──
  _MathCategoryData('أقواس', Icons.data_array, [
    _MathItem(r'(\Box)', r'\left( \right)', 'أقواس دائرية'),
    _MathItem(r'[\Box]', r'\left[ \right]', 'أقواس مربعة'),
    _MathItem(r'\{\Box\}', r'\left\{ \right\}', 'أقواس مجموعة'),
    _MathItem(r'|\Box|', r'\left| \right|', 'قيمة مطلقة'),
    _MathItem(r'\|\Box\|', r'\left\| \right\|', 'نورم'),
    _MathItem(r'\langle \Box \rangle', r'\langle \rangle', 'أقواس زاوية'),
    _MathItem(r'\lceil \Box \rceil', r'\lceil \rceil', 'سقف'),
    _MathItem(r'\lfloor \Box \rfloor', r'\lfloor \rfloor', 'أرضية'),
  ]),

  // ── 7. دوال (Functions) ──
  _MathCategoryData('دوال', Icons.auto_graph, [
    _MathItem(r'\sin', r'\sin ', 'جيب'),
    _MathItem(r'\cos', r'\cos ', 'جيب تمام'),
    _MathItem(r'\tan', r'\tan ', 'ظل'),
    _MathItem(r'\cot', r'\cot ', 'ظل تمام'),
    _MathItem(r'\sec', r'\sec ', 'قاطع'),
    _MathItem(r'\csc', r'\csc ', 'قاطع تمام'),
    _MathItem(r'\sin^{-1}', r'\sin^{-1} ', 'جيب عكسي'),
    _MathItem(r'\cos^{-1}', r'\cos^{-1} ', 'جيب تمام عكسي'),
    _MathItem(r'\log', r'\log ', 'لوغاريتم'),
    _MathItem(r'\ln', r'\ln ', 'لوغاريتم طبيعي'),
    _MathItem(r'\log_2', r'\log_2 ', 'لوغ أساس 2'),
    _MathItem(r'\lim', r'\lim ', 'نهاية'),
    _MathItem(r'\lim_{x \to 0}', r'\lim_{x \to 0} ', 'نهاية x→0'),
    _MathItem(r'\lim_{x \to \infty}', r'\lim_{x \to \infty} ', 'نهاية x→∞'),
    _MathItem(r'\max', r'\max ', 'أقصى'),
    _MathItem(r'\min', r'\min ', 'أدنى'),
    _MathItem(r'\exp', r'\exp ', 'أسية'),
    _MathItem(r'\det', r'\det ', 'محدد'),
  ]),

  // ── 8. مصفوفات (Matrices) ──
  _MathCategoryData('مصفوفات', Icons.grid_on, [
    _MathItem(r'\begin{pmatrix}\end{pmatrix}', r'\begin{pmatrix} a & b \\ c & d \end{pmatrix}', 'مصفوفة 2×2'),
    _MathItem(r'\begin{bmatrix}\end{bmatrix}', r'\begin{bmatrix} a & b \\ c & d \end{bmatrix}', 'مصفوفة [ ] 2×2'),
    _MathItem(r'\begin{vmatrix}\end{vmatrix}', r'\begin{vmatrix} a & b \\ c & d \end{vmatrix}', 'محدد 2×2'),
    _MathItem(r'3\times3', r'\begin{pmatrix} a & b & c \\ d & e & f \\ g & h & i \end{pmatrix}', 'مصفوفة 3×3'),
    _MathItem(r'\vec{v}', r'\vec{v}', 'متجه'),
    _MathItem(r'\hat{u}', r'\hat{u}', 'متجه وحدة'),
    _MathItem(r'\dot{x}', r'\dot{x}', 'مشتقة نقطة'),
    _MathItem(r'\ddot{x}', r'\ddot{x}', 'مشتقة ثانية'),
    _MathItem(r'\bar{x}', r'\bar{x}', 'متوسط'),
  ]),

  // ── 9. حروف يونانية (Greek Letters) ──
  _MathCategoryData('يونانية', Icons.translate, [
    _MathItem(r'\alpha', r'\alpha', 'ألفا α'),
    _MathItem(r'\beta', r'\beta', 'بيتا β'),
    _MathItem(r'\gamma', r'\gamma', 'غاما γ'),
    _MathItem(r'\delta', r'\delta', 'دلتا δ'),
    _MathItem(r'\epsilon', r'\epsilon', 'إبسلون ε'),
    _MathItem(r'\zeta', r'\zeta', 'زيتا ζ'),
    _MathItem(r'\eta', r'\eta', 'إيتا η'),
    _MathItem(r'\theta', r'\theta', 'ثيتا θ'),
    _MathItem(r'\iota', r'\iota', 'أيوتا ι'),
    _MathItem(r'\kappa', r'\kappa', 'كابا κ'),
    _MathItem(r'\lambda', r'\lambda', 'لامدا λ'),
    _MathItem(r'\mu', r'\mu', 'مو μ'),
    _MathItem(r'\nu', r'\nu', 'نو ν'),
    _MathItem(r'\xi', r'\xi', 'كسي ξ'),
    _MathItem(r'\pi', r'\pi', 'باي π'),
    _MathItem(r'\rho', r'\rho', 'رو ρ'),
    _MathItem(r'\sigma', r'\sigma', 'سيجما σ'),
    _MathItem(r'\tau', r'\tau', 'تاو τ'),
    _MathItem(r'\phi', r'\phi', 'فاي φ'),
    _MathItem(r'\chi', r'\chi', 'كاي χ'),
    _MathItem(r'\psi', r'\psi', 'بساي ψ'),
    _MathItem(r'\omega', r'\omega', 'أوميجا ω'),
    _MathItem(r'\Gamma', r'\Gamma', 'غاما Γ'),
    _MathItem(r'\Delta', r'\Delta', 'دلتا Δ'),
    _MathItem(r'\Theta', r'\Theta', 'ثيتا Θ'),
    _MathItem(r'\Lambda', r'\Lambda', 'لامدا Λ'),
    _MathItem(r'\Sigma', r'\Sigma', 'سيجما Σ'),
    _MathItem(r'\Phi', r'\Phi', 'فاي Φ'),
    _MathItem(r'\Psi', r'\Psi', 'بساي Ψ'),
    _MathItem(r'\Omega', r'\Omega', 'أوميجا Ω'),
  ]),

  // ── 10. أسهم (Arrows) ──
  _MathCategoryData('أسهم', Icons.arrow_forward, [
    _MathItem(r'\rightarrow', r'\rightarrow', 'سهم يمين →'),
    _MathItem(r'\leftarrow', r'\leftarrow', 'سهم يسار ←'),
    _MathItem(r'\leftrightarrow', r'\leftrightarrow', 'سهم مزدوج ↔'),
    _MathItem(r'\uparrow', r'\uparrow', 'سهم أعلى ↑'),
    _MathItem(r'\downarrow', r'\downarrow', 'سهم أسفل ↓'),
    _MathItem(r'\Rightarrow', r'\Rightarrow', 'يقتضي ⇒'),
    _MathItem(r'\Leftarrow', r'\Leftarrow', 'عكس يقتضي ⇐'),
    _MathItem(r'\Leftrightarrow', r'\Leftrightarrow', 'تكافؤ ⇔'),
    _MathItem(r'\mapsto', r'\mapsto', 'تصوير ↦'),
    _MathItem(r'\to', r'\to', 'إلى →'),
    _MathItem(r'\nearrow', r'\nearrow', 'سهم شمال شرق'),
    _MathItem(r'\searrow', r'\searrow', 'سهم جنوب شرق'),
    _MathItem(r'\hookrightarrow', r'\hookrightarrow', 'سهم خطّاف'),
    _MathItem(r'\longrightarrow', r'\longrightarrow', 'سهم طويل'),
    _MathItem(r'\xrightarrow{}', r'\xrightarrow{text}', 'سهم بنص'),
  ]),

  // ── 11. علاقات ومقارنات (Relations) ──
  _MathCategoryData('علاقات', Icons.compare_arrows, [
    _MathItem(r'=', r'=', 'يساوي'),
    _MathItem(r'\neq', r'\neq', 'لا يساوي ≠'),
    _MathItem(r'<', r'<', 'أصغر'),
    _MathItem(r'>', r'>', 'أكبر'),
    _MathItem(r'\leq', r'\leq', 'أصغر أو يساوي ≤'),
    _MathItem(r'\geq', r'\geq', 'أكبر أو يساوي ≥'),
    _MathItem(r'\approx', r'\approx', 'تقريباً ≈'),
    _MathItem(r'\equiv', r'\equiv', 'مطابق ≡'),
    _MathItem(r'\sim', r'\sim', 'مشابه ~'),
    _MathItem(r'\simeq', r'\simeq', 'يشابه ≃'),
    _MathItem(r'\cong', r'\cong', 'متطابق ≅'),
    _MathItem(r'\propto', r'\propto', 'يتناسب ∝'),
    _MathItem(r'\ll', r'\ll', 'أصغر بكثير ≪'),
    _MathItem(r'\gg', r'\gg', 'أكبر بكثير ≫'),
    _MathItem(r'\perp', r'\perp', 'عمودي ⊥'),
    _MathItem(r'\parallel', r'\parallel', 'متوازي ∥'),
  ]),

  // ── 12. رموز رياضية (Math Operators & Symbols) ──
  _MathCategoryData('رموز', Icons.calculate, [
    _MathItem(r'\pm', r'\pm', 'زائد/ناقص ±'),
    _MathItem(r'\mp', r'\mp', 'ناقص/زائد ∓'),
    _MathItem(r'\times', r'\times', 'ضرب ×'),
    _MathItem(r'\div', r'\div', 'قسمة ÷'),
    _MathItem(r'\cdot', r'\cdot', 'نقطة ·'),
    _MathItem(r'\circ', r'\circ', 'دائرة ∘'),
    _MathItem(r'\infty', r'\infty', 'لانهاية ∞'),
    _MathItem(r'\partial', r'\partial', 'اشتقاق جزئي ∂'),
    _MathItem(r'\nabla', r'\nabla', 'نابلا ∇'),
    _MathItem(r'\forall', r'\forall', 'لكل ∀'),
    _MathItem(r'\exists', r'\exists', 'يوجد ∃'),
    _MathItem(r'\nexists', r'\nexists', 'لا يوجد ∄'),
    _MathItem(r'\neg', r'\neg', 'نفي ¬'),
    _MathItem(r'\wedge', r'\wedge', 'و (منطقي) ∧'),
    _MathItem(r'\vee', r'\vee', 'أو (منطقي) ∨'),
    _MathItem(r'\therefore', r'\therefore', 'إذن ∴'),
    _MathItem(r'\because', r'\because', 'بسبب ∵'),
    _MathItem(r'\angle', r'\angle', 'زاوية ∠'),
    _MathItem(r'\triangle', r'\triangle', 'مثلث △'),
    _MathItem(r'\square', r'\square', 'مربع □'),
  ]),

  // ── 13. مجموعات (Set Theory) ──
  _MathCategoryData('مجموعات', Icons.join_inner, [
    _MathItem(r'\in', r'\in', 'ينتمي ∈'),
    _MathItem(r'\notin', r'\notin', 'لا ينتمي ∉'),
    _MathItem(r'\subset', r'\subset', 'مجموعة جزئية ⊂'),
    _MathItem(r'\supset', r'\supset', 'مجموعة شاملة ⊃'),
    _MathItem(r'\subseteq', r'\subseteq', 'جزئية أو تساوي ⊆'),
    _MathItem(r'\supseteq', r'\supseteq', 'شاملة أو تساوي ⊇'),
    _MathItem(r'\cup', r'\cup', 'اتحاد ∪'),
    _MathItem(r'\cap', r'\cap', 'تقاطع ∩'),
    _MathItem(r'\setminus', r'\setminus', 'فرق ∖'),
    _MathItem(r'\emptyset', r'\emptyset', 'مجموعة فارغة ∅'),
    _MathItem(r'\mathbb{N}', r'\mathbb{N}', 'أعداد طبيعية ℕ'),
    _MathItem(r'\mathbb{Z}', r'\mathbb{Z}', 'أعداد صحيحة ℤ'),
    _MathItem(r'\mathbb{Q}', r'\mathbb{Q}', 'أعداد نسبية ℚ'),
    _MathItem(r'\mathbb{R}', r'\mathbb{R}', 'أعداد حقيقية ℝ'),
    _MathItem(r'\mathbb{C}', r'\mathbb{C}', 'أعداد مركّبة ℂ'),
  ]),
];

// ═══════════════════════════════════════════════════════════════
// MATH EMBED BUILDER
// ═══════════════════════════════════════════════════════════════

class MathEmbedBuilder extends quill.EmbedBuilder {
  final Function(String latex)? onFocusMath;
  final String? activeLatex;

  MathEmbedBuilder({this.onFocusMath, this.activeLatex});

  @override
  String get key => 'math';

  @override
  Widget build(BuildContext context, quill.EmbedContext embedContext) {
    final latex = embedContext.node.value.data as String;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black87;

    if (activeLatex == latex) {
      return Container(
        margin: const EdgeInsets.symmetric(vertical: 8),
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          border: Border.all(color: AppColors.primaryBlue, width: 2),
          borderRadius: BorderRadius.circular(8),
          color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.02),
        ),
        child: VisualMathField(
          nodes: VisualMathEditor.parseLatex(latex),
          isDark: isDark,
          textColor: textColor,
          onChanged: (newLatex) {
            if (newLatex != latex) {
              final offset = embedContext.node.offset;
              embedContext.controller.replaceText(offset, 1, quill.Embeddable('math', newLatex), null);
            }
          },
        ),
      );
    }

    return InkWell(
      onTap: () => onFocusMath?.call(latex),
      borderRadius: BorderRadius.circular(4),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        decoration: BoxDecoration(
          color: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.03),
          borderRadius: BorderRadius.circular(4),
        ),
        child: SafeMathPreview(latex: latex, textColor: textColor, mathSize: 18),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// IMAGE EMBED BUILDER (with delete button)
// ═══════════════════════════════════════════════════════════════

class ImageBlockEmbedBuilder extends quill.EmbedBuilder {
  final void Function(String imageUrl)? onDeleteImage;

  ImageBlockEmbedBuilder({this.onDeleteImage});

  @override
  String get key => quill.BlockEmbed.imageType;

  @override
  Widget build(BuildContext context, quill.EmbedContext embedContext) {
    final imageUrl = embedContext.node.value.data as String;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      width: double.infinity,
      alignment: Alignment.centerRight, // Arabic context, usually right aligned
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // ── Image Container ──
          Container(
            constraints: const BoxConstraints(
              maxHeight: 400,
              minHeight: 100, // Ensure it doesn't collapse
              minWidth: 100,
            ),
            decoration: BoxDecoration(
              color: isDark ? Colors.white.withValues(alpha: 0.03) : Colors.grey.shade50,
              border: Border.all(
                color: isDark ? Colors.white12 : Colors.grey.shade300,
                width: 1,
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.network(
                imageUrl,
                fit: BoxFit.contain,
                loadingBuilder: (context, child, loadingProgress) {
                  if (loadingProgress == null) return child;
                  return Container(
                    height: 150,
                    width: 200,
                    alignment: Alignment.center,
                    child: CircularProgressIndicator(
                      value: loadingProgress.expectedTotalBytes != null
                          ? loadingProgress.cumulativeBytesLoaded /
                              loadingProgress.expectedTotalBytes!
                          : null,
                      strokeWidth: 2,
                      color: AppColors.primaryBlue,
                    ),
                  );
                },
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    height: 120,
                    width: 200,
                    alignment: Alignment.center,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.broken_image_rounded, color: Colors.red.shade300, size: 32),
                        const SizedBox(height: 8),
                        Text(
                          'خطأ في تحميل الصورة',
                          style: TextStyle(fontSize: 12, color: Colors.red.shade300),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),

          // ── Delete Button ──
          Positioned(
            top: -10,
            left: -10,
            child: MouseRegion(
              cursor: SystemMouseCursors.click,
              child: GestureDetector(
                onTap: () {
                  final offset = embedContext.node.offset;
                  embedContext.controller.replaceText(offset, 1, '', null);
                  onDeleteImage?.call(imageUrl);
                },
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Colors.red.shade600,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.2),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.close_rounded,
                    color: Colors.white,
                    size: 14,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// RICH TEXT EDITOR
// ═══════════════════════════════════════════════════════════════

class RichTextEditor extends StatefulWidget {
  final String? initialHtml;
  final Function(String) onContentChanged;
  final String placeholder;
  final double height;
  final bool isCompact;
  final Color? textColor;
  final Function(String imageUrl)? onImageDeleted;

  const RichTextEditor({
    super.key,
    this.initialHtml,
    required this.onContentChanged,
    this.placeholder = 'اكتب هنا...',
    this.height = 200,
    this.isCompact = false,
    this.textColor,
    this.onImageDeleted,
  });

  @override
  State<RichTextEditor> createState() => _RichTextEditorState();
}

class _RichTextEditorState extends State<RichTextEditor> {
  late quill.QuillController _controller;
  final FocusNode _focusNode = FocusNode();
  final ScrollController _scrollController = ScrollController();
  bool _isFocused = false;
  bool _showMathToolbar = false;
  int _selectedMathCategory = 0;
  String? _activeMathLatex;
  final List<String> _deletedImageUrls = [];

  /// List of image URLs that were deleted from this editor
  List<String> get deletedImageUrls => List.unmodifiable(_deletedImageUrls);

  quill.Style get _selectionStyle => _controller.getSelectionStyle();

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(_onFocusChanged);
    _initializeController();
  }

  @override
  void dispose() {
    _focusNode.removeListener(_onFocusChanged);
    _focusNode.dispose();
    _controller.removeListener(_onContentChanged);
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onFocusChanged() {
    if (mounted) setState(() => _isFocused = _focusNode.hasFocus);
  }

  void _initializeController() {
    try {
      if (widget.initialHtml != null && widget.initialHtml!.isNotEmpty) {
        String html = MathUtils.normalizeMathContent(widget.initialHtml!);
        var delta = HtmlToDelta().convert(html);
        _controller = quill.QuillController(
          document: quill.Document.fromDelta(delta),
          selection: const TextSelection.collapsed(offset: 0),
        );
      } else {
        _controller = quill.QuillController.basic();
      }
    } catch (_) {
      _controller = quill.QuillController.basic();
    }
    _controller.addListener(_onContentChanged);
  }

  void _onContentChanged() {
    final delta = _controller.document.toDelta();
    final List<Map<String, dynamic>> processedOps = [];

    for (final op in delta.toJson()) {
      final insert = op['insert'];
      if (insert is Map && insert.containsKey('math')) {
        final latex = insert['math'].toString();
        processedOps.add({
          'insert': 'MATH_LATEX_START${latex}MATH_LATEX_END',
          'attributes': op['attributes'],
        });
      } else {
        processedOps.add(Map<String, dynamic>.from(op));
      }
    }

    final converter = QuillDeltaToHtmlConverter(
      processedOps,
      ConverterOptions(converterOptions: OpConverterOptions(inlineStylesFlag: true)),
    );

    String html = converter.convert();
    html = html.replaceAll('MATH_LATEX_START', '\\(');
    html = html.replaceAll('MATH_LATEX_END', '\\)');
    widget.onContentChanged(html);
  }

  void _toggleInlineStyle(quill.Attribute attribute) {
    _focusNode.requestFocus();
    final isActive = _selectionStyle.attributes.containsKey(attribute.key);
    _controller.formatSelection(isActive ? quill.Attribute.clone(attribute, null) : attribute);
  }

  Future<void> _uploadAndInsertImage() async {
    try {
      final result = await FilePicker.platform.pickFiles(type: FileType.image, allowMultiple: false, withData: true);
      if (result != null && result.files.isNotEmpty) {
        final file = result.files.first;
        if (file.bytes == null) return;
        if (!mounted) return;
        showDialog(context: context, barrierDismissible: false, builder: (_) => const Center(child: CircularProgressIndicator()));
        final storageService = FirebaseStorageService();
        final url = await storageService.uploadFile(fileBytes: file.bytes!, fileExtension: file.extension ?? 'png', folderName: 'question_images');
        if (mounted) Navigator.pop(context);
        if (url != null) {
          final index = _controller.selection.baseOffset;
          _controller.replaceText(index, 0, quill.BlockEmbed.image(url), null);
        }
      }
    } catch (_) {}
  }

  Widget _buildToolbarButton({
    required IconData icon,
    required VoidCallback onPressed,
    required bool isSelected,
    String? tooltip,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final foreground = isSelected ? Colors.white : (isDark ? Colors.white : AppColors.textPrimary);
    final background = isSelected ? AppColors.primaryBlue : Colors.transparent;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: IconButton(
        tooltip: tooltip,
        onPressed: onPressed,
        icon: Icon(icon, size: 18),
        style: IconButton.styleFrom(
          foregroundColor: foreground,
          backgroundColor: background,
          minimumSize: const Size(34, 34),
          padding: const EdgeInsets.all(8),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final editorBackground = isDark ? const Color(0xFF0F172A) : Colors.white;
    final toolbarBackground = isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC);

    return Container(
      decoration: BoxDecoration(
        color: editorBackground,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: _isFocused ? AppColors.primaryBlue : AppColors.borderLight,
          width: _isFocused ? 1.5 : 1,
        ),
      ),
      child: Column(
        children: [
          // ═══ TOP TOOLBAR ═══
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
            decoration: BoxDecoration(
              color: toolbarBackground,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(11)),
              border: Border(bottom: BorderSide(color: AppColors.borderLight.withValues(alpha: 0.5))),
            ),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildToolbarButton(
                    icon: Icons.format_bold,
                    isSelected: _selectionStyle.attributes.containsKey(quill.Attribute.bold.key),
                    onPressed: () => _toggleInlineStyle(quill.Attribute.bold),
                    tooltip: 'غامق',
                  ),
                  _buildToolbarButton(
                    icon: Icons.format_italic,
                    isSelected: _selectionStyle.attributes.containsKey(quill.Attribute.italic.key),
                    onPressed: () => _toggleInlineStyle(quill.Attribute.italic),
                    tooltip: 'مائل',
                  ),
                  _buildToolbarButton(
                    icon: Icons.format_underline,
                    isSelected: _selectionStyle.attributes.containsKey(quill.Attribute.underline.key),
                    onPressed: () => _toggleInlineStyle(quill.Attribute.underline),
                    tooltip: 'تسطير',
                  ),
                  const VerticalDivider(width: 12),
                  _buildToolbarButton(
                    icon: Icons.format_list_bulleted,
                    isSelected: _selectionStyle.attributes[quill.Attribute.list.key]?.value == 'bullet',
                    onPressed: () {
                      final isActive = _selectionStyle.attributes[quill.Attribute.list.key]?.value == 'bullet';
                      _controller.formatSelection(isActive ? quill.Attribute.clone(quill.Attribute.ol, null) : quill.Attribute.ul);
                    },
                    tooltip: 'قائمة نقطية',
                  ),
                  _buildToolbarButton(
                    icon: Icons.format_list_numbered,
                    isSelected: _selectionStyle.attributes[quill.Attribute.list.key]?.value == 'ordered',
                    onPressed: () {
                      final isActive = _selectionStyle.attributes[quill.Attribute.list.key]?.value == 'ordered';
                      _controller.formatSelection(isActive ? quill.Attribute.clone(quill.Attribute.ol, null) : quill.Attribute.ol);
                    },
                    tooltip: 'قائمة مرقّمة',
                  ),
                  const VerticalDivider(width: 12),
                  _buildToolbarButton(
                    icon: Icons.format_align_right,
                    isSelected: _selectionStyle.attributes[quill.Attribute.align.key]?.value == 'right',
                    onPressed: () => _controller.formatSelection(quill.Attribute.rightAlignment),
                    tooltip: 'محاذاة يمين',
                  ),
                  _buildToolbarButton(
                    icon: Icons.format_align_center,
                    isSelected: _selectionStyle.attributes[quill.Attribute.align.key]?.value == 'center',
                    onPressed: () => _controller.formatSelection(quill.Attribute.centerAlignment),
                    tooltip: 'توسيط',
                  ),
                  _buildToolbarButton(
                    icon: Icons.format_align_left,
                    isSelected: _selectionStyle.attributes[quill.Attribute.align.key]?.value == 'left',
                    onPressed: () => _controller.formatSelection(quill.Attribute.leftAlignment),
                    tooltip: 'محاذاة يسار',
                  ),
                  const VerticalDivider(width: 12),
                  _buildToolbarButton(
                    icon: Icons.image_rounded,
                    isSelected: false,
                    onPressed: _uploadAndInsertImage,
                    tooltip: 'إضافة صورة',
                  ),
                  // ★ MATH TOGGLE BUTTON
                  _buildToolbarButton(
                    icon: Icons.functions_rounded,
                    isSelected: _showMathToolbar,
                    onPressed: () => setState(() => _showMathToolbar = !_showMathToolbar),
                    tooltip: 'إدراج معادلة رياضية',
                  ),
                ],
              ),
            ),
          ),

          // ═══ EDITOR AREA ═══
          Stack(
            children: [
              SizedBox(
                height: widget.height,
                child: DefaultTextStyle(
                  style: TextStyle(
                    color: widget.textColor ?? (isDark ? Colors.white : AppColors.textPrimary),
                    fontSize: 16,
                  ),
                  child: quill.QuillEditor.basic(
                    controller: _controller,
                    focusNode: _focusNode,
                    scrollController: _scrollController,
                    config: quill.QuillEditorConfig(
                      padding: const EdgeInsets.all(12),
                      autoFocus: false,
                      expands: false,
                      embedBuilders: [
                        ImageBlockEmbedBuilder(
                          onDeleteImage: (url) {
                            _deletedImageUrls.add(url);
                            widget.onImageDeleted?.call(url);
                          },
                        ),
                        MathEmbedBuilder(
                          activeLatex: _activeMathLatex,
                          onFocusMath: (latex) => setState(() => _activeMathLatex = latex),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              if (_activeMathLatex != null)
                Positioned(
                  top: 5,
                  right: 5,
                  child: IconButton(
                    icon: const Icon(Icons.close_rounded, size: 18),
                    style: IconButton.styleFrom(
                      backgroundColor: AppColors.primaryBlue,
                      foregroundColor: Colors.white,
                      minimumSize: const Size(28, 28),
                    ),
                    onPressed: () => setState(() => _activeMathLatex = null),
                  ),
                ),
            ],
          ),

          // ═══ MATH TOOLBAR (Hidden by default, shown on fx click) ═══
          AnimatedCrossFade(
            firstChild: const SizedBox.shrink(),
            secondChild: _buildComprehensiveMathToolbar(isDark, toolbarBackground),
            crossFadeState: _showMathToolbar ? CrossFadeState.showSecond : CrossFadeState.showFirst,
            duration: const Duration(milliseconds: 250),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // COMPREHENSIVE MATH TOOLBAR (Word-like with categories)
  // ═══════════════════════════════════════════════════════════════

  Widget _buildComprehensiveMathToolbar(bool isDark, Color background) {
    final selectedCategory = _allMathCategories[_selectedMathCategory];
    final tabBg = isDark ? const Color(0xFF0F172A) : const Color(0xFFEEF2FF);
    final borderColor = AppColors.borderLight.withValues(alpha: 0.5);

    return Container(
      decoration: BoxDecoration(
        color: background,
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(11)),
        border: Border(top: BorderSide(color: borderColor)),
      ),
      child: Column(
        children: [
          // ── Category Tabs (scrollable) ──
          Container(
            height: 42,
            color: tabBg,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              itemCount: _allMathCategories.length,
              itemBuilder: (context, index) {
                final cat = _allMathCategories[index];
                final isActive = index == _selectedMathCategory;
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 3),
                  child: InkWell(
                    onTap: () => setState(() => _selectedMathCategory = index),
                    borderRadius: BorderRadius.circular(8),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: isActive ? AppColors.primaryBlue : Colors.transparent,
                        borderRadius: BorderRadius.circular(8),
                        border: isActive ? null : Border.all(color: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.05)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(cat.icon, size: 16, color: isActive ? Colors.white : (isDark ? Colors.white60 : Colors.black54)),
                          const SizedBox(width: 4),
                          Text(
                            cat.name,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: isActive ? FontWeight.bold : FontWeight.w500,
                              color: isActive ? Colors.white : (isDark ? Colors.white70 : Colors.black87),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),

          // ── Items Grid for selected category ──
          Container(
            height: 90,
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 10),
              itemCount: selectedCategory.items.length,
              itemBuilder: (context, index) {
                final item = selectedCategory.items[index];
                return _buildMathItemCard(item, isDark);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMathItemCard(_MathItem item, bool isDark) {
    final textColor = isDark ? Colors.white : Colors.black87;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 3),
      child: Tooltip(
        message: item.label,
        child: InkWell(
          onTap: () => _insertMathLatex(item.latex),
          borderRadius: BorderRadius.circular(8),
          child: Container(
            width: 70,
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: isDark ? Colors.white.withValues(alpha: 0.03) : Colors.white,
              border: Border.all(color: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.06)),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Expanded(
                  child: Center(
                    child: SafeMathPreview(latex: item.preview, textColor: textColor, mathSize: 14),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  item.label,
                  style: TextStyle(fontSize: 8, color: textColor.withValues(alpha: 0.6)),
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _insertMathLatex(String latex) {
    final index = _controller.selection.baseOffset;
    _controller.replaceText(index, 0, quill.Embeddable('math', latex), null);
    setState(() => _activeMathLatex = latex);
  }
}

import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_math_fork/flutter_math.dart';
import '../../theme/app_colors.dart';

class MathSymbolToolbar extends StatelessWidget {
  final Function(String) onSymbolSelected;
  final ScrollController? scrollController;

  const MathSymbolToolbar({
    super.key,
    required this.onSymbolSelected,
    this.scrollController,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final background = isDark ? const Color(0xFF1E293B) : Colors.white;
    final borderColor = AppColors.borderLight;

    return Container(
      height: 65,
      decoration: BoxDecoration(
        color: background,
        border: Border(
          bottom: BorderSide(color: borderColor.withValues(alpha: 0.5)),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ScrollConfiguration(
        behavior: ScrollConfiguration.of(context).copyWith(
          dragDevices: {
            PointerDeviceKind.touch,
            PointerDeviceKind.mouse,
            PointerDeviceKind.trackpad,
          },
        ),
        child: Scrollbar(
          controller: scrollController,
          thumbVisibility: false,
          child: ListView(
            scrollDirection: Axis.horizontal,
            controller: scrollController,
            physics: const AlwaysScrollableScrollPhysics(
              parent: BouncingScrollPhysics(),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            children: [
              _buildEquationButton(context),
              _buildCategoryMenu(
                context,
                'الرموز',
                'αΩ',
                [
                  _MathItem('α', 'ألفا', 'α'),
                  _MathItem('β', 'بيتا', 'β'),
                  _MathItem('γ', 'غاما', 'γ'),
                  _MathItem('δ', 'دلتا', 'δ'),
                  _MathItem('ε', 'إبسيلون', 'ε'),
                  _MathItem('ζ', 'زيتا', 'ζ'),
                  _MathItem('η', 'إيتا', 'η'),
                  _MathItem('θ', 'ثيتا', 'θ'),
                  _MathItem('ι', 'أيوتا', 'ι'),
                  _MathItem('κ', 'كابا', 'κ'),
                  _MathItem('λ', 'لامدا', 'λ'),
                  _MathItem('μ', 'ميو', 'μ'),
                  _MathItem('ν', 'نيو', 'ν'),
                  _MathItem('ξ', 'كسي', 'ξ'),
                  _MathItem('π', 'باي', 'π'),
                  _MathItem('ρ', 'رو', 'ρ'),
                  _MathItem('σ', 'سيغما', 'σ'),
                  _MathItem('τ', 'تاو', 'τ'),
                  _MathItem('φ', 'فاي', 'φ'),
                  _MathItem('χ', 'كاي', 'χ'),
                  _MathItem('ψ', 'بساي', 'ψ'),
                  _MathItem('ω', 'أوميغا', 'ω'),
                  _MathItem('Δ', 'دلتا كبيرة', 'Δ'),
                  _MathItem('Ω', 'أوميغا كبيرة', 'Ω'),
                  _MathItem('Σ', 'سيغما كبيرة', 'Σ'),
                  _MathItem('Φ', 'فاي كبيرة', 'Φ'),
                  _MathItem('∞', 'لانهاية', '∞'),
                  _MathItem('∂', 'اشتقاق جزئي', '∂'),
                  _MathItem('∇', 'نابلا', '∇'),
                  _MathItem('ℏ', 'ثابت بلانك', 'ℏ'),
                ],
              ),
              _buildCategoryMenu(
                context,
                'كيمياء',
                '⇌',
                [
                  _MathItem('→', 'سهم تفاعل', '→'),
                  _MathItem('⇌', 'تفاعل عكوس', '⇌'),
                  _MathItem('⇀', 'سهم أمامي', '⇀'),
                  _MathItem('↽', 'سهم عكسي', '↽'),
                  _MathItem('↑', 'غاز متصاعد', '↑'),
                  _MathItem('↓', 'راسب', '↓'),
                  _MathItem('(s)', 'حالة صلبة', '(s)'),
                  _MathItem('(l)', 'حالة سائلة', '(l)'),
                  _MathItem('(g)', 'حالة غازية', '(g)'),
                  _MathItem('(aq)', 'محلول مائي', '(aq)'),
                  _MathItem('₀', 'رقم سفلي 0', '₀'),
                  _MathItem('₁', 'رقم سفلي 1', '₁'),
                  _MathItem('₂', 'رقم سفلي 2', '₂'),
                  _MathItem('₃', 'رقم سفلي 3', '₃'),
                  _MathItem('₄', 'رقم سفلي 4', '₄'),
                  _MathItem('₅', 'رقم سفلي 5', '₅'),
                  _MathItem('₆', 'رقم سفلي 6', '₆'),
                  _MathItem('₇', 'رقم سفلي 7', '₇'),
                  _MathItem('₈', 'رقم سفلي 8', '₈'),
                  _MathItem('₉', 'رقم سفلي 9', '₉'),
                  _MathItem('⁰', 'رقم علوي 0', '⁰'),
                  _MathItem('¹', 'رقم علوي 1', '¹'),
                  _MathItem('²', 'رقم علوي 2', '²'),
                  _MathItem('³', 'رقم علوي 3', '³'),
                  _MathItem('⁴', 'رقم علوي 4', '⁴'),
                  _MathItem('⁺', 'شحنة موجبة', '⁺'),
                  _MathItem('⁻', 'شحنة سالبة', '⁻'),
                  _MathItem('²⁺', 'شحنة 2+', '²⁺'),
                  _MathItem('²⁻', 'شحنة 2-', '²⁻'),
                  _MathItem('³⁺', 'شحنة 3+', '³⁺'),
                  _MathItem('³⁻', 'شحنة 3-', '³⁻'),
                ],
              ),
              _buildCategoryMenu(
                context,
                'عمليات',
                '±÷',
                [
                  _MathItem('±', 'زائد أو ناقص', '±'),
                  _MathItem('∓', 'ناقص أو زائد', '∓'),
                  _MathItem('×', 'ضرب', '×'),
                  _MathItem('÷', 'قسمة', '÷'),
                  _MathItem('·', 'ضرب (نقطة)', '·'),
                  _MathItem('≠', 'لا يساوي', '≠'),
                  _MathItem('≈', 'تقريبا', '≈'),
                  _MathItem('≡', 'مطابق', '≡'),
                  _MathItem('≤', 'أقل أو يساوي', '≤'),
                  _MathItem('≥', 'أكبر أو يساوي', '≥'),
                  _MathItem('≪', 'أصغر بكثير', '≪'),
                  _MathItem('≫', 'أكبر بكثير', '≫'),
                  _MathItem('∝', 'تتناسب مع', '∝'),
                  _MathItem('∈', 'ينتمي إلى', '∈'),
                  _MathItem('∉', 'لا ينتمي إلى', '∉'),
                  _MathItem('⊂', 'مجموعة جزئية', '⊂'),
                  _MathItem('⊃', 'مجموعة شاملة', '⊃'),
                  _MathItem('∪', 'اتحاد', '∪'),
                  _MathItem('∩', 'تقاطع', '∩'),
                  _MathItem('∅', 'مجموعة فارغة', '∅'),
                  _MathItem('∀', 'لكل', '∀'),
                  _MathItem('∃', 'يوجد', '∃'),
                  _MathItem('∴', 'إذن', '∴'),
                  _MathItem('∵', 'لأن', '∵'),
                  _MathItem('⊥', 'عمودي على', '⊥'),
                  _MathItem('∥', 'يوازي', '∥'),
                  _MathItem('∠', 'زاوية', '∠'),
                  _MathItem('°', 'درجة', '°'),
                ],
              ),
              _buildCategoryMenu(
                context,
                'أسهم',
                '→',
                [
                  _MathItem('→', 'سهم لليمين', '→'),
                  _MathItem('←', 'سهم لليسار', '←'),
                  _MathItem('↔', 'سهم مزدوج', '↔'),
                  _MathItem('⇒', 'يؤدي إلى', '⇒'),
                  _MathItem('⇐', 'ينتج من', '⇐'),
                  _MathItem('⇔', 'إذا وفقط إذا', '⇔'),
                  _MathItem('↑', 'سهم للأعلى', '↑'),
                  _MathItem('↓', 'سهم للأسفل', '↓'),
                  _MathItem('⇌', 'توازن', '⇌'),
                ],
              ),
              _buildCategoryMenu(
                context,
                'دوال',
                'sin',
                [
                  _MathItem('sin', 'جا', 'sin'),
                  _MathItem('cos', 'جتا', 'cos'),
                  _MathItem('tan', 'ظا', 'tan'),
                  _MathItem('log', 'لوغاريتم', 'log'),
                  _MathItem('ln', 'لوغاريتم طبيعي', 'ln'),
                  _MathItem('lim', 'نهاية', 'lim'),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEquationButton(BuildContext context) {
    final accent = AppColors.primaryBlue;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: InkWell(
        onTap: () => _showEquationDialog(context),
        borderRadius: BorderRadius.circular(10),
        child: Container(
          width: 84,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                accent.withValues(alpha: 0.15),
                accent.withValues(alpha: 0.05)
              ],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: accent.withValues(alpha: 0.4)),
          ),
          child: const Center(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.functions, color: AppColors.primaryBlue, size: 24),
                  SizedBox(height: 2),
                  Text(
                    'معادلة',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: AppColors.primaryBlue,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _showEquationDialog(BuildContext context) {
    final controller = TextEditingController();
    String previewLatex = '';
    String selectedCategoryId = _equationCategories.first.id;

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF1E293B) : Colors.white;
    final textColor = isDark ? Colors.white : AppColors.textPrimary;
    final mutedTextColor = isDark ? Colors.white70 : AppColors.textSecondary;
    final borderColor = isDark ? Colors.white12 : AppColors.borderLight;
    final accentColor = AppColors.primaryBlue;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          return Dialog(
            backgroundColor: Colors.transparent,
            insetPadding: const EdgeInsets.all(16),
            child: Container(
              constraints: const BoxConstraints(maxWidth: 860, maxHeight: 720),
              decoration: BoxDecoration(
                color: bgColor,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.4),
                    blurRadius: 32,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.max,
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: accentColor.withValues(alpha: 0.1),
                      borderRadius:
                          const BorderRadius.vertical(top: Radius.circular(16)),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.functions, color: accentColor, size: 24),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'إدراج معادلة رياضية',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: textColor,
                            ),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          child: ElevatedButton.icon(
                            onPressed: previewLatex.isEmpty
                                ? null
                                : () {
                                    final result = '\\(${controller.text}\\)';
                                    Navigator.pop(ctx);
                                    onSymbolSelected(result);
                                  },
                            icon: const Icon(Icons.check, size: 18),
                            label: const Text('حفظ'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: accentColor,
                              foregroundColor: Colors.white,
                              disabledBackgroundColor:
                                  accentColor.withValues(alpha: 0.1),
                              disabledForegroundColor:
                                  textColor.withValues(alpha: 0.3),
                              elevation: 0,
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 8),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(20),
                              ),
                            ),
                          ),
                        ),
                        IconButton(
                          icon: Icon(Icons.close,
                              color: textColor.withValues(alpha: 0.6)),
                          onPressed: () => Navigator.pop(ctx),
                        ),
                      ],
                    ),
                  ),

                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          SizedBox(
                            height: 52,
                            child: ListView.separated(
                              scrollDirection: Axis.horizontal,
                              itemCount: _equationCategories.length,
                              separatorBuilder: (_, _) =>
                                  const SizedBox(width: 8),
                              itemBuilder: (context, index) {
                                final category = _equationCategories[index];
                                final selected =
                                    category.id == selectedCategoryId;
                                return InkWell(
                                  onTap: () {
                                    setDialogState(() {
                                      selectedCategoryId = category.id;
                                    });
                                  },
                                  borderRadius: BorderRadius.circular(12),
                                  child: AnimatedContainer(
                                    duration: const Duration(milliseconds: 180),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 14,
                                      vertical: 8,
                                    ),
                                    decoration: BoxDecoration(
                                      color: selected
                                          ? accentColor.withValues(alpha: 0.14)
                                          : Colors.transparent,
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: selected
                                            ? accentColor
                                            : borderColor,
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          category.icon,
                                          size: 18,
                                          color: selected
                                              ? accentColor
                                              : textColor,
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          category.label,
                                          style: TextStyle(
                                            color: selected
                                                ? accentColor
                                                : textColor,
                                            fontWeight: FontWeight.w700,
                                            fontSize: 13,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                          const SizedBox(height: 16),
                          ..._equationCategories
                              .firstWhere((c) => c.id == selectedCategoryId)
                              .groups
                              .map((group) {
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 18),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  Text(
                                    group.title,
                                    style: TextStyle(
                                      color: textColor,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                    ),
                                  ),
                                  const SizedBox(height: 10),
                                  LayoutBuilder(
                                    builder: (context, constraints) {
                                      final width = constraints.maxWidth;
                                      final crossAxisCount = width > 760
                                          ? 4
                                          : width > 520
                                              ? 3
                                              : 2;
                                      return GridView.builder(
                                        shrinkWrap: true,
                                        physics:
                                            const NeverScrollableScrollPhysics(),
                                        itemCount: group.templates.length,
                                        gridDelegate:
                                            SliverGridDelegateWithFixedCrossAxisCount(
                                          crossAxisCount: crossAxisCount,
                                          crossAxisSpacing: 10,
                                          mainAxisSpacing: 10,
                                          childAspectRatio:
                                              width > 760 ? 1.45 : 1.15,
                                        ),
                                        itemBuilder: (context, index) {
                                          final template =
                                              group.templates[index];
                                          return InkWell(
                                            onTap: () {
                                              controller.text = template.latex;
                                              setDialogState(() {
                                                previewLatex = template.latex;
                                              });
                                            },
                                            borderRadius:
                                                BorderRadius.circular(12),
                                            child: Container(
                                              padding: const EdgeInsets.all(12),
                                              decoration: BoxDecoration(
                                                color: Colors.transparent,
                                                borderRadius:
                                                    BorderRadius.circular(12),
                                                border: Border.all(
                                                  color: borderColor,
                                                ),
                                              ),
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.stretch,
                                                children: [
                                                  Expanded(
                                                    child: Center(
                                                      child: _SafeMathPreview(
                                                        latex: template.preview,
                                                        textColor: textColor,
                                                        mathSize: 16,
                                                      ),
                                                    ),
                                                  ),
                                                  const SizedBox(height: 8),
                                                  Text(
                                                    template.label,
                                                    textAlign: TextAlign.center,
                                                    style: TextStyle(
                                                      fontSize: 12,
                                                      color: textColor,
                                                      fontWeight:
                                                          FontWeight.w700,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          );
                                        },
                                      );
                                    },
                                  ),
                                ],
                              ),
                            );
                          }),

                          Text('قوالب سريعة:',
                              style: TextStyle(
                                  color: textColor,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14)),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: _equationTemplates.take(8).map((t) {
                              return ActionChip(
                                onPressed: () {
                                  controller.text = t.latex;
                                  setDialogState(() => previewLatex = t.latex);
                                },
                                backgroundColor: Colors.transparent,
                                side: BorderSide(color: borderColor),
                                label: Text(
                                  t.label,
                                  style: TextStyle(
                                    color: textColor,
                                    fontSize: 12,
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                          const SizedBox(height: 16),

                          Text('اكتب المعادلة بصيغة LaTeX:',
                              style: TextStyle(
                                  color: textColor,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14)),
                          const SizedBox(height: 8),
                          Directionality(
                            textDirection: TextDirection.ltr,
                            child: TextField(
                              controller: controller,
                              maxLines: 3,
                              style: TextStyle(
                                fontFamily: 'monospace',
                                fontSize: 14,
                                color: textColor,
                              ),
                              decoration: InputDecoration(
                                hintText:
                                    r'مثال: \frac{-b \pm \sqrt{b^2-4ac}}{2a}',
                                hintStyle: TextStyle(
                                    color:
                                        mutedTextColor.withValues(alpha: 0.5),
                                    fontSize: 12),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  borderSide: BorderSide(color: borderColor),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  borderSide: BorderSide(color: borderColor),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  borderSide: BorderSide(
                                      color: accentColor, width: 1.5),
                                ),
                                filled: true,
                                fillColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                              ),
                              onChanged: (val) {
                                setDialogState(() => previewLatex = val);
                              },
                            ),
                          ),

                          const SizedBox(height: 16),

                          Text('المعاينة:',
                              style: TextStyle(
                                  color: textColor,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14)),
                          const SizedBox(height: 8),
                          Container(
                            constraints: const BoxConstraints(minHeight: 120),
                            decoration: BoxDecoration(
                              color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                  color: accentColor.withValues(alpha: 0.3)),
                            ),
                            child: previewLatex.isEmpty
                                ? Center(
                                    child: Padding(
                                      padding: const EdgeInsets.all(20),
                                      child: Text(
                                        'ابدأ بالكتابة لرؤية المعاينة',
                                        style: TextStyle(
                                            color: mutedTextColor,
                                            fontSize: 13),
                                      ),
                                    ),
                                  )
                                : Padding(
                                    padding: const EdgeInsets.all(16),
                                    child: Center(
                                      child: _SafeMathPreview(
                                        latex: previewLatex,
                                        textColor: textColor,
                                        mathSize: 22,
                                      ),
                                    ),
                                  ),
                          ),
                        ],
                      ),
                    ),
                  ),

                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildCategoryMenu(
    BuildContext context,
    String label,
    String iconLabel,
    List<_MathItem> items,
  ) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final surface = isDark ? const Color(0xFF1E293B) : Colors.white;
    final borderColor = isDark ? Colors.white12 : AppColors.borderLight;
    final textPrimary = isDark ? Colors.white : AppColors.textPrimary;
    final textSecondary = isDark ? Colors.white70 : AppColors.textSecondary;
    final accent = AppColors.primaryBlue;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: PopupMenuButton<String>(
        onSelected: onSymbolSelected,
        offset: const Offset(0, -8),
        elevation: 10,
        color: surface,
        constraints: const BoxConstraints(maxHeight: 420, minWidth: 280),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: borderColor),
        ),
        tooltip: label,
        child: Container(
          width: 84,
          decoration: BoxDecoration(
            color: surface,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: borderColor),
          ),
          child: Center(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Directionality(
                    textDirection: TextDirection.ltr,
                    child: Text(
                      iconLabel,
                      style: TextStyle(
                        color: textPrimary,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ),
                  const SizedBox(height: 1),
                  Text(
                    label,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: textSecondary,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        itemBuilder: (context) => items.map((item) {
          return PopupMenuItem<String>(
            value: item.value,
            height: 44,
            child: Row(
              children: [
                Container(
                  width: 48,
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: accent.withValues(alpha: 0.25)),
                  ),
                  child: Directionality(
                    textDirection: TextDirection.ltr,
                    child: Text(
                      item.preview,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 14,
                        color: accent,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    item.label,
                    style: TextStyle(
                      fontSize: 13,
                      color: textPrimary,
                    ),
                    textAlign: TextAlign.right,
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  static final List<_EquationTemplate> _equationTemplates = [
    const _EquationTemplate(r'\frac{a}{b}', 'كسر', preview: r'\frac{\Box}{\Box}'),
    const _EquationTemplate(
      r'\frac{-b \pm \sqrt{b^2-4ac}}{2a}',
      'صيغة تربيعية',
      preview: r'\frac{-b \pm \sqrt{b^2-4ac}}{2a}',
    ),
    const _EquationTemplate(r'\sqrt{x}', 'جذر تربيعي', preview: r'\sqrt{\Box}'),
    const _EquationTemplate(r'x^{n}', 'أس', preview: r'x^{\Box}'),
    const _EquationTemplate(r'x_{n}', 'دليل سفلي', preview: r'x_{\Box}'),
    const _EquationTemplate(
      r'\sum_{i=1}^{n} x_i',
      'مجموع',
      preview: r'\sum_{i=1}^{n} x_i',
    ),
    const _EquationTemplate(
      r'\int_{a}^{b} f(x) \, dx',
      'تكامل محدد',
      preview: r'\int_{a}^{b} f(x)\,dx',
    ),
    const _EquationTemplate(
      r'\lim_{x \to \infty} f(x)',
      'نهاية',
      preview: r'\lim_{x\to\infty} f(x)',
    ),
  ];

  static final List<_EquationCategory> _equationCategories = [
    _EquationCategory(
      id: 'fractions',
      label: 'كسور',
      icon: Icons.horizontal_split,
      groups: [
        const _EquationGroup(
          title: 'كسور شائعة',
          templates: [
            _EquationTemplate(r'\frac{a}{b}', 'كسر بسيط',
                preview: r'\frac{\Box}{\Box}'),
            _EquationTemplate(r'\frac{dy}{dx}', 'مشتقة',
                preview: r'\frac{dy}{dx}'),
            _EquationTemplate(r'\frac{\Delta y}{\Delta x}', 'فرق محدود',
                preview: r'\frac{\Delta y}{\Delta x}'),
          ],
        ),
      ],
    ),
    _EquationCategory(
      id: 'scripts',
      label: 'علوي/سفلي',
      icon: Icons.keyboard_arrow_up,
      groups: [
        const _EquationGroup(
          title: 'أحرف منخفضة ومرتفعة',
          templates: [
            _EquationTemplate(r'x^{2}', 'أس عادي', preview: r'x^2'),
            _EquationTemplate(r'x_{1}', 'دليل سفلي', preview: r'x_1'),
            _EquationTemplate(r'x_{1}^{2}', 'سفلي وعلوي', preview: r'x_1^2'),
          ],
        ),
      ],
    ),
    _EquationCategory(
      id: 'radicals',
      label: 'جذور',
      icon: Icons.square_foot,
      groups: [
        const _EquationGroup(
          title: 'جذور',
          templates: [
            _EquationTemplate(r'\sqrt{x}', 'جذر تربيعي',
                preview: r'\sqrt{\Box}'),
            _EquationTemplate(r'\sqrt[3]{x}', 'جذر تكعيبي',
                preview: r'\sqrt[3]{\Box}'),
            _EquationTemplate(r'\sqrt[n]{x}', 'جذر نوني',
                preview: r'\sqrt[n]{\Box}'),
          ],
        ),
      ],
    ),
    _EquationCategory(
      id: 'integrals',
      label: 'تكامل',
      icon: Icons.functions,
      groups: [
        const _EquationGroup(
          title: 'تكاملات ونهايات',
          templates: [
            _EquationTemplate(r'\int f(x)\,dx', 'تكامل بسيط',
                preview: r'\int f(x)\,dx'),
            _EquationTemplate(r'\int_{a}^{b} f(x)\,dx', 'تكامل محدد',
                preview: r'\int_{a}^{b} f(x)\,dx'),
            _EquationTemplate(r'\sum_{i=1}^{n} x_i', 'مجموع كبير',
                preview: r'\sum_{i=1}^{n} x_i'),
            _EquationTemplate(r'\lim_{x\to\infty} f(x)', 'نهاية',
                preview: r'\lim_{x\to\infty} f(x)'),
          ],
        ),
      ],
    ),
  ];
}

class _MathItem {
  final String value;
  final String label;
  final String preview;

  _MathItem(this.value, this.label, this.preview);
}

class _EquationTemplate {
  final String latex;
  final String label;
  final String preview;

  const _EquationTemplate(
    this.latex,
    this.label, {
    String? preview,
  }) : preview = preview ?? latex;
}

class _EquationCategory {
  final String id;
  final String label;
  final IconData icon;
  final List<_EquationGroup> groups;

  const _EquationCategory({
    required this.id,
    required this.label,
    required this.icon,
    required this.groups,
  });
}

class _EquationGroup {
  final String title;
  final List<_EquationTemplate> templates;

  const _EquationGroup({
    required this.title,
    required this.templates,
  });
}

class _SafeMathPreview extends StatelessWidget {
  final String latex;
  final Color textColor;
  final double mathSize;

  const _SafeMathPreview({
    required this.latex,
    required this.textColor,
    this.mathSize = 16,
  });

  @override
  Widget build(BuildContext context) {
    if (latex.trim().isEmpty) {
      return const SizedBox.shrink();
    }
    return Directionality(
      textDirection: TextDirection.ltr,
      child: Math.tex(
        latex,
        textStyle: TextStyle(
          fontSize: mathSize,
          color: textColor,
        ),
        onErrorFallback: (err) => _LatexFallbackText(
          latex: latex,
          textColor: textColor,
          fontSize: mathSize * 0.75,
        ),
      ),
    );
  }
}

class _LatexFallbackText extends StatelessWidget {
  final String latex;
  final Color textColor;
  final double fontSize;

  const _LatexFallbackText({
    required this.latex,
    required this.textColor,
    required this.fontSize,
  });

  @override
  Widget build(BuildContext context) {
    return Text(
      latex,
      textAlign: TextAlign.center,
      style: TextStyle(
        fontFamily: 'monospace',
        fontSize: fontSize.clamp(9.0, 14.0),
        color: textColor.withValues(alpha: 0.7),
        height: 1.3,
      ),
    );
  }
}

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
              _buildSimpleCategoryMenu(
                context,
                'الرموز',
                'αΩ',
                [
                  _MathItem('α', 'ألفا', 'α'),
                  _MathItem('β', 'بيتا', 'β'),
                  _MathItem('γ', 'غاما', 'γ'),
                  _MathItem('δ', 'دلتا', 'δ'),
                  _MathItem('π', 'باي', 'π'),
                  _MathItem('∞', 'لانهاية', '∞'),
                  _MathItem('≠', 'لا يساوي', '≠'),
                  _MathItem('≈', 'تقريبا', '≈'),
                ],
              ),
              _buildSimpleCategoryMenu(
                context,
                'كيمياء',
                '⇌',
                [
                  _MathItem('→', 'سهم تفاعل', '→'),
                  _MathItem('⇌', 'تفاعل عكوس', '⇌'),
                  _MathItem('↑', 'غاز متصاعد', '↑'),
                  _MathItem('↓', 'راسب', '↓'),
                  _MathItem('₂', 'رقم سفلي 2', '₂'),
                  _MathItem('₃', 'رقم سفلي 3', '₃'),
                  _MathItem('⁺', 'شحنة موجب', '⁺'),
                  _MathItem('⁻', 'شحنة سالب', '⁻'),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSimpleCategoryMenu(
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
        constraints: const BoxConstraints(maxHeight: 420, minWidth: 200),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: borderColor),
        ),
        child: Container(
          width: 84,
          decoration: BoxDecoration(
            color: surface,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: borderColor),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(iconLabel, style: TextStyle(color: textPrimary, fontWeight: FontWeight.bold, fontSize: 16)),
              Text(label, style: TextStyle(color: textSecondary, fontSize: 12)),
            ],
          ),
        ),
        itemBuilder: (context) => items.map((item) {
          return PopupMenuItem<String>(
            value: item.value,
            child: Row(
              children: [
                Text(item.preview, style: TextStyle(fontSize: 14, color: accent, fontWeight: FontWeight.bold)),
                const SizedBox(width: 10),
                Expanded(child: Text(item.label, textAlign: TextAlign.right)),
              ],
            ),
          );
        }).toList(),
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
              colors: [accent.withValues(alpha: 0.15), accent.withValues(alpha: 0.05)],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: accent.withValues(alpha: 0.4)),
          ),
          child: const Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.functions, color: AppColors.primaryBlue, size: 24),
              Text('معادلة', style: TextStyle(color: AppColors.primaryBlue, fontSize: 12, fontWeight: FontWeight.bold)),
            ],
          ),
        ),
      ),
    );
  }

  void _showEquationDialog(BuildContext context) {
    final controller = TextEditingController();
    String previewLatex = '';

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF1E293B) : Colors.white;
    final textColor = isDark ? Colors.white : AppColors.textPrimary;
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
              constraints: const BoxConstraints(maxWidth: 900, maxHeight: 750),
              decoration: BoxDecoration(
                color: bgColor,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(color: Colors.black.withValues(alpha: 0.4), blurRadius: 32, spreadRadius: 2),
                ],
              ),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: accentColor.withValues(alpha: 0.1),
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.functions, color: accentColor, size: 24),
                        const SizedBox(width: 8),
                        const Expanded(child: Text('إدراج معادلة رياضية', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold))),
                        ElevatedButton.icon(
                          onPressed: previewLatex.isEmpty ? null : () {
                            onSymbolSelected('\\(${controller.text}\\)');
                            Navigator.pop(ctx);
                          },
                          icon: const Icon(Icons.check, size: 18),
                          label: const Text('حفظ'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: accentColor,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                          ),
                        ),
                        IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(ctx)),
                      ],
                    ),
                  ),

                  // Ribbon
                  Container(
                    height: 95,
                    color: isDark ? Colors.black.withValues(alpha: 0.2) : Colors.grey.withValues(alpha: 0.05),
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      itemCount: _equationCategories.length,
                      itemBuilder: (context, index) {
                        final cat = _equationCategories[index];
                        return Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: PopupMenuButton<String>(
                            onSelected: (template) {
                              final text = controller.text;
                              final selection = controller.selection;
                              final start = selection.start == -1 ? text.length : selection.start;
                              final end = selection.end == -1 ? text.length : selection.end;
                              final newText = text.replaceRange(start, end, template);
                              controller.value = TextEditingValue(
                                text: newText,
                                selection: TextSelection.collapsed(offset: start + template.length),
                              );
                              setDialogState(() => previewLatex = newText);
                            },
                            offset: const Offset(0, 85),
                            constraints: const BoxConstraints(maxWidth: 350, maxHeight: 450),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            child: SizedBox(
                              width: 85,
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  _SafeMathPreview(latex: cat.ribbonPreview, textColor: textColor, mathSize: 22),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Flexible(child: Text(cat.label, style: const TextStyle(fontSize: 11), overflow: TextOverflow.ellipsis)),
                                      const Icon(Icons.arrow_drop_down, size: 14),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            itemBuilder: (ctx) {
                              List<PopupMenuEntry<String>> entries = [];
                              for (var group in cat.groups) {
                                entries.add(PopupMenuItem(enabled: false, child: Text(group.title, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: accentColor))));
                                entries.add(PopupMenuItem<String>(
                                  padding: EdgeInsets.zero,
                                  child: Container(
                                    width: 350,
                                    padding: const EdgeInsets.all(12),
                                    child: Wrap(
                                      spacing: 10,
                                      runSpacing: 10,
                                      children: group.templates.map((t) {
                                        return InkWell(
                                          onTap: () => Navigator.pop(ctx, t.latex),
                                          child: Container(
                                            width: 70, height: 70,
                                            decoration: BoxDecoration(border: Border.all(color: borderColor.withValues(alpha: 0.3)), borderRadius: BorderRadius.circular(8)),
                                            child: Center(child: _SafeMathPreview(latex: t.preview, textColor: textColor, mathSize: 18)),
                                          ),
                                        );
                                      }).toList(),
                                    ),
                                  ),
                                ));
                              }
                              return entries;
                            },
                          ),
                        );
                      },
                    ),
                  ),

                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const Text('المعاينة:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                          const SizedBox(height: 12),
                          Container(
                            constraints: const BoxConstraints(minHeight: 200),
                            decoration: BoxDecoration(
                              color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: accentColor.withValues(alpha: 0.3), width: 1.5),
                            ),
                            child: previewLatex.isEmpty
                                ? const Center(child: Text('استخدم الشريط في الأعلى لإضافة الرموز'))
                                : Padding(padding: const EdgeInsets.all(24), child: Center(child: _SafeMathPreview(latex: previewLatex, textColor: textColor, mathSize: 32))),
                          ),
                          const SizedBox(height: 24),
                          const Text('تعديل القيم:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                          const SizedBox(height: 12),
                          Directionality(
                            textDirection: TextDirection.ltr,
                            child: TextField(
                              controller: controller,
                              maxLines: 4,
                              style: TextStyle(fontFamily: 'monospace', fontSize: 18, color: textColor),
                              decoration: InputDecoration(
                                filled: true,
                                fillColor: isDark ? const Color(0xFF0F172A) : Colors.white,
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                              onChanged: (val) => setDialogState(() => previewLatex = val),
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text('تلميح: المربعات الفارغة تمثل الأماكن التي يجب تعبئتها.', textAlign: TextAlign.center, style: TextStyle(color: accentColor, fontSize: 12, fontWeight: FontWeight.bold)),
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

  static final List<_EquationCategory> _equationCategories = [
    _EquationCategory(
      id: 'fractions', label: 'كسر', ribbonPreview: r'\frac{x}{y}',
      groups: [
        const _EquationGroup(title: 'كسور', templates: [
          _EquationTemplate(r'\frac{\Box}{\Box}', 'كسر عمودي', preview: r'\frac{\Box}{\Box}'),
          _EquationTemplate(r'{\Box}/{\Box}', 'كسر مائل', preview: r'{\Box}/{\Box}'),
          _EquationTemplate(r'\frac{dy}{dx}', 'مشتقة', preview: r'\frac{dy}{dx}'),
          _EquationTemplate(r'\frac{\Delta y}{\Delta x}', 'فرق', preview: r'\frac{\Delta y}{\Delta x}'),
          _EquationTemplate(r'\frac{\partial y}{\partial x}', 'معدل تغير', preview: r'\frac{\partial y}{\partial x}'),
          _EquationTemplate(r'\frac{\pi}{2}', 'باي على 2', preview: r'\frac{\pi}{2}'),
        ]),
      ],
    ),
    _EquationCategory(
      id: 'scripts', label: 'أس', ribbonPreview: r'e^x',
      groups: [
        const _EquationGroup(title: 'نص علوي وسفلي', templates: [
          _EquationTemplate(r'{\Box}^{\Box}', 'أس', preview: r'{\Box}^{\Box}'),
          _EquationTemplate(r'{\Box}_{\Box}', 'دليل سفلي', preview: r'{\Box}_{\Box}'),
          _EquationTemplate(r'{\Box}_{\Box}^{\Box}', 'سفلي وعلوي', preview: r'{\Box}_{\Box}^{\Box}'),
          _EquationTemplate(r'{}^{\Box}_{\Box}{\Box}', 'يسار علوي وسفلي', preview: r'{}^{\Box}_{\Box}{\Box}'),
        ]),
      ],
    ),
    _EquationCategory(
      id: 'radicals', label: 'جذري', ribbonPreview: r'\sqrt[n]{x}',
      groups: [
        const _EquationGroup(title: 'جذور', templates: [
          _EquationTemplate(r'\sqrt{\Box}', 'جذر تربيعي', preview: r'\sqrt{\Box}'),
          _EquationTemplate(r'\sqrt[3]{\Box}', 'جذر تكعيبي', preview: r'\sqrt[3]{\Box}'),
          _EquationTemplate(r'\sqrt[{\Box}]{\Box}', 'جذر نوني', preview: r'\sqrt[{\Box}]{\Box}'),
          _EquationTemplate(r'\frac{-b \pm \sqrt{b^2-4ac}}{2a}', 'قانون عام', preview: r'\frac{-b \pm \sqrt{b^2-4ac}}{2a}'),
        ]),
      ],
    ),
    _EquationCategory(
      id: 'integrals', label: 'تكامل', ribbonPreview: r'\int',
      groups: [
        const _EquationGroup(title: 'تكاملات', templates: [
          _EquationTemplate(r'\int {\Box} \, dx', 'تكامل', preview: r'\int {\Box}\,dx'),
          _EquationTemplate(r'\int_{\Box}^{\Box} {\Box} \, dx', 'تكامل محدد', preview: r'\int_{\Box}^{\Box} {\Box}\,dx'),
          _EquationTemplate(r'\iint {\Box} \, dA', 'تكامل ثنائي', preview: r'\iint {\Box} \, dA'),
          _EquationTemplate(r'\oint {\Box} \, ds', 'تكامل مسار', preview: r'\oint {\Box} \, ds'),
        ]),
      ],
    ),
    _EquationCategory(
      id: 'large_op', label: 'عامل كبير', ribbonPreview: r'\sum',
      groups: [
        const _EquationGroup(title: 'مجموع ومنتجات', templates: [
          _EquationTemplate(r'\sum_{i=1}^{n} {\Box}', 'مجموع', preview: r'\sum_{i=0}^{n} {\Box}'),
          _EquationTemplate(r'\prod_{i=1}^{n} {\Box}', 'جداء', preview: r'\prod_{i=0}^{n} {\Box}'),
          _EquationTemplate(r'\coprod_{i=1}^{n} {\Box}', 'مرافق جداء', preview: r'\coprod_{i=0}^{n} {\Box}'),
          _EquationTemplate(r'\bigcap_{\Box}^{\Box}', 'تقاطع', preview: r'\bigcap_{\Box}^{\Box}'),
          _EquationTemplate(r'\bigcup_{\Box}^{\Box}', 'اتحاد', preview: r'\bigcup_{\Box}^{\Box}'),
        ]),
      ],
    ),
    _EquationCategory(
      id: 'brackets', label: 'أقواس', ribbonPreview: r'\{()\}',
      groups: [
        const _EquationGroup(title: 'أقواس وأسوار', templates: [
          _EquationTemplate(r'( {\Box} )', 'قوس دائري', preview: r'( {\Box} )'),
          _EquationTemplate(r'[ {\Box} ]', 'قوس مربع', preview: r'[ {\Box} ]'),
          _EquationTemplate(r'\{ {\Box} \}', 'مجموعة', preview: r'\{ {\Box} \}'),
          _EquationTemplate(r'| {\Box} |', 'قيمة مطلقة', preview: r'| {\Box} |'),
          _EquationTemplate(r'\| {\Box} \|', 'نظيم', preview: r'\| {\Box} \|'),
          _EquationTemplate(r'\langle {\Box} \rangle', 'قوس زاوية', preview: r'\langle {\Box} \rangle'),
        ]),
      ],
    ),
    _EquationCategory(
      id: 'functions', label: 'دالة', ribbonPreview: r'\sin \theta',
      groups: [
        const _EquationGroup(title: 'تطبيقات مثلثية', templates: [
          _EquationTemplate(r'\sin({\Box})', 'جا', preview: r'\sin'),
          _EquationTemplate(r'\cos({\Box})', 'جتا', preview: r'\cos'),
          _EquationTemplate(r'\tan({\Box})', 'ظا', preview: r'\tan'),
          _EquationTemplate(r'\sin^{-1}({\Box})', 'جا عكسي', preview: r'\sin^{-1}'),
          _EquationTemplate(r'\sinh({\Box})', 'جا زائدية', preview: r'\sinh'),
        ]),
      ],
    ),
    _EquationCategory(
      id: 'accents', label: 'حركة', ribbonPreview: r'\ddot{a}',
      groups: [
        const _EquationGroup(title: 'رموز فوقية', templates: [
          _EquationTemplate(r'\hat{\Box}', 'هات', preview: r'\hat{\Box}'),
          _EquationTemplate(r'\bar{\Box}', 'بار', preview: r'\bar{\Box}'),
          _EquationTemplate(r'\dot{\Box}', 'نقطة', preview: r'\dot{\Box}'),
          _EquationTemplate(r'\ddot{\Box}', 'نقطتين', preview: r'\ddot{\Box}'),
          _EquationTemplate(r'\vec{\Box}', 'متجه', preview: r'\vec{\Box}'),
          _EquationTemplate(r'\tilde{\Box}', 'موجة', preview: r'\tilde{\Box}'),
        ]),
      ],
    ),
    _EquationCategory(
      id: 'limits', label: 'حد وسجل', ribbonPreview: r'\lim_{n \to \infty}',
      groups: [
        const _EquationGroup(title: 'نهايات ولوغاريتمات', templates: [
          _EquationTemplate(r'\lim_{x \to {\Box}} {\Box}', 'نهاية', preview: r'\lim_{x\to\infty}'),
          _EquationTemplate(r'\log_{\Box}({\Box})', 'لوغاريتم', preview: r'\log_{\Box}'),
          _EquationTemplate(r'\ln({\Box})', 'لوغاريتم طبيعي', preview: r'\ln'),
          _EquationTemplate(r'\min_{\Box} {\Box}', 'قيمة صغرى', preview: r'\min_{\Box}'),
          _EquationTemplate(r'\max_{\Box} {\Box}', 'قيمة عظمى', preview: r'\max_{\Box}'),
        ]),
      ],
    ),
    _EquationCategory(
      id: 'matrix', label: 'مصفوفة', ribbonPreview: r'[ \begin{smallmatrix} 1 & 0 \\ 0 & 1 \end{smallmatrix} ]',
      groups: [
        const _EquationGroup(title: 'مصفوفات', templates: [
          _EquationTemplate(r'\begin{pmatrix} \Box & \Box \\ \Box & \Box \end{pmatrix}', '2x2 دائرية', preview: r'\begin{pmatrix} \cdot & \cdot \\ \cdot & \cdot \end{pmatrix}'),
          _EquationTemplate(r'\begin{bmatrix} \Box & \Box \\ \Box & \Box \end{bmatrix}', '2x2 مربعة', preview: r'\begin{bmatrix} \cdot & \cdot \\ \cdot & \cdot \end{bmatrix}'),
          _EquationTemplate(r'\begin{matrix} \Box & \Box & \Box \\ \Box & \Box & \Box \end{matrix}', '2x3 مستطيلة', preview: r'\begin{matrix} \cdot & \cdot & \cdot \\ \cdot & \cdot & \cdot \end{matrix}'),
          _EquationTemplate(r'\begin{vmatrix} \Box & \Box \\ \Box & \Box \end{vmatrix}', 'محدد', preview: r'\begin{vmatrix} \cdot & \cdot \\ \cdot & \cdot \end{vmatrix}'),
        ]),
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
  const _EquationTemplate(this.latex, this.label, {String? preview}) : preview = preview ?? latex;
}

class _EquationCategory {
  final String id;
  final String label;
  final String ribbonPreview;
  final List<_EquationGroup> groups;
  const _EquationCategory({required this.id, required this.label, required this.ribbonPreview, required this.groups});
}

class _EquationGroup {
  final String title;
  final List<_EquationTemplate> templates;
  const _EquationGroup({required this.title, required this.templates});
}

class _SafeMathPreview extends StatelessWidget {
  final String latex;
  final Color textColor;
  final double mathSize;
  const _SafeMathPreview({required this.latex, required this.textColor, this.mathSize = 16});

  @override
  Widget build(BuildContext context) {
    if (latex.trim().isEmpty) return const SizedBox.shrink();
    return Directionality(
      textDirection: TextDirection.ltr,
      child: Math.tex(latex, textStyle: TextStyle(fontSize: mathSize, color: textColor),
        onErrorFallback: (err) => Text(latex, style: TextStyle(color: textColor, fontSize: mathSize * 0.75))),
    );
  }
}

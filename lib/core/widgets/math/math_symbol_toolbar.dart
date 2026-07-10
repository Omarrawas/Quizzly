import 'dart:ui';
import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';
import 'visual_math_editor.dart';

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
    final background = isDark ? const Color(0xFF131A26) : Colors.white;
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
    final surface = isDark ? const Color(0xFF131A26) : Colors.white;
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
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(16),
        child: SizedBox(
          width: 950,
          height: 650,
          child: VisualMathEditor(
            onSave: (latex) {
              onSymbolSelected('\\($latex\\)');
              Navigator.pop(ctx);
            },
          ),
        ),
      ),
    );
  }
}

class _MathItem {
  final String value;
  final String label;
  final String preview;
  _MathItem(this.value, this.label, this.preview);
}

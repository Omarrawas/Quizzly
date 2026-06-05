import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../bloc/math_expression/math_expression_bloc.dart';

class ActionButtons extends StatelessWidget {
  final VoidCallback copyAsImage;
  final VoidCallback copyLatexToClipboard;
  final VoidCallback copyAsFormula;
  final VoidCallback exportAsImage;
  final VoidCallback exportAsSVG;
  final VoidCallback saveExpression;
  final VoidCallback showRenderedExpressionSettings;
  final bool useMobileLayout;

  const ActionButtons({
    super.key,
    required this.copyAsImage,
    required this.copyLatexToClipboard,
    required this.copyAsFormula,
    required this.exportAsImage,
    required this.showRenderedExpressionSettings,
    required this.exportAsSVG,
    required this.saveExpression,
    this.useMobileLayout = false,
  });

  @override
  Widget build(BuildContext context) {
    if (useMobileLayout) {
      return SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            IconButton(
              icon: const Icon(Icons.copy),
              onPressed: copyAsImage,
              tooltip: 'Copy as Image',
            ),
            IconButton(
              icon: const Icon(Icons.code),
              onPressed: copyLatexToClipboard,
              tooltip: 'Copy LaTeX',
            ),
            IconButton(
              icon: const Icon(Icons.image),
              onPressed: exportAsImage,
              tooltip: 'Export as Image',
            ),
            IconButton(
              icon: const Icon(Icons.save),
              onPressed: saveExpression,
              tooltip: 'Save',
            ),
          ],
        ),
      );
    }
    return BlocListener<MathExpressionBloc, MathExpressionState>(
      listener: (context, state) {
        if (state is MathExpressionError) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(state.message)),
          );
        }
      },
      child: Wrap(
        spacing: 16,
        runSpacing: 16,
        children: [
          ElevatedButton.icon(
            onPressed: saveExpression,
            icon: const Icon(Icons.save),
            label: const Text('Save'),
          ),
          ElevatedButton.icon(
            onPressed: copyLatexToClipboard,
            icon: const Icon(Icons.code),
            label: const Text('Copy LaTeX'),
          ),
          ElevatedButton.icon(
            onPressed: showRenderedExpressionSettings,
            icon: const Icon(Icons.settings_suggest_outlined),
            label: const Text('Style'),
          ),
        ],
      ),
    );
  }
}

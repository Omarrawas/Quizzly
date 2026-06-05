import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:math_keyboard/math_keyboard.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'bloc/math_expression/math_expression_bloc.dart';
import 'bloc/settings/settings_bloc.dart';
import 'math_expression/action_buttons.dart';
import 'math_expression/dialogs/rendered_expression_dialog.dart';
import 'math_expression/dialogs/settings_dialog.dart';
import 'math_expression/math_field_widget.dart';
import 'math_expression/rendered_expression.dart';
import 'math_expression/services/settings_service.dart';
import 'math_expression/symbol_selector.dart';

class QuizzlyMathEditor extends StatefulWidget {
  final String initialLatex;

  const QuizzlyMathEditor({
    super.key,
    this.initialLatex = '',
  });

  static Future<String?> show(BuildContext context, {String initialLatex = ''}) {
    return showDialog<String>(
      context: context,
      builder: (context) => QuizzlyMathEditor(initialLatex: initialLatex),
    );
  }

  @override
  State<QuizzlyMathEditor> createState() => _QuizzlyMathEditorState();
}

class _QuizzlyMathEditorState extends State<QuizzlyMathEditor> {
  late MathFieldEditingController _controller;
  String _searchQuery = '';
  final GlobalKey _expressionKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _controller = MathFieldEditingController();
    if (widget.initialLatex.isNotEmpty) {
      _controller.updateValue(TeXParser(widget.initialLatex).parse());
    }
    _controller.addListener(_onExpressionChanged);
  }

  @override
  void dispose() {
    _controller.removeListener(_onExpressionChanged);
    _controller.dispose();
    super.dispose();
  }

  void _onExpressionChanged() {
    final expression = _controller.currentEditingValue();
    context.read<MathExpressionBloc>().add(UpdateExpression(expression));
  }

  void _updateSearchQuery(String query) {
    setState(() {
      _searchQuery = query;
    });
  }

  void _clearExpression() {
    _controller.clear();
    context.read<MathExpressionBloc>().add(const UpdateExpression(''));
  }

  void _copyLatexToClipboard() {
    final state = context.read<MathExpressionBloc>().state;
    if (state is MathExpressionUpdated) {
      Clipboard.setData(ClipboardData(text: state.expression));
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('LaTeX copied to clipboard')),
      );
    }
  }

  void _saveAndExit() {
    final state = context.read<MathExpressionBloc>().state;
    String latex = state.currentExpression;
    if (latex.isEmpty) {
      latex = _controller.currentEditingValue();
    }
    Navigator.of(context).pop(latex);
  }

  @override
  Widget build(BuildContext context) {
    return Dialog.fullscreen(
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Math Editor'),
          leading: IconButton(
            icon: const Icon(Icons.close),
            onPressed: () => Navigator.of(context).pop(),
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.delete_outline),
              onPressed: _clearExpression,
              tooltip: 'Clear',
            ),
            IconButton(
              icon: const Icon(Icons.settings_outlined),
              onPressed: () => showDialog(
                context: context,
                builder: (context) => const SettingsDialog(),
              ),
              tooltip: 'Settings',
            ),
            TextButton(
              onPressed: _saveAndExit,
              child: const Text('DONE', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
        body: Column(
          children: [
            Expanded(
              child: SymbolSelector(
                searchQuery: _searchQuery,
                updateSearchQuery: _updateSearchQuery,
                showSuggestions: false,
                suggestions: const [],
                onSymbolSelected: (symbol) {
                  _controller.addLeaf(symbol);
                },
              ),
            ),
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(12),
              child: MathFieldWidget(
                controller: _controller,
                onClear: _clearExpression,
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: ActionButtons(
                copyAsImage: () {}, // Not implemented
                copyLatexToClipboard: _copyLatexToClipboard,
                copyAsFormula: () {}, // Not implemented
                exportAsImage: () {}, // Not implemented
                showRenderedExpressionSettings: () => showDialog(
                  context: context,
                  builder: (context) => const RenderedExpressionDialog(),
                ),
                exportAsSVG: () {}, // Not implemented
                saveExpression: _saveAndExit,
                useMobileLayout: true,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              height: 100,
              width: double.infinity,
              margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.shade300),
                borderRadius: BorderRadius.circular(8),
                color: Colors.grey.shade50,
              ),
              child: Center(
                child: RepaintBoundary(
                  key: _expressionKey,
                  child: const RenderedExpression(),
                ),
              ),
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }
}

/// A wrapper to provide necessary Blocs
class QuizzlyMathEditorProvider extends StatelessWidget {
  final String initialLatex;

  const QuizzlyMathEditorProvider({
    super.key,
    this.initialLatex = '',
  });

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<SharedPreferences>(
      future: SharedPreferences.getInstance(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final prefs = snapshot.data!;
        final settingsService = SettingsService(sharedPreferences: prefs);

        return MultiBlocProvider(
          providers: [
            BlocProvider(
              create: (context) => MathExpressionBloc()
                ..add(SetExpression(initialLatex)),
            ),
            BlocProvider(
              create: (context) => SettingsBloc(settingsService: settingsService)
                ..add(LoadSettings()),
            ),
          ],
          child: QuizzlyMathEditor(initialLatex: initialLatex),
        );
      },
    );
  }
}

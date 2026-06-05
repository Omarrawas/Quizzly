import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:math_keyboard/math_keyboard.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'bloc/math_expression/math_expression_bloc.dart';
import 'bloc/settings/settings_bloc.dart';
import 'math_expression/math_field_widget.dart';

import 'math_expression/services/settings_service.dart';
import 'math_expression/symbol_selector.dart';

class QuizzlyMathEditor extends StatefulWidget {
  final String initialLatex;

  const QuizzlyMathEditor({super.key, this.initialLatex = ''});

  static Future<String?> show(
    BuildContext context, {
    String initialLatex = '',
  }) {
    return showDialog<String>(
      context: context,
      builder: (context) => QuizzlyMathEditor(initialLatex: initialLatex),
    );
  }

  @override
  State<QuizzlyMathEditor> createState() => _QuizzlyMathEditorState();
}

class PasteIntent extends Intent {
  const PasteIntent();
}

class _QuizzlyMathEditorState extends State<QuizzlyMathEditor> {
  late MathFieldEditingController _controller;
  String _searchQuery = '';
  bool _isSearchVisible = false;

  @override
  void initState() {
    super.initState();
    _controller = MathFieldEditingController();
    if (widget.initialLatex.isNotEmpty) {
      try {
        _controller.updateValue(TeXParser(widget.initialLatex).parse());
      } catch (e) {
        debugPrint('Error parsing initial LaTeX: $e');
      }
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

  Future<void> _handlePaste() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    if (data != null && data.text != null) {
      final text = data.text!;
      try {
        _controller.updateValue(TeXParser(text).parse());
      } catch (e) {
        // Fallback or ignore if not valid LaTeX
      }
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
      child: Shortcuts(
        shortcuts: <LogicalKeySet, Intent>{
          LogicalKeySet(LogicalKeyboardKey.control, LogicalKeyboardKey.keyV):
              const PasteIntent(),
        },
        child: Actions(
          actions: <Type, Action<Intent>>{
            PasteIntent: CallbackAction<PasteIntent>(
              onInvoke: (intent) async {
                await _handlePaste();
                return null;
              },
            ),
          },
          child: Theme(
            data: Theme.of(context).copyWith(
              canvasColor: Colors.black.withValues(alpha: 0.7),
              scaffoldBackgroundColor: Colors.transparent,
              cardColor: Colors.black.withValues(alpha: 0.5),
            ),
            child: Scaffold(
              backgroundColor: Colors.transparent,
              appBar: AppBar(
                toolbarHeight: 40,
                backgroundColor: Theme.of(
                  context,
                ).appBarTheme.backgroundColor?.withValues(alpha: 0.9),
                title: const Text(
                  'محرر الرياضيات',
                  style: TextStyle(fontSize: 16),
                ),
                leading: IconButton(
                  icon: const Icon(Icons.close, size: 18),
                  onPressed: () => Navigator.of(context).pop(),
                ),
                actions: [
                  IconButton(
                    icon: Icon(
                      _isSearchVisible ? Icons.search_off : Icons.search,
                      size: 18,
                    ),
                    onPressed: () {
                      setState(() {
                        _isSearchVisible = !_isSearchVisible;
                        if (!_isSearchVisible) _searchQuery = '';
                      });
                    },
                    tooltip: 'البحث عن رموز',
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_outline, size: 18),
                    onPressed: _clearExpression,
                    tooltip: 'مسح',
                  ),
                  TextButton(
                    onPressed: _saveAndExit,
                    child: const Text(
                      'حفظ',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                ],
              ),
              body: Column(
                children: [
                  // Symbol selector takes all available space
                  Expanded(
                    child: SymbolSelector(
                      searchQuery: _searchQuery,
                      updateSearchQuery: _updateSearchQuery,
                      isSearchVisible: _isSearchVisible,
                      showSuggestions: false,
                      suggestions: const [],
                      onSymbolSelected: (symbol) {
                        _controller.addLeaf(symbol);
                      },
                    ),
                  ),
                  // Fixed bottom panel: writing area + preview
                  const Divider(height: 1),
                  Container(
                    color: Theme.of(context).cardColor,
                    padding: const EdgeInsets.fromLTRB(12, 6, 12, 4),
                    child: MathFieldWidget(
                      controller: _controller,
                      onClear: _clearExpression,
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A wrapper to provide necessary Blocs
class QuizzlyMathEditorProvider extends StatelessWidget {
  final String initialLatex;

  const QuizzlyMathEditorProvider({super.key, this.initialLatex = ''});

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
              create: (context) =>
                  MathExpressionBloc()..add(SetExpression(initialLatex)),
            ),
            BlocProvider(
              create: (context) =>
                  SettingsBloc(settingsService: settingsService)
                    ..add(LoadSettings()),
            ),
          ],
          child: QuizzlyMathEditor(initialLatex: initialLatex),
        );
      },
    );
  }
}

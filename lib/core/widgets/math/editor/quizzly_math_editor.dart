import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'bloc/math_expression/math_expression_bloc.dart';
import 'bloc/settings/settings_bloc.dart';
import 'math_expression/math_field_widget.dart';
import 'math_expression/rendered_expression.dart';
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
  late TextEditingController _controller;
  String _searchQuery = '';
  bool _isSearchVisible = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialLatex);
    _controller.addListener(_onTextChanged);
    // Fire initial state
    if (widget.initialLatex.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        context.read<MathExpressionBloc>().add(UpdateExpression(widget.initialLatex));
      });
    }
  }

  @override
  void dispose() {
    _controller.removeListener(_onTextChanged);
    _controller.dispose();
    super.dispose();
  }

  void _onTextChanged() {
    context.read<MathExpressionBloc>().add(UpdateExpression(_controller.text));
  }

  void _insertAtCursor(String symbol) {
    final sel = _controller.selection;
    final text = _controller.text;
    final start = sel.isValid ? sel.start : text.length;
    final end = sel.isValid ? sel.end : text.length;
    final newText = text.replaceRange(start, end, symbol);
    _controller.value = _controller.value.copyWith(
      text: newText,
      selection: TextSelection.collapsed(offset: start + symbol.length),
    );
  }

  void _updateSearchQuery(String query) {
    setState(() => _searchQuery = query);
  }

  void _clearExpression() {
    _controller.clear();
    context.read<MathExpressionBloc>().add(const UpdateExpression(''));
  }

  /// Converts pasted text (e.g. from Word) to valid LaTeX.
  String _processWordPaste(String text) {
    var result = text;

    // 1. Strip Word OLE/bracket junk: sequences of standalone [ or ] with spaces
    //    e.g. "[ [ [ [ [Ag..." → "[Ag..."
    result = result.replaceAllMapped(
      RegExp(r'^(\[\s*)+'),
      (m) => '[',
    );

    // 2. Wrap multi-character superscripts without braces: ^12 → ^{12}, ^10 → ^{10}
    //    Only if not already wrapped in {}
    result = result.replaceAllMapped(
      RegExp(r'\^(-?\d{2,}|\w{2,})(?!\})'),
      (m) => '^{${m[1]}}',
    );

    // 3. Wrap multi-character subscripts without braces: _12 → _{12}
    result = result.replaceAllMapped(
      RegExp(r'_(-?\d{2,}|\w{2,})(?!\})'),
      (m) => '_{${m[1]}}',
    );

    // 4. Fix ^2 2s → ^2\,2s (preserve spacing, don't merge)
    //    Actually we just need to ensure single-digit ^n is valid as-is.

    // 5. Normalize multiple spaces
    result = result.replaceAll(RegExp(r'  +'), ' ').trim();

    return result;
  }

  Future<void> _handlePaste() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    if (data?.text != null) {
      final processed = _processWordPaste(data!.text!);
      _insertAtCursor(processed);
    }

  }

  void _saveAndExit() {
    Navigator.of(context).pop(_controller.text);
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
                        _insertAtCursor(symbol);
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
                      onPaste: _handlePaste,
                    ),
                  ),
                  // Rendered preview area
                  Container(
                    constraints: const BoxConstraints(minHeight: 55, maxHeight: 120),
                    width: double.infinity,
                    margin: const EdgeInsets.fromLTRB(12, 0, 12, 4),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.06),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                    ),
                    child: const Center(
                      child: Directionality(
                        textDirection: TextDirection.ltr,
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: RenderedExpression(),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
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

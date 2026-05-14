import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart' as quill;
import 'package:flutter_quill/quill_delta.dart' as quill_delta;
import 'package:vsc_quill_delta_to_html/vsc_quill_delta_to_html.dart';
import 'package:flutter_quill_delta_from_html/flutter_quill_delta_from_html.dart';
import 'package:flutter_math_fork/flutter_math.dart';
import '../theme/app_colors.dart';
import '../utils/math_utils.dart';
import '../utils/math_parser.dart';
import 'math/math_symbol_toolbar.dart';

class MathEmbedBuilder extends quill.EmbedBuilder {
  @override
  String get key => 'math';

  @override
  Widget build(BuildContext context, quill.EmbedContext embedContext) {
    final latex = embedContext.node.value.data as String;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black87;

    return Tooltip(
      message: 'معادلة: $latex (انقر للتعديل)',
      child: SelectionArea(
        child: InkWell(
          onTap: () async {
            final TextEditingController editController = TextEditingController(text: latex);
            final newLatex = await showDialog<String>(
              context: context,
              builder: (ctx) => AlertDialog(
                title: const Text('تعديل المعادلة'),
                content: Directionality(
                  textDirection: TextDirection.ltr,
                  child: TextField(
                    controller: editController,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      hintText: 'LaTeX...',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text('إلغاء'),
                  ),
                  ElevatedButton(
                    onPressed: () => Navigator.pop(ctx, editController.text.trim()),
                    child: const Text('حفظ'),
                  ),
                ],
              ),
            );

            if (newLatex != null && newLatex != latex) {
              final offset = embedContext.node.offset;
              embedContext.controller.replaceText(
                offset,
                1,
                quill.Embeddable('math', newLatex),
                null,
              );
            }
          },
          borderRadius: BorderRadius.circular(2),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2),
            child: Directionality(
              textDirection: TextDirection.ltr,
              child: Math.tex(
                latex,
                textStyle: TextStyle(
                  fontSize: 16,
                  color: textColor,
                ),
                onErrorFallback: (err) => Text(
                  latex,
                  style: TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 13,
                    color: textColor.withOpacity(0.7),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class RichTextEditor extends StatefulWidget {
  final String? initialHtml;
  final Function(String) onContentChanged;
  final String placeholder;
  final double height;
  final bool isCompact;
  final Color? textColor;

  const RichTextEditor({
    super.key,
    this.initialHtml,
    required this.onContentChanged,
    this.placeholder = 'اكتب هنا...',
    this.height = 200,
    this.isCompact = false,
    this.textColor,
  });

  @override
  State<RichTextEditor> createState() => _RichTextEditorState();
}

class _RichTextEditorState extends State<RichTextEditor> {
  late quill.QuillController _controller;
  final FocusNode _focusNode = FocusNode();
  final ScrollController _scrollController = ScrollController();
  bool _isFocused = false;

  quill.Style get _selectionStyle => _controller.getSelectionStyle();

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(_onFocusChanged);
    _initializeController();
  }

  @override
  void didUpdateWidget(covariant RichTextEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialHtml != oldWidget.initialHtml) {
      _controller.removeListener(_onContentChanged);
      _controller.dispose();
      _initializeController();
    }
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
    if (mounted) {
      setState(() {
        _isFocused = _focusNode.hasFocus;
      });
    }
  }

  void _initializeController() {
    try {
      if (widget.initialHtml != null && widget.initialHtml!.isNotEmpty) {
        String html = MathUtils.normalizeMathContent(widget.initialHtml!);
        
        html = html.replaceAllMapped(RegExp(r'style="([^"]*)"'), (match) {
          String style = match.group(1)!;
          style = style.toLowerCase()
              .replaceAll(RegExp(r':\s*'), ': ')
              .replaceAll(RegExp(r';\s*'), '; ');
          return 'style="$style"';
        });

        html = html.replaceAllMapped(
          RegExp(r'<(h[1-6]|p)([^>]*)style="([^"]*color:\s*(#[0-9a-f]{3,8}|rgb\([^\)]+\))[^"]*)"([^>]*)>(.*?)</\1>', 
          caseSensitive: false, dotAll: true),
          (match) {
            String tag = match.group(1)!;
            String attr1 = match.group(2)!;
            String style = match.group(3)!;
            String attr2 = match.group(4)!;
            String content = match.group(5)!;
            
            RegExp colorReg = RegExp(r'color:\s*(#[0-9a-f]{3,8}|rgb\([^\)]+\))', caseSensitive: false);
            String colorValue = colorReg.firstMatch(style)?.group(1) ?? '';
            
            if (colorValue.isNotEmpty) {
              return '<$tag$attr1 style="$style"$attr2><span style="color: $colorValue">$content</span></$tag>';
            }
            return match.group(0)!;
          }
        );

        var delta = HtmlToDelta().convert(html);
        delta = _processMathEmbeds(delta);

        _controller = quill.QuillController(
          document: quill.Document.fromDelta(delta),
          selection: const TextSelection.collapsed(offset: 0),
        );
      } else {
        _controller = quill.QuillController.basic();
      }
    } catch (e) {
      debugPrint('Error initializing editor with HTML: $e');
      final doc = quill.Document();
      if (widget.initialHtml != null) {
        doc.insert(0, widget.initialHtml!);
      }
      _controller = quill.QuillController(
        document: doc,
        selection: const TextSelection.collapsed(offset: 0),
      );
    }

    _controller.addListener(_onContentChanged);

    _controller.changes.listen((event) {
      if (event.source != quill.ChangeSource.local) return;
      
      final delta = event.change;
      for (final op in delta.toList()) {
        if (op.key == 'insert' && op.value is String) {
          final text = op.value as String;
          final trimmed = text.trim();
          
          if (trimmed.length > 2 && MathUtils.isMathLike(trimmed)) {
            Future.delayed(const Duration(milliseconds: 10), () {
              if (!mounted) return;
              _convertLinearMathInDoc();
            });
          }
        }
      }
    });
  }

  void _convertLinearMathInDoc() {
    final delta = _controller.document.toDelta();
    bool changed = false;
    final newDelta = quill_delta.Delta();

    for (final op in delta.toList()) {
      if (op.key == 'insert' && op.value is String) {
        final text = op.value as String;
        
        if (MathUtils.isMathLike(text) && !text.contains('\n')) {
          final trimmed = text.trim();
          final latex = MathParser.convertToLatex(trimmed);
          
          if (latex != trimmed && latex.isNotEmpty) {
            newDelta.insert(quill.Embeddable('math', latex), op.attributes);
            changed = true;
            continue;
          }
        }
      }
      newDelta.insert(op.value, op.attributes);
    }

    if (changed) {
      final selection = _controller.selection;
      _controller.document.replace(0, _controller.document.length, "");
      _controller.document.compose(newDelta, quill.ChangeSource.local);
      _controller.updateSelection(selection, quill.ChangeSource.local);
    }
  }

  quill_delta.Delta _processMathEmbeds(quill_delta.Delta delta) {
    final newDelta = quill_delta.Delta();
    for (final op in delta.toList()) {
      if (op.key == 'insert' && op.value is String) {
        final text = op.value as String;
        
        final latexMatches = MathUtils.latexRegex.allMatches(text);
        if (latexMatches.isNotEmpty) {
          int lastIndex = 0;
          for (final match in latexMatches) {
            if (match.start > lastIndex) {
              newDelta.insert(text.substring(lastIndex, match.start), op.attributes);
            }
            final rawMatch = match.group(0)!;
            final cleanLatex = _stripMathDelimiters(rawMatch);
            newDelta.insert(
              quill.Embeddable('math', cleanLatex),
              op.attributes,
            );
            lastIndex = match.end;
          }
          if (lastIndex < text.length) {
            newDelta.insert(text.substring(lastIndex), op.attributes);
          }
          continue;
        }

        final trimmed = text.trim();
        if (trimmed.length > 2 && MathUtils.isMathLike(trimmed) && !trimmed.contains('\n')) {
          final latex = MathParser.convertToLatex(trimmed);
          if (latex != trimmed) {
            newDelta.insert(
              quill.Embeddable('math', latex),
              op.attributes,
            );
            continue;
          }
        }

        newDelta.push(op);
      } else {
        newDelta.push(op);
      }
    }
    return newDelta;
  }

  String _stripMathDelimiters(String token) {
    if (token.startsWith(r'\[') && token.endsWith(r'\]')) {
      return token.substring(2, token.length - 2);
    }
    if (token.startsWith(r'\(') && token.endsWith(r'\)')) {
      return token.substring(2, token.length - 2);
    }
    if (token.startsWith('\$\$') && token.endsWith('\$\$')) {
      return token.substring(2, token.length - 2);
    }
    if (token.startsWith('\$') && token.endsWith('\$')) {
      return token.substring(1, token.length - 1);
    }
    return token;
  }

  void _onContentChanged() {
    final delta = _controller.document.toDelta();
    
    final List<Map<String, dynamic>> processedOps = [];
    
    for (final op in delta.toJson()) {
      final insert = op['insert'];
      if (insert is Map && insert.containsKey('math')) {
        final latex = insert['math'].toString();
        processedOps.add({
          'insert': 'MATH_LATEX_START$latex MATH_LATEX_END',
          'attributes': op['attributes'],
        });
      } else {
        processedOps.add(Map<String, dynamic>.from(op));
      }
    }

    final converter = QuillDeltaToHtmlConverter(
      processedOps,
      ConverterOptions(
        converterOptions: OpConverterOptions(
          inlineStylesFlag: true,
        ),
      ),
    );

    String html = converter.convert();
    html = html.replaceAll('MATH_LATEX_START', r'\(');
    html = html.replaceAll('MATH_LATEX_END', r'\)');
    
    widget.onContentChanged(html);
  }

  void _toggleInlineStyle(quill.Attribute attribute) {
    _focusNode.requestFocus();
    final isActive = _selectionStyle.attributes.containsKey(attribute.key);
    _controller.formatSelection(
      isActive ? quill.Attribute.clone(attribute, null) : attribute,
    );
  }

  void _applyColor(Color? color) {
    _focusNode.requestFocus();
    if (color == null) {
      _controller.formatSelection(quill.Attribute.clone(quill.Attribute.color, null));
    } else {
      _controller.formatSelection(
        quill.Attribute.fromKeyValue(
          quill.Attribute.color.key,
          _toHexColor(color),
        )!,
      );
    }
  }

  String _toHexColor(Color color) {
    final r = color.red.toRadixString(16).padLeft(2, '0');
    final g = color.green.toRadixString(16).padLeft(2, '0');
    final b = color.blue.toRadixString(16).padLeft(2, '0');
    return '#$r$g$b';
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
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
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
          // Custom Toolbar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
            decoration: BoxDecoration(
              color: toolbarBackground,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(11)),
              border: Border(
                bottom: BorderSide(color: AppColors.borderLight.withOpacity(0.5)),
              ),
            ),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildToolbarButton(
                    icon: Icons.format_bold,
                    isSelected: _selectionStyle.attributes.containsKey(quill.Attribute.bold.key),
                    onPressed: () => _toggleInlineStyle(quill.Attribute.bold),
                  ),
                  _buildToolbarButton(
                    icon: Icons.format_italic,
                    isSelected: _selectionStyle.attributes.containsKey(quill.Attribute.italic.key),
                    onPressed: () => _toggleInlineStyle(quill.Attribute.italic),
                  ),
                  _buildToolbarButton(
                    icon: Icons.format_underline,
                    isSelected: _selectionStyle.attributes.containsKey(quill.Attribute.underline.key),
                    onPressed: () => _toggleInlineStyle(quill.Attribute.underline),
                  ),
                  const VerticalDivider(width: 12),
                  _buildToolbarButton(
                    icon: Icons.format_list_bulleted,
                    isSelected: _selectionStyle.attributes[quill.Attribute.list.key]?.value == 'bullet',
                    onPressed: () {
                      final isActive = _selectionStyle.attributes[quill.Attribute.list.key]?.value == 'bullet';
                      _controller.formatSelection(isActive ? quill.Attribute.clone(quill.Attribute.ol, null) : quill.Attribute.ul);
                    },
                  ),
                  _buildToolbarButton(
                    icon: Icons.format_list_numbered,
                    isSelected: _selectionStyle.attributes[quill.Attribute.list.key]?.value == 'ordered',
                    onPressed: () {
                      final isActive = _selectionStyle.attributes[quill.Attribute.list.key]?.value == 'ordered';
                      _controller.formatSelection(isActive ? quill.Attribute.clone(quill.Attribute.ol, null) : quill.Attribute.ol);
                    },
                  ),
                  const VerticalDivider(width: 12),
                  _buildToolbarButton(
                    icon: Icons.format_align_right,
                    isSelected: _selectionStyle.attributes[quill.Attribute.align.key]?.value == 'right',
                    onPressed: () => _controller.formatSelection(quill.Attribute.rightAlignment),
                  ),
                  _buildToolbarButton(
                    icon: Icons.format_align_center,
                    isSelected: _selectionStyle.attributes[quill.Attribute.align.key]?.value == 'center',
                    onPressed: () => _controller.formatSelection(quill.Attribute.centerAlignment),
                  ),
                  _buildToolbarButton(
                    icon: Icons.format_align_left,
                    isSelected: _selectionStyle.attributes[quill.Attribute.align.key]?.value == 'left',
                    onPressed: () => _controller.formatSelection(quill.Attribute.leftAlignment),
                  ),
                ],
              ),
            ),
          ),
          
          // Math Toolbar (Always visible in this premium editor)
          MathSymbolToolbar(
            onSymbolSelected: (symbol) {
              final index = _controller.selection.baseOffset;
              final length = _controller.selection.extentOffset - index;
              
              if (symbol.startsWith('\\(') && symbol.endsWith('\\)')) {
                final latex = symbol.substring(2, symbol.length - 2);
                _controller.replaceText(index, length, quill.Embeddable('math', latex), null);
              } else {
                _controller.replaceText(index, length, symbol, null);
              }
            },
          ),

          // Editor Area
          SizedBox(
            height: widget.height,
            child: quill.QuillEditor.basic(
              controller: _controller,
              focusNode: _focusNode,
              scrollController: _scrollController,
              configurations: quill.QuillEditorConfigurations(
                placeholder: widget.placeholder,
                padding: const EdgeInsets.all(12),
                embedBuilders: [MathEmbedBuilder()],
                autoFocus: false,
                expands: false,
                scrollable: true,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

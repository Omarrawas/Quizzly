import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_math_fork/flutter_math.dart';
import '../../theme/app_colors.dart';

abstract class MathNode {
  String toLatex();
  bool get isEmpty;
}

class TextNode extends MathNode {
  String text;
  TextNode(this.text);

  @override
  String toLatex() => text;

  @override
  bool get isEmpty => text.trim().isEmpty;
}

class TemplateNode extends MathNode {
  final String type;
  final Map<String, List<MathNode>> slots;
  TemplateNode(this.type, this.slots);

  @override
  String toLatex() {
    switch (type) {
      case 'fraction':
        return '\\frac{${_slotsToLatex('num')}}{${_slotsToLatex('den')}}';
      case 'power':
        return '{${_slotsToLatex('base')}}^{${_slotsToLatex('exp')}}';
      case 'subscript':
        return '{${_slotsToLatex('base')}}_{${_slotsToLatex('sub')}}';
      case 'root':
        return '\\sqrt{${_slotsToLatex('content')}}';
      case 'nroot':
        return '\\sqrt[${_slotsToLatex('n')}]{${_slotsToLatex('content')}}';
      case 'integral':
        return '\\int_{${_slotsToLatex('lower')}}^{${_slotsToLatex('upper')}} ${_slotsToLatex('body')}';
      case 'sum':
        return '\\sum_{${_slotsToLatex('lower')}}^{${_slotsToLatex('upper')}} ${_slotsToLatex('body')}';
      case 'bracket':
        return '\\left( ${_slotsToLatex('content')} \\right)';
      case 'square_bracket':
        return '\\left[ ${_slotsToLatex('content')} \\right]';
      case 'curly_bracket':
        return '\\left\\{ ${_slotsToLatex('content')} \\right\\}';
      case 'matrix':
        return '\\begin{bmatrix} ${_slotsToLatex('0,0')} & ${_slotsToLatex('0,1')} \\\\ ${_slotsToLatex('1,0')} & ${_slotsToLatex('1,1')} \\end{bmatrix}';
      default:
        return '';
    }
  }

  String _slotsToLatex(String slotKey) {
    return slots[slotKey]?.map((n) => n.toLatex()).join('') ?? '';
  }

  @override
  bool get isEmpty => slots.values.every((list) => list.every((n) => n.isEmpty));
}

class VisualMathEditor extends StatefulWidget {
  final String? initialLatex;
  final Function(String) onSave;

  const VisualMathEditor({
    super.key,
    this.initialLatex,
    required this.onSave,
  });

  static List<MathNode> parseLatex(String latex) {
    if (latex.isEmpty) {
      return [TextNode('')];
    }
    
    List<MathNode> nodes = [];
    int i = 0;
    
    while (i < latex.length) {
      if (latex.startsWith(r'\frac', i)) {
        i += 5;
        final numSlot = _extractBracedContent(latex, i);
        i += numSlot.length + 2;
        final denSlot = _extractBracedContent(latex, i);
        i += denSlot.length + 2;
        nodes.add(TemplateNode('fraction', {
          'num': parseLatex(numSlot),
          'den': parseLatex(denSlot),
        }));
      } else if (latex.startsWith(r'\sqrt', i)) {
        i += 5;
        if (i < latex.length && latex[i] == '[') {
          final nSlot = _extractBracketedContent(latex, i);
          i += nSlot.length + 2;
          final contentSlot = _extractBracedContent(latex, i);
          i += contentSlot.length + 2;
          nodes.add(TemplateNode('nroot', {
            'n': parseLatex(nSlot),
            'content': parseLatex(contentSlot),
          }));
        } else {
          final contentSlot = _extractBracedContent(latex, i);
          i += contentSlot.length + 2;
          nodes.add(TemplateNode('root', {
            'content': parseLatex(contentSlot),
          }));
        }
      } else if (latex.startsWith(r'\int', i)) {
        i += 4;
        String lower = '', upper = '';
        if (i < latex.length && latex[i] == '_') {
          i++;
          lower = _extractBracedContent(latex, i);
          i += lower.length + 2;
        }
        if (i < latex.length && latex[i] == '^') {
          i++;
          upper = _extractBracedContent(latex, i);
          i += upper.length + 2;
        }
        nodes.add(TemplateNode('integral', {
          'lower': parseLatex(lower),
          'upper': parseLatex(upper),
          'body': [TextNode('')],
        }));
      } else if (latex.startsWith(r'\sum', i)) {
        i += 4;
        String lower = '', upper = '';
        if (i < latex.length && latex[i] == '_') {
          i++;
          lower = _extractBracedContent(latex, i);
          i += lower.length + 2;
        }
        if (i < latex.length && latex[i] == '^') {
          i++;
          upper = _extractBracedContent(latex, i);
          i += upper.length + 2;
        }
        nodes.add(TemplateNode('sum', {
          'lower': parseLatex(lower),
          'upper': parseLatex(upper),
          'body': [TextNode('')],
        }));
      } else if (latex[i] == '^' && nodes.isNotEmpty) {
        i++;
        final expSlot = _extractBracedContent(latex, i);
        i += expSlot.length + 2;
        final last = nodes.removeLast();
        nodes.add(TemplateNode('power', {
          'base': [last],
          'exp': parseLatex(expSlot),
        }));
      } else if (latex[i] == '_' && nodes.isNotEmpty) {
        i++;
        final subSlot = _extractBracedContent(latex, i);
        i += subSlot.length + 2;
        final last = nodes.removeLast();
        nodes.add(TemplateNode('subscript', {
          'base': [last],
          'sub': parseLatex(subSlot),
        }));
      } else if (latex.startsWith(r'\left(', i)) {
        i += 6;
        final content = _extractLeftRightContent(latex, i, r'\right)');
        i += content.length + 7;
        nodes.add(TemplateNode('bracket', {'content': parseLatex(content)}));
      } else if (latex.startsWith(r'\left[', i)) {
        i += 6;
        final content = _extractLeftRightContent(latex, i, r'\right]');
        i += content.length + 7;
        nodes.add(TemplateNode('square_bracket', {'content': parseLatex(content)}));
      } else if (latex.startsWith(r'\left\{', i)) {
        i += 7;
        final content = _extractLeftRightContent(latex, i, r'\right\}');
        i += content.length + 8;
        nodes.add(TemplateNode('curly_bracket', {'content': parseLatex(content)}));
      } else {
        String currentText = '';
        while (i < latex.length && 
               !latex.startsWith(r'\frac', i) && 
               !latex.startsWith(r'\sqrt', i) &&
               !latex.startsWith(r'\int', i) &&
               !latex.startsWith(r'\sum', i) &&
               !latex.startsWith(r'\left(', i) &&
               !latex.startsWith(r'\left[', i) &&
               !latex.startsWith(r'\left\{', i) &&
               latex[i] != '^' && latex[i] != '_') {
          currentText += latex[i];
          i++;
        }
        if (currentText.isNotEmpty) {
          nodes.add(TextNode(currentText));
        }
      }
    }
    
    if (nodes.isEmpty) {
      nodes.add(TextNode(''));
    }
    return nodes;
  }

  static String _extractLeftRightContent(String s, int start, String closeTag) {
    int j = start;
    int depth = 1;
    while (j < s.length && depth > 0) {
      if (s.startsWith(r'\left', j)) {
        depth++;
      } else if (s.startsWith(r'\right', j)) {
        depth--;
      }
      if (depth > 0) {
        j++;
      }
    }
    return s.substring(start, j);
  }

  static String _extractBracedContent(String s, int start) {
    if (start >= s.length || s[start] != '{') {
      return "";
    }
    int depth = 1;
    int j = start + 1;
    while (j < s.length && depth > 0) {
      if (s[j] == '{') {
        depth++;
      } else if (s[j] == '}') {
        depth--;
      }
      if (depth > 0) {
        j++;
      }
    }
    return s.substring(start + 1, j);
  }

  static String _extractBracketedContent(String s, int start) {
    if (start >= s.length || s[start] != '[') {
      return "";
    }
    int depth = 1;
    int j = start + 1;
    while (j < s.length && depth > 0) {
      if (s[j] == '[') {
        depth++;
      } else if (s[j] == ']') {
        depth--;
      }
      if (depth > 0) {
        j++;
      }
    }
    return s.substring(start + 1, j);
  }

  @override
  State<VisualMathEditor> createState() => _VisualMathEditorState();
}

class _VisualMathEditorState extends State<VisualMathEditor> {
  late List<MathNode> rootNodes;
  
  // Focus tracking for Word-like experience
  List<MathNode>? _focusedSlot;
  int? _focusedIndex;
  TextEditingController? _focusedController;
  final FocusNode _editorFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _initializeNodes();
    _focusedSlot = rootNodes;
    _focusedIndex = rootNodes.length - 1;
  }

  void _initializeNodes() {
    if (widget.initialLatex != null && widget.initialLatex!.isNotEmpty) {
      rootNodes = VisualMathEditor.parseLatex(widget.initialLatex!);
    } else {
      rootNodes = [TextNode('')];
    }
  }

  void _updateFocus(List<MathNode> slot, int index, TextEditingController controller) {
    setState(() {
      _focusedSlot = slot;
      _focusedIndex = index;
      _focusedController = controller;
    });
  }

  void _addTemplate(String type) {
    Map<String, List<MathNode>> slots = {};
    if (type == 'fraction') slots = {'num': [TextNode('')], 'den': [TextNode('')]};
    if (type == 'power') slots = {'base': [TextNode('')], 'exp': [TextNode('')]};
    if (type == 'subscript') slots = {'base': [TextNode('')], 'sub': [TextNode('')]};
    if (type == 'root') slots = {'content': [TextNode('')]};
    if (type == 'nroot') slots = {'n': [TextNode('')], 'content': [TextNode('')]};
    if (type == 'integral' || type == 'sum') {
      slots = {'lower': [TextNode('')], 'upper': [TextNode('')], 'body': [TextNode('')]};
    }
    if (type == 'bracket' || type == 'square_bracket' || type == 'curly_bracket') {
      slots = {'content': [TextNode('')]};
    }
    if (type == 'matrix') {
      slots = {
        '0,0': [TextNode('')], '0,1': [TextNode('')],
        '1,0': [TextNode('')], '1,1': [TextNode('')]
      };
    }
    if (slots.isEmpty) {
       // Handle generic text templates if any
       _addSymbol('\\$type ');
       return;
    }
    
    setState(() {
      if (_focusedSlot != null && _focusedIndex != null) {
        final node = _focusedSlot![_focusedIndex!];
        if (node is TextNode) {
          final cursor = _focusedController?.selection.baseOffset ?? node.text.length;
          final textBefore = node.text.substring(0, cursor >= 0 ? cursor : 0);
          final textAfter = node.text.substring(cursor >= 0 ? cursor : 0);
          
          node.text = textBefore;
          _focusedSlot!.insert(_focusedIndex! + 1, TemplateNode(type, slots));
          _focusedSlot!.insert(_focusedIndex! + 2, TextNode(textAfter));
          
          // Set focus to new template
          _focusedSlot = slots.values.first;
          _focusedIndex = 0;
        } else {
          _focusedSlot!.insert(_focusedIndex! + 1, TemplateNode(type, slots));
          _focusedSlot!.insert(_focusedIndex! + 2, TextNode(''));
          _focusedIndex = _focusedIndex! + 1;
        }
      } else {
        rootNodes.add(TemplateNode(type, slots));
        rootNodes.add(TextNode(''));
      }
    });
  }

  void _addSymbol(String symbol) {
    if (_focusedSlot != null && _focusedIndex != null) {
      final node = _focusedSlot![_focusedIndex!];
      if (node is TextNode) {
        final cursor = _focusedController?.selection.baseOffset ?? node.text.length;
        final textBefore = node.text.substring(0, cursor >= 0 ? cursor : 0);
        final textAfter = node.text.substring(cursor >= 0 ? cursor : 0);
        
        setState(() {
          node.text = textBefore + symbol + textAfter;
          _focusedController?.text = node.text;
          _focusedController?.selection = TextSelection.collapsed(offset: cursor + symbol.length);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF1E293B) : Colors.white;
    final textColor = isDark ? Colors.white : AppColors.textPrimary;
    final borderColor = isDark ? Colors.white12 : AppColors.borderLight;
    final accentColor = AppColors.primaryBlue;

    final double editorWidth = size.width > 950 ? 950 : size.width * 0.95;
    final double editorHeight = size.height > 650 ? 650 : size.height * 0.85;

    return Center(
      child: Container(
        width: editorWidth,
        height: editorHeight,
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.3),
              blurRadius: 30,
              spreadRadius: 5,
            ),
          ],
        ),
        child: Column(
          children: [
            // Header
            _buildHeader(ctx: context, textColor: textColor, borderColor: borderColor, accentColor: accentColor, isDark: isDark, width: editorWidth),

            // Top Ribbon (Word Style)
            _buildWordRibbon(isDark: isDark, borderColor: borderColor, textColor: textColor, width: editorWidth),

            // Main Canvas
            Expanded(
              child: GestureDetector(
                onTap: () => FocusScope.of(context).requestFocus(_editorFocusNode),
                child: Container(
                  width: editorWidth,
                  padding: const EdgeInsets.symmetric(vertical: 30, horizontal: 30),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.black.withValues(alpha: 0.2) : const Color(0xFFF8FAFC),
                  ),
                  child: Center(
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      physics: const BouncingScrollPhysics(),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: rootNodes.map((node) => _buildNodeWidget(node, isDark, textColor, rootNodes)).toList(),
                      ),
                    ),
                  ),
                ),
              ),
            ),

            // Footer
            _buildFooter(isDark: isDark, textColor: textColor, accentColor: accentColor, width: editorWidth),
          ],
        ),
      ),
    );
  }

  Widget _buildWordRibbon({required bool isDark, required Color borderColor, required Color textColor, required double width}) {
    return Container(
      width: width,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
        border: Border(bottom: BorderSide(color: borderColor)),
      ),
      child: Column(
        children: [
          // Symbols Quick Bar
          Container(
            height: 42,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(border: Border(bottom: BorderSide(color: borderColor.withValues(alpha: 0.5)))),
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                '±', '∞', '≠', '≈', '×', '÷', 'π', 'α', 'β', 'θ', 'λ', '∑', '∫', '√', '→', '⇒', '⇔', '∀', '∃', '∈', '∉', '⊂', '⊃', '⊆', '⊇', '∠', '△'
              ].map((s) => _buildQuickSymbol(s)).toList(),
            ),
          ),
          // Categories Ribbon
          SizedBox(
            height: 80,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              children: [
                _buildCategoryMenu('كسور', Icons.view_headline, [
                  _TemplateItem(r'\frac{\Box}{\Box}', 'fraction', 'كسر عادي'),
                  _TemplateItem(r'\tfrac{\Box}{\Box}', 'fraction', 'كسر صغير'),
                  _TemplateItem(r'\dfrac{\Box}{\Box}', 'fraction', 'كسر كبير'),
                ], isDark, textColor),
                _buildCategoryMenu('أُسس', Icons.superscript, [
                  _TemplateItem(r'\Box^{\Box}', 'power', 'أُس علوي'),
                  _TemplateItem(r'\Box_{\Box}', 'subscript', 'حد سفلي'),
                ], isDark, textColor),
                _buildCategoryMenu('جذور', Icons.square_foot, [
                  _TemplateItem(r'\sqrt{\Box}', 'root', 'جذر تربيعي'),
                  _TemplateItem(r'\sqrt[n]{\Box}', 'nroot', 'جذر نوني'),
                ], isDark, textColor),
                _buildCategoryMenu('تكامل', Icons.show_chart, [
                  _TemplateItem(r'\int', 'integral', 'تكامل'),
                  _TemplateItem(r'\int_{\Box}^{\Box}', 'integral', 'تكامل محدود'),
                  _TemplateItem(r'\iint', 'integral', 'تكامل ثنائي'),
                ], isDark, textColor),
                _buildCategoryMenu('مجموع', Icons.functions, [
                   _TemplateItem(r'\sum', 'sum', 'مجموع'),
                  _TemplateItem(r'\sum_{\Box}^{\Box}', 'sum', 'مجموع محدود'),
                  _TemplateItem(r'\prod', 'sum', 'جداء'),
                ], isDark, textColor),
                _buildCategoryMenu('أقواس', Icons.data_array, [
                  _TemplateItem(r'(\Box)', 'bracket', 'أقواس دائرية'),
                  _TemplateItem(r'[\Box]', 'square_bracket', 'أقواس مربعة'),
                  _TemplateItem(r'\{\Box\}', 'curly_bracket', 'أقواس مجموعة'),
                ], isDark, textColor),
                _buildCategoryMenu('مصفوفة', Icons.grid_on, [
                  _TemplateItem(r'\begin{matrix} \Box & \Box \\ \Box & \Box \end{matrix}', 'matrix', '2x2'),
                ], isDark, textColor),
                _buildCategoryMenu('دوال', Icons.auto_graph, [
                  _TemplateItem(r'\sin', 'sin', 'sin'),
                  _TemplateItem(r'\cos', 'cos', 'cos'),
                  _TemplateItem(r'\tan', 'tan', 'tan'),
                  _TemplateItem(r'\lim_{x \to 0}', 'lim', 'limit'),
                ], isDark, textColor),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickSymbol(String symbol) {
    return InkWell(
      onTap: () => _addSymbol(symbol),
      child: Container(
        width: 38,
        alignment: Alignment.center,
        child: Text(symbol, style: const TextStyle(fontSize: 18)),
      ),
    );
  }

  Widget _buildCategoryMenu(String label, IconData icon, List<_TemplateItem> items, bool isDark, Color textColor) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: PopupMenuButton<_TemplateItem>(
        onSelected: (item) => _addTemplate(item.type),
        offset: const Offset(0, 75),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        itemBuilder: (context) => items.map((item) {
          return PopupMenuItem<_TemplateItem>(
            value: item,
            child: Row(
              children: [
                Container(
                  width: 35,
                  height: 35,
                  alignment: Alignment.center,
                  child: SafeMathPreview(latex: item.preview, textColor: textColor, mathSize: 13),
                ),
                const SizedBox(width: 12),
                Text(item.label, style: const TextStyle(fontSize: 13)),
              ],
            ),
          );
        }).toList(),
        child: Container(
          width: 85,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.white,
            border: Border.all(color: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.05)),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 22, color: AppColors.primaryBlue),
              const SizedBox(height: 4),
              Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: textColor.withValues(alpha: 0.7))),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNodeWidget(MathNode node, bool isDark, Color textColor, List<MathNode> parentSlot) {
    if (node is TextNode) {
      return _MathTextField(
        node: node,
        isDark: isDark,
        textColor: textColor,
        onFocused: (controller) => _updateFocus(parentSlot, parentSlot.indexOf(node), controller),
        isRoot: parentSlot == rootNodes,
      );
    } else if (node is TemplateNode) {
      Widget content;
      switch (node.type) {
        case 'fraction':
          content = Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildSlot(node.slots['num']!, isDark, textColor),
              Container(width: 40, height: 1.5, color: textColor, margin: const EdgeInsets.symmetric(vertical: 4)),
              _buildSlot(node.slots['den']!, isDark, textColor),
            ],
          );
          break;
        case 'power':
          content = Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              _buildSlot(node.slots['base']!, isDark, textColor),
              Padding(
                padding: const EdgeInsets.only(bottom: 20),
                child: _buildSlot(node.slots['exp']!, isDark, textColor, small: true),
              ),
            ],
          );
          break;
        case 'subscript':
          content = Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSlot(node.slots['base']!, isDark, textColor),
              Padding(
                padding: const EdgeInsets.only(top: 20),
                child: _buildSlot(node.slots['sub']!, isDark, textColor, small: true),
              ),
            ],
          );
          break;
        case 'root':
          content = Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('√', style: TextStyle(fontSize: 40, color: textColor, fontFamily: 'serif')),
              Container(
                decoration: BoxDecoration(border: Border(top: BorderSide(color: textColor, width: 1.5))),
                child: _buildSlot(node.slots['content']!, isDark, textColor),
              ),
            ],
          );
          break;
        case 'nroot':
          content = Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 4, right: -10),
                child: _buildSlot(node.slots['n']!, isDark, textColor, small: true),
              ),
              Text('√', style: TextStyle(fontSize: 40, color: textColor, fontFamily: 'serif')),
              Container(
                decoration: BoxDecoration(border: Border(top: BorderSide(color: textColor, width: 1.5))),
                child: _buildSlot(node.slots['content']!, isDark, textColor),
              ),
            ],
          );
          break;
        case 'integral':
        case 'sum':
          final symbol = node.type == 'integral' ? '∫' : '∑';
          content = Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildSlot(node.slots['upper']!, isDark, textColor, small: true),
                  Text(symbol, style: TextStyle(fontSize: 36, color: textColor, fontFamily: 'serif')),
                  _buildSlot(node.slots['lower']!, isDark, textColor, small: true),
                ],
              ),
              const SizedBox(width: 4),
              _buildSlot(node.slots['body']!, isDark, textColor),
            ],
          );
          break;
        case 'bracket':
        case 'square_bracket':
        case 'curly_bracket':
          String open = '(', close = ')';
          if (node.type == 'square_bracket') { open = '['; close = ']'; }
          if (node.type == 'curly_bracket') { open = '{'; close = '}'; }
          content = Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(open, style: TextStyle(fontSize: 40, color: textColor, fontWeight: FontWeight.w100)),
              _buildSlot(node.slots['content']!, isDark, textColor),
              Text(close, style: TextStyle(fontSize: 40, color: textColor, fontWeight: FontWeight.w100)),
            ],
          );
          break;
        case 'matrix':
          content = Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('[', style: TextStyle(fontSize: 50, color: textColor, fontWeight: FontWeight.w100)),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(mainAxisSize: MainAxisSize.min, children: [
                    _buildSlot(node.slots['0,0']!, isDark, textColor),
                    const SizedBox(width: 8),
                    _buildSlot(node.slots['0,1']!, isDark, textColor),
                  ]),
                  const SizedBox(height: 8),
                  Row(mainAxisSize: MainAxisSize.min, children: [
                    _buildSlot(node.slots['1,0']!, isDark, textColor),
                    const SizedBox(width: 8),
                    _buildSlot(node.slots['1,1']!, isDark, textColor),
                  ]),
                ],
              ),
              Text(']', style: TextStyle(fontSize: 50, color: textColor, fontWeight: FontWeight.w100)),
            ],
          );
          break;
        default: content = const SizedBox.shrink();
      }
      return content;
    }
    return const SizedBox.shrink();
  }

  Widget _buildSlot(List<MathNode> nodes, bool isDark, Color textColor, {bool small = false}) {
    final isFocused = _focusedSlot == nodes;
    
    return Container(
      padding: const EdgeInsets.all(4),
      constraints: BoxConstraints(minWidth: small ? 25 : 35, minHeight: small ? 25 : 35),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withValues(alpha: 0.04) : Colors.black.withValues(alpha: 0.02),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(
          color: isFocused ? AppColors.primaryBlue : (isDark ? Colors.white10 : Colors.black12),
          width: isFocused ? 1.5 : 1,
          style: nodes.every((n) => n.isEmpty) ? BorderStyle.solid : BorderStyle.none,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: nodes.isEmpty 
          ? [const SizedBox(width: 10)] 
          : nodes.map((n) => _buildNodeWidget(n, isDark, textColor, nodes)).toList(),
      ),
    );
  }

  Widget _buildHeader({required BuildContext ctx, required Color textColor, required Color borderColor, required Color accentColor, required bool isDark, required double width}) {
    return Container(
      width: width,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
        border: Border(bottom: BorderSide(color: borderColor)),
      ),
      child: Row(
        children: [
          Icon(Icons.functions, color: accentColor, size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'محرر معادلات وورد (Visual Equation Editor)',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: textColor),
            ),
          ),
          ElevatedButton.icon(
            onPressed: () {
              final latex = rootNodes.map((n) => n.toLatex()).join('');
              widget.onSave(latex);
            },
            icon: const Icon(Icons.check, size: 18),
            label: const Text('إدراج'),
            style: ElevatedButton.styleFrom(
              backgroundColor: accentColor,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            ),
          ),
          const SizedBox(width: 12),
          IconButton(
            icon: const Icon(Icons.close, size: 20),
            onPressed: () => Navigator.pop(ctx),
          ),
        ],
      ),
    );
  }

  Widget _buildFooter({required bool isDark, required Color textColor, required Color accentColor, required double width}) {
    return Container(
      width: width,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      color: isDark ? const Color(0xFF0F172A) : Colors.white,
      child: Row(
        children: [
          Icon(Icons.info_outline, size: 16, color: accentColor),
          const SizedBox(width: 8),
          Text(
            'اضغط في المربعات المنقطة للكتابة. استخدم الأيقونات لإدراج قوالب.',
            style: TextStyle(fontSize: 12, color: textColor.withValues(alpha: 0.6)),
          ),
          const Spacer(),
          Text(
            'Latex Result: ${rootNodes.map((n) => n.toLatex()).join('')}',
            style: TextStyle(fontSize: 11, color: textColor.withValues(alpha: 0.3)),
          ),
        ],
      ),
    );
  }
}

class _TemplateItem {
  final String preview;
  final String type;
  final String label;
  _TemplateItem(this.preview, this.type, this.label);
}

class _MathTextField extends StatefulWidget {
  final TextNode node;
  final bool isDark;
  final Color textColor;
  final Function(TextEditingController) onFocused;
  final bool isRoot;

  const _MathTextField({
    required this.node,
    required this.isDark,
    required this.textColor,
    required this.onFocused,
    this.isRoot = false,
  });

  @override
  State<_MathTextField> createState() => _MathTextFieldState();
}

class _MathTextFieldState extends State<_MathTextField> {
  late TextEditingController _controller;
  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.node.text);
    _focusNode.addListener(() {
      if (_focusNode.hasFocus) {
        widget.onFocused(_controller);
      }
    });
  }

  @override
  void didUpdateWidget(_MathTextField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.node.text != _controller.text) {
      _controller.text = widget.node.text;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IntrinsicWidth(
      child: TextFormField(
        controller: _controller,
        focusNode: _focusNode,
        onChanged: (val) => widget.node.text = val,
        style: TextStyle(
          fontSize: widget.isRoot ? 32 : 22, 
          color: widget.textColor, 
          fontFamily: 'serif',
          fontWeight: FontWeight.w400,
        ),
        cursorColor: AppColors.primaryBlue,
        decoration: InputDecoration(
          border: InputBorder.none,
          isDense: true,
          hintText: widget.isRoot && widget.node.text.isEmpty ? '...' : '',
          hintStyle: TextStyle(color: widget.textColor.withValues(alpha: 0.1)),
          contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
        ),
      ),
    );
  }
}

class VisualMathField extends StatefulWidget {
  final List<MathNode> nodes;
  final Function(String) onChanged;
  final bool isDark;
  final Color textColor;
  final Stream<String>? mathAdditionStream;

  const VisualMathField({
    super.key,
    required this.nodes,
    required this.onChanged,
    required this.isDark,
    required this.textColor,
    this.mathAdditionStream,
  });

  @override
  State<VisualMathField> createState() => _VisualMathFieldState();
}

class _VisualMathFieldState extends State<VisualMathField> {
  StreamSubscription? _subscription;

  @override
  void initState() {
    super.initState();
    _subscription = widget.mathAdditionStream?.listen((latex) {
      if (mounted) {
        setState(() {
          widget.nodes.addAll(VisualMathEditor.parseLatex(latex));
          widget.onChanged(widget.nodes.map((n) => n.toLatex()).join(''));
        });
      }
    });
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    bool isEmpty = widget.nodes.every((n) {
      if (n is TextNode) return n.text.trim().isEmpty;
      return false;
    });

    return Directionality(
      textDirection: TextDirection.ltr,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: widget.isDark ? const Color(0xFF1E293B) : const Color(0xFFF0F7FF),
          border: Border.all(
            color: const Color(0xFF3B82F6).withValues(alpha: 0.5), 
            width: 1.5,
          ),
          borderRadius: BorderRadius.circular(10),
        ),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: widget.nodes.map((node) => _InlineNodeBuilder(
              node: node,
              isDark: widget.isDark,
              textColor: widget.textColor,
              placeholder: isEmpty ? 'اكتب هنا' : null,
              onChanged: () {
                widget.onChanged(widget.nodes.map((n) => n.toLatex()).join(''));
              },
            )).toList(),
          ),
        ),
      ),
    );
  }
}

class _InlineNodeBuilder extends StatelessWidget {
  final MathNode node;
  final bool isDark;
  final Color textColor;
  final VoidCallback onChanged;
  final String? placeholder;

  const _InlineNodeBuilder({
    required this.node,
    required this.isDark,
    required this.textColor,
    required this.onChanged,
    this.placeholder,
  });

  @override
  Widget build(BuildContext context) {
    if (node is TextNode) {
      final tNode = node as TextNode;
      return IntrinsicWidth(
        child: TextFormField(
          initialValue: tNode.text,
          onChanged: (val) {
            tNode.text = val;
            onChanged();
          },
          style: TextStyle(fontSize: 22, color: textColor, fontFamily: 'serif'),
          cursorColor: AppColors.primaryBlue,
          decoration: InputDecoration(
            border: InputBorder.none,
            isDense: true,
            hintText: placeholder,
            hintStyle: TextStyle(color: textColor.withValues(alpha: 0.2)),
            contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
          ),
        ),
      );
    } else if (node is TemplateNode) {
      return _buildTemplateWidget(node as TemplateNode, isDark, textColor, onChanged);
    }
    return const SizedBox.shrink();
  }

  Widget _buildTemplateWidget(TemplateNode node, bool isDark, Color textColor, VoidCallback onChanged) {
    switch (node.type) {
      case 'fraction':
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildInlineSlot(node.slots['num']!, isDark, textColor, onChanged),
            Container(width: 25, height: 1.5, color: textColor, margin: const EdgeInsets.symmetric(vertical: 2)),
            _buildInlineSlot(node.slots['den']!, isDark, textColor, onChanged),
          ],
        );
      case 'power':
        return Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            _buildInlineSlot(node.slots['base']!, isDark, textColor, onChanged),
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _buildInlineSlot(node.slots['exp']!, isDark, textColor, onChanged, small: true),
            ),
          ],
        );
      default:
        return Text(node.toLatex(), style: TextStyle(color: textColor));
    }
  }

  Widget _buildInlineSlot(List<MathNode> nodes, bool isDark, Color textColor, VoidCallback onChanged, {bool small = false}) {
    return Container(
      padding: const EdgeInsets.all(2),
      constraints: BoxConstraints(minWidth: small ? 15 : 24),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.02),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: AppColors.primaryBlue.withValues(alpha: 0.1)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: nodes.map((n) => _InlineNodeBuilder(node: n, isDark: isDark, textColor: textColor, onChanged: onChanged)).toList(),
      ),
    );
  }
}

class SafeMathPreview extends StatelessWidget {
  final String latex;
  final Color textColor;
  final double mathSize;

  const SafeMathPreview({
    super.key,
    required this.latex,
    required this.textColor,
    this.mathSize = 16,
  });

  @override
  Widget build(BuildContext context) {
    if (latex.trim().isEmpty) return const SizedBox.shrink();
    return Directionality(
      textDirection: TextDirection.ltr,
      child: Math.tex(
        latex,
        textStyle: TextStyle(fontSize: mathSize, color: textColor),
        onErrorFallback: (err) => Text(latex, style: TextStyle(color: textColor, fontSize: mathSize * 0.8)),
      ),
    );
  }
}

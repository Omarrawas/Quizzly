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

  @override
  void initState() {
    super.initState();
    _initializeNodes();
  }

  void _initializeNodes() {
    if (widget.initialLatex != null && widget.initialLatex!.isNotEmpty) {
      rootNodes = VisualMathEditor.parseLatex(widget.initialLatex!);
    } else {
      rootNodes = [TextNode('')];
    }
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
        '0,0': [TextNode('')],
        '0,1': [TextNode('')],
        '1,0': [TextNode('')],
        '1,1': [TextNode('')]
      };
    }
    
    setState(() {
      rootNodes.add(TemplateNode(type, slots));
      rootNodes.add(TextNode(''));
    });
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF1E293B) : Colors.white;
    final textColor = isDark ? Colors.white : AppColors.textPrimary;
    final borderColor = isDark ? Colors.white12 : AppColors.borderLight;
    final accentColor = AppColors.primaryBlue;

    // Use a safe width that works on all screens
    final double editorWidth = size.width > 950 ? 950 : size.width * 0.95;
    final double editorHeight = size.height > 600 ? 600 : size.height * 0.8;

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
            // 1. Header (Top Bar)
            _buildHeader(ctx: context, textColor: textColor, borderColor: borderColor, accentColor: accentColor, isDark: isDark, width: editorWidth),

            // 2. Main Writing Area (Canvas) - NOW EXPANDED
            Expanded(
              child: Container(
                width: editorWidth,
                padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 32),
                decoration: BoxDecoration(
                  color: isDark ? Colors.black.withValues(alpha: 0.2) : Colors.grey[50],
                  image: isDark ? null : DecorationImage(
                    image: const NetworkImage('https://www.transparenttextures.com/patterns/cubes.png'), // Subtle pattern
                    opacity: 0.05,
                    repeat: ImageRepeat.repeat,
                  ),
                ),
                child: Center(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    physics: const BouncingScrollPhysics(),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: rootNodes.isEmpty 
                        ? [Text(isDark ? 'بداية المعادلة...' : 'اكتب المعادلة هنا...', style: TextStyle(color: textColor.withValues(alpha: 0.3), fontSize: 24, fontStyle: FontStyle.italic))]
                        : rootNodes.map((node) => _buildNodeWidget(node, isDark, textColor)).toList(),
                    ),
                  ),
                ),
              ),
            ),

            // 3. Ribbon (Tools) - Moved to BOTTOM just like the screenshot
            _buildRibbon(isDark: isDark, borderColor: borderColor, textColor: textColor, width: editorWidth),

            // Footer
            _buildFooter(isDark: isDark, textColor: textColor, accentColor: accentColor, width: editorWidth),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader({required BuildContext ctx, required Color textColor, required Color borderColor, required Color accentColor, required bool isDark, required double width}) {
    return Container(
      width: width,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: isDark ? Colors.black.withValues(alpha: 0.3) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
        border: Border(bottom: BorderSide(color: borderColor)),
      ),
      child: Row(
        children: [
          Icon(Icons.functions, color: accentColor, size: 22),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'محرر المعادلات المرئي',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: textColor),
            ),
          ),
          ElevatedButton.icon(
            onPressed: () {
              final latex = rootNodes.map((n) => n.toLatex()).join('');
              widget.onSave(latex);
            },
            icon: const Icon(Icons.check, size: 18),
            label: const Text('حفظ المعادلة'),
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
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            visualDensity: VisualDensity.compact,
          ),
        ],
      ),
    );
  }

  Widget _buildRibbon({required bool isDark, required Color borderColor, required Color textColor, required double width}) {
    return Container(
      width: width,
      height: 80,
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withValues(alpha: 0.02) : Colors.grey.withValues(alpha: 0.05),
        border: Border(bottom: BorderSide(color: borderColor)),
      ),
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        children: [
          _buildRibbonItem(r'\frac{\Box}{\Box}', 'كسر', () => _addTemplate('fraction'), isDark, textColor),
          _buildRibbonItem(r'\Box^{\Box}', 'أس', () => _addTemplate('power'), isDark, textColor),
          _buildRibbonItem(r'\Box_{\Box}', 'سفلي', () => _addTemplate('subscript'), isDark, textColor),
          _buildRibbonItem(r'\sqrt{\Box}', 'جذر', () => _addTemplate('root'), isDark, textColor),
          _buildRibbonItem(r'\sqrt[n]{\Box}', 'جذر نوني', () => _addTemplate('nroot'), isDark, textColor),
          _buildRibbonItem(r'\int_{\Box}^{\Box}', 'تكامل', () => _addTemplate('integral'), isDark, textColor),
          _buildRibbonItem(r'\sum_{\Box}^{\Box}', 'مجموع', () => _addTemplate('sum'), isDark, textColor),
          _buildRibbonItem(r'(\Box)', 'أقواس', () => _addTemplate('bracket'), isDark, textColor),
          _buildRibbonItem(r'[\Box]', 'مربعة', () => _addTemplate('square_bracket'), isDark, textColor),
          _buildRibbonItem(r'\{\Box\}', 'مجموعة', () => _addTemplate('curly_bracket'), isDark, textColor),
          _buildRibbonItem(r'\begin{matrix} \Box & \Box \\ \Box & \Box \end{matrix}', 'مصفوفة', () => _addTemplate('matrix'), isDark, textColor),
        ],
      ),
    );
  }

  Widget _buildRibbonItem(String latex, String label, VoidCallback onTap, bool isDark, Color textColor) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          width: 75,
          padding: const EdgeInsets.symmetric(vertical: 4),
          decoration: BoxDecoration(
            border: Border.all(color: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.05)),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SafeMathPreview(latex: latex, textColor: textColor, mathSize: 14),
              const SizedBox(height: 4),
              Text(label, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w500)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNodeWidget(MathNode node, bool isDark, Color textColor) {
    if (node is TextNode) {
      return IntrinsicWidth(
        child: TextFormField(
          initialValue: node.text,
          onChanged: (val) => node.text = val,
          style: TextStyle(
            fontSize: 28, 
            color: textColor, 
            fontFamily: 'serif',
            fontWeight: FontWeight.w400,
          ),
          cursorColor: AppColors.primaryBlue,
          decoration: InputDecoration(
            border: InputBorder.none,
            isDense: true,
            hintText: rootNodes.indexOf(node) == 0 && node.text.isEmpty ? 'اكتب هنا...' : '',
            hintStyle: TextStyle(color: textColor.withValues(alpha: 0.2)),
            contentPadding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
          ),
        ),
      );
    } else if (node is TemplateNode) {
      switch (node.type) {
        case 'fraction':
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildSlot(node.slots['num']!, isDark, textColor),
                Container(width: 40, height: 2, color: textColor, margin: const EdgeInsets.symmetric(vertical: 4)),
                _buildSlot(node.slots['den']!, isDark, textColor),
              ],
            ),
          );
        case 'power':
          return Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              _buildSlot(node.slots['base']!, isDark, textColor),
              Padding(
                padding: const EdgeInsets.only(bottom: 18),
                child: _buildSlot(node.slots['exp']!, isDark, textColor, small: true),
              ),
            ],
          );
        case 'subscript':
          return Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSlot(node.slots['base']!, isDark, textColor),
              Padding(
                padding: const EdgeInsets.only(top: 18),
                child: _buildSlot(node.slots['sub']!, isDark, textColor, small: true),
              ),
            ],
          );
        case 'root':
          return Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('√', style: TextStyle(fontSize: 40, color: textColor, fontFamily: 'serif')),
              _buildSlot(node.slots['content']!, isDark, textColor),
            ],
          );
        case 'nroot':
          return Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 4, right: -10),
                child: _buildSlot(node.slots['n']!, isDark, textColor, small: true),
              ),
              Text('√', style: TextStyle(fontSize: 40, color: textColor, fontFamily: 'serif')),
              _buildSlot(node.slots['content']!, isDark, textColor),
            ],
          );
        case 'integral':
        case 'sum':
          final symbol = node.type == 'integral' ? '∫' : '∑';
          return Row(
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
        case 'bracket':
        case 'square_bracket':
        case 'curly_bracket':
          String open = '(', close = ')';
          if (node.type == 'square_bracket') { open = '['; close = ']'; }
          if (node.type == 'curly_bracket') { open = '{'; close = '}'; }
          return Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(open, style: TextStyle(fontSize: 40, color: textColor, fontWeight: FontWeight.w100)),
              _buildSlot(node.slots['content']!, isDark, textColor),
              Text(close, style: TextStyle(fontSize: 40, color: textColor, fontWeight: FontWeight.w100)),
            ],
          );
        case 'matrix':
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('[', style: TextStyle(fontSize: 50, color: textColor, fontWeight: FontWeight.w100)),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _buildSlot(node.slots['0,0']!, isDark, textColor),
                        const SizedBox(width: 8),
                        _buildSlot(node.slots['0,1']!, isDark, textColor),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _buildSlot(node.slots['1,0']!, isDark, textColor),
                        const SizedBox(width: 8),
                        _buildSlot(node.slots['1,1']!, isDark, textColor),
                      ],
                    ),
                  ],
                ),
                Text(']', style: TextStyle(fontSize: 50, color: textColor, fontWeight: FontWeight.w100)),
              ],
            ),
          );
      }
    }
    return const SizedBox.shrink();
  }

  Widget _buildSlot(List<MathNode> nodes, bool isDark, Color textColor, {bool small = false}) {
    return Container(
      padding: const EdgeInsets.all(4),
      constraints: BoxConstraints(minWidth: small ? 20 : 30, minHeight: small ? 20 : 30),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.02),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(
          color: AppColors.primaryBlue.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: nodes.map((n) {
          if (n is TextNode) {
            return IntrinsicWidth(
              child: TextFormField(
                initialValue: n.text,
                onChanged: (val) => n.text = val,
                style: TextStyle(fontSize: small ? 16 : 20, color: textColor, fontFamily: 'serif'),
                decoration: const InputDecoration(
                  border: InputBorder.none,
                  isDense: true,
                  contentPadding: EdgeInsets.zero,
                  hintText: '?',
                  hintStyle: TextStyle(color: Colors.grey, fontSize: 14),
                ),
              ),
            );
          }
          return _buildNodeWidget(n, isDark, textColor);
        }).toList(),
      ),
    );
  }

  Widget _buildFooter({required bool isDark, required Color textColor, required Color accentColor, required double width}) {
    return Container(
      width: width,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      color: isDark ? Colors.black.withValues(alpha: 0.2) : Colors.grey.withValues(alpha: 0.02),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.info_outline, size: 16, color: accentColor),
          const SizedBox(width: 8),
          Text(
            'اضغط داخل المربعات المنقطة لكتابة الأرقام أو الرموز',
            style: TextStyle(fontSize: 12, color: textColor.withValues(alpha: 0.7)),
          ),
        ],
      ),
    );
  }
}

class VisualMathField extends StatefulWidget {
  final List<MathNode> nodes;
  final Function(String) onChanged;
  final bool isDark;
  final Color textColor;

  const VisualMathField({
    super.key,
    required this.nodes,
    required this.onChanged,
    required this.isDark,
    required this.textColor,
  });

  @override
  State<VisualMathField> createState() => _VisualMathFieldState();
}

class _VisualMathFieldState extends State<VisualMathField> {
  @override
  Widget build(BuildContext context) {
    // Check if the entire field is essentially empty
    bool isEmpty = widget.nodes.every((n) {
      if (n is TextNode) return n.text.trim().isEmpty;
      return false;
    });

    return Directionality(
      textDirection: TextDirection.ltr, // FORCE LTR for math editing
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: widget.isDark ? const Color(0xFF1E293B) : const Color(0xFFF0F7FF),
          border: Border.all(
            color: const Color(0xFF3B82F6).withValues(alpha: 0.5), 
            width: 1.5,
          ),
          borderRadius: BorderRadius.circular(10),
          boxShadow: [
            BoxShadow(
              color: Colors.blue.withValues(alpha: 0.08),
              blurRadius: 4,
              spreadRadius: 1,
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Flexible(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: widget.nodes.map((node) => _InlineNodeBuilder(
                    node: node,
                    isDark: widget.isDark,
                    textColor: widget.textColor,
                    placeholder: isEmpty ? 'اكتب المعادلة هنا' : null,
                    onChanged: () {
                      widget.onChanged(widget.nodes.map((n) => n.toLatex()).join(''));
                    },
                  )).toList(),
                ),
              ),
            ),
            const SizedBox(width: 4),
            Icon(
              Icons.more_vert, 
              size: 16, 
              color: Colors.blue.withValues(alpha: 0.4),
            ),
          ],
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
          textAlign: TextAlign.left,
          style: TextStyle(fontSize: 22, color: textColor, fontFamily: 'serif'),
          cursorColor: AppColors.primaryBlue,
          decoration: InputDecoration(
            border: InputBorder.none,
            isDense: true,
            hintText: placeholder,
            hintStyle: TextStyle(
              color: isDark ? Colors.white24 : Colors.blue.withValues(alpha: 0.3),
              fontSize: 18,
              fontStyle: FontStyle.italic,
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
          ),
        ),
      );
    } else if (node is TemplateNode) {
      final temp = node as TemplateNode;
      return _buildTemplateWidget(temp, isDark, textColor, onChanged);
    }
    return const SizedBox.shrink();
  }

  Widget _buildTemplateWidget(TemplateNode node, bool isDark, Color textColor, VoidCallback onChanged) {
    switch (node.type) {
      case 'fraction':
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildInlineSlot(node.slots['num']!, isDark, textColor, onChanged),
              Container(width: 30, height: 1.5, color: textColor, margin: const EdgeInsets.symmetric(vertical: 2)),
              _buildInlineSlot(node.slots['den']!, isDark, textColor, onChanged),
            ],
          ),
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
      case 'subscript':
        return Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildInlineSlot(node.slots['base']!, isDark, textColor, onChanged),
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: _buildInlineSlot(node.slots['sub']!, isDark, textColor, onChanged, small: true),
            ),
          ],
        );
      case 'root':
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('√', style: TextStyle(fontSize: 32, color: textColor, fontFamily: 'serif')),
            _buildInlineSlot(node.slots['content']!, isDark, textColor, onChanged),
          ],
        );
      case 'nroot':
        return Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 2, right: -6),
              child: _buildInlineSlot(node.slots['n']!, isDark, textColor, onChanged, small: true),
            ),
            Text('√', style: TextStyle(fontSize: 32, color: textColor, fontFamily: 'serif')),
            _buildInlineSlot(node.slots['content']!, isDark, textColor, onChanged),
          ],
        );
      default:
        // Basic versions for others
        return Text(node.toLatex(), style: TextStyle(color: textColor, fontSize: 18));
    }
  }

  Widget _buildInlineSlot(List<MathNode> nodes, bool isDark, Color textColor, VoidCallback onChanged, {bool small = false}) {
    return Container(
      padding: const EdgeInsets.all(2),
      constraints: BoxConstraints(minWidth: small ? 15 : 24, minHeight: small ? 15 : 24),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.02),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: AppColors.primaryBlue.withValues(alpha: 0.2)),
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
    if (latex.trim().isEmpty) {
      return const SizedBox.shrink();
    }
    return Directionality(
      textDirection: TextDirection.ltr,
      child: Math.tex(
        latex,
        textStyle: TextStyle(fontSize: mathSize, color: textColor),
        onErrorFallback: (err) => Text(
          latex,
          style: TextStyle(color: textColor, fontSize: mathSize * 0.75),
        ),
      ),
    );
  }
}

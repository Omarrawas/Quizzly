import 'package:flutter/material.dart';

class MathFieldWidget extends StatelessWidget {
  final TextEditingController controller;
  final VoidCallback onClear;

  const MathFieldWidget({
    super.key,
    required this.controller,
    required this.onClear,
  });

  void _moveCursorLeft() {
    final sel = controller.selection;
    if (!sel.isValid) return;
    final newOffset = (sel.baseOffset - 1).clamp(0, controller.text.length);
    controller.selection = TextSelection.collapsed(offset: newOffset);
  }

  void _moveCursorRight() {
    final sel = controller.selection;
    if (!sel.isValid) return;
    final newOffset = (sel.baseOffset + 1).clamp(0, controller.text.length);
    controller.selection = TextSelection.collapsed(offset: newOffset);
  }

  void _backspace() {
    final sel = controller.selection;
    if (!sel.isValid) return;
    if (sel.start == 0 && sel.end == 0) return;
    final text = controller.text;
    if (sel.start != sel.end) {
      // Delete selected text
      final newText = text.replaceRange(sel.start, sel.end, '');
      controller.value = controller.value.copyWith(
        text: newText,
        selection: TextSelection.collapsed(offset: sel.start),
      );
    } else {
      // Delete character before cursor
      final newText = text.replaceRange(sel.start - 1, sel.start, '');
      controller.value = controller.value.copyWith(
        text: newText,
        selection: TextSelection.collapsed(offset: sel.start - 1),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return DragTarget<String>(
      onAcceptWithDetails: (details) {
        _insertAtCursor(details.data);
      },
      builder: (context, candidateData, rejectedData) {
        return Container(
          decoration: BoxDecoration(
            border: Border.all(color: Theme.of(context).dividerColor),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: Theme.of(context).dividerColor.withValues(alpha: 0.05),
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(8),
                    topRight: Radius.circular(8),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'منطقة الكتابة',
                      style: TextStyle(
                        fontSize: 11,
                        color: Theme.of(context).hintColor,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    TextButton.icon(
                      onPressed: onClear,
                      icon: const Icon(Icons.layers_clear_outlined, size: 13),
                      label: const Text('مسح الكل', style: TextStyle(fontSize: 10)),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 0),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                    ),
                  ],
                ),
              ),
              // Input field
              Directionality(
                textDirection: TextDirection.ltr,
                child: TextField(
                  controller: controller,
                  decoration: const InputDecoration(
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    hintText: r'اكتب LaTeX هنا... مثال: \frac{a}{b}',
                    hintStyle: TextStyle(fontSize: 12),
                  ),
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 13,
                    letterSpacing: 0.5,
                  ),
                  minLines: 1,
                  maxLines: 3,
                  keyboardType: TextInputType.text,
                  textInputAction: TextInputAction.done,
                  enableInteractiveSelection: true,
                ),
              ),
              // Control bar: cursor nav + backspace
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                decoration: BoxDecoration(
                  border: Border(
                    top: BorderSide(color: Theme.of(context).dividerColor),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back, size: 18),
                      onPressed: _moveCursorLeft,
                      tooltip: 'يسار',
                      constraints: const BoxConstraints(),
                      padding: const EdgeInsets.all(6),
                    ),
                    IconButton(
                      icon: const Icon(Icons.arrow_forward, size: 18),
                      onPressed: _moveCursorRight,
                      tooltip: 'يمين',
                      constraints: const BoxConstraints(),
                      padding: const EdgeInsets.all(6),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: const Icon(
                        Icons.backspace_outlined,
                        size: 18,
                        color: Colors.redAccent,
                      ),
                      onPressed: _backspace,
                      tooltip: 'حذف',
                      constraints: const BoxConstraints(),
                      padding: const EdgeInsets.all(6),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _insertAtCursor(String text) {
    final sel = controller.selection;
    final currentText = controller.text;
    final start = sel.isValid ? sel.start : currentText.length;
    final end = sel.isValid ? sel.end : currentText.length;
    final newText = currentText.replaceRange(start, end, text);
    controller.value = controller.value.copyWith(
      text: newText,
      selection: TextSelection.collapsed(offset: start + text.length),
    );
  }
}

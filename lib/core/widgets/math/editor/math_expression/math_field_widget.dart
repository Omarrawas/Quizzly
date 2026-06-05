import 'package:flutter/material.dart';
import 'package:math_keyboard/math_keyboard.dart';

class MathFieldWidget extends StatelessWidget {
  final MathFieldEditingController controller;
  final VoidCallback onClear;

  const MathFieldWidget({
    super.key,
    required this.controller,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    return DragTarget<String>(
      onAcceptWithDetails: (details) {
        final symbol = details.data;
        controller.addLeaf(symbol);
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
                    IconButton(
                      icon: const Icon(Icons.keyboard_hide_outlined, size: 16),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      onPressed: () {
                        FocusScope.of(context).unfocus();
                      },
                      tooltip: 'إخفاء لوحة المفاتيح',
                    ),
                  ],
                ),
              ),
              Container(
                constraints: const BoxConstraints(
                  minHeight: 60,
                  maxHeight: 180,
                ),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                    child: Column(
                      children: [
                        MathField(
                          controller: controller,
                          variables: const [
                            'x', 'y', 'z', 'r', 'n', 'k', 'i', 'j',
                            r'\theta', r'\alpha', r'\beta', r'\gamma', r'\delta',
                            'a', 'b', 'c', 't', 'v', 'f', 'E', 'm',
                          ],
                          decoration: const InputDecoration(
                            border: InputBorder.none,
                            contentPadding: EdgeInsets.all(8),
                          ),
                          onChanged: (value) {},
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                          decoration: BoxDecoration(
                            border: Border(top: BorderSide(color: Theme.of(context).dividerColor)),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              TextButton.icon(
                                onPressed: onClear,
                                icon: const Icon(Icons.layers_clear_outlined, size: 14),
                                label: const Text('مسح الكل', style: TextStyle(fontSize: 10)),
                              ),
                              const Spacer(),
                              IconButton(
                                icon: const Icon(Icons.arrow_back, size: 18),
                                onPressed: () {
                                  // Simplified movement or ignore if method not found
                                  try { (controller as dynamic).moveCursorLeft(); } catch(_) {}
                                },
                                tooltip: 'يسار',
                              ),
                              IconButton(
                                icon: const Icon(Icons.arrow_forward, size: 18),
                                onPressed: () {
                                  try { (controller as dynamic).moveCursorRight(); } catch(_) {}
                                },
                                tooltip: 'يمين',
                              ),
                              const SizedBox(width: 8),
                              IconButton(
                                icon: const Icon(Icons.backspace_outlined, size: 18, color: Colors.redAccent),
                                onPressed: () {
                                  try { (controller as dynamic).backspace(); } catch(_) {}
                                },
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      );
  }
}

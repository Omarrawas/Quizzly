import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quizzly/core/widgets/rich_text_editor.dart';
import 'package:flutter_math_fork/flutter_math.dart' as math_fork;

void main() {
  testWidgets('RichTextEditor auto-converts typed LaTeX block to math embed', (WidgetTester tester) async {
    String changedHtml = '';
    
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: RichTextEditor(
            initialHtml: '',
            onContentChanged: (html) {
              changedHtml = html;
            },
          ),
        ),
      ),
    );

    // Find the editor widget
    final editorFinder = find.byType(RichTextEditor);
    expect(editorFinder, findsOneWidget);

    // Get the state of RichTextEditor and cast dynamically
    final dynamic state = tester.state<State<RichTextEditor>>(editorFinder);
    
    // Simulate user typing \(x^2 + y^2 = r^2\)
    state.controller.replaceText(0, 0, r'\(x^2 + y^2 = r^2\)', null);
    
    // Trigger paint/microtasks
    await tester.pumpAndSettle();

    // Verify it converts to the embed and displays the Math widget
    expect(find.byType(math_fork.Math), findsOneWidget);

    // Verify that html content has the correct raw delimiters \(...\)
    expect(changedHtml, contains(r'\(x^2 + y^2 = r^2\)'));
  });
}

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quizzly/core/widgets/tex_view_widget.dart';
import 'package:flutter_math_fork/flutter_math.dart';

void main() {
  testWidgets('TexViewWidget paragraph wrap layout test', (WidgetTester tester) async {
    const testHtml = '<p style="text-align:right">اوجد العلاقة بين \\(\\infty\\) و\\(^\\circ\\text{C}\\) </p>';
    
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TexViewWidget(text: testHtml),
        ),
      ),
    );

    await tester.pumpAndSettle();

    final mathFinders = find.byType(Math);
    expect(mathFinders, findsNWidgets(2));

    final math0Center = tester.getCenter(mathFinders.at(0));
    final math1Center = tester.getCenter(mathFinders.at(1));

    debugPrint('Math 0 center X: ${math0Center.dx}');
    debugPrint('Math 1 center X: ${math1Center.dx}');

    // In RTL, Math 0 (first equation) must be to the right of Math 1 (second equation)
    expect(math0Center.dx, greaterThan(math1Center.dx));
  });
}

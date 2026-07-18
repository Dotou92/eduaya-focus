import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:eduayo_focus/main.dart';

void main() {
  testWidgets('SubjectSelectionScreen affiche la liste des matières',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: SubjectSelectionScreen()),
    );

    expect(find.text('Mathématiques'), findsOneWidget);
    expect(find.text('Français'), findsOneWidget);
  });

  testWidgets('Sélectionner une matière ouvre le choix de l\'heure de fin',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: SubjectSelectionScreen()),
    );

    await tester.tap(find.text('Mathématiques'));
    await tester.pumpAndSettle();

    expect(find.text('Heure de fin de session'), findsOneWidget);
  });
}

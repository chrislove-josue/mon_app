import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:mon_app/main.dart';

void main() {
  testWidgets('Le jeu se lance et affiche le message de départ',
      (WidgetTester tester) async {
    await tester.pumpWidget(const MonJeu());

    expect(find.text('🎯 Devine le nombre'), findsOneWidget);
    expect(find.text('Entrée un nombre entre 1 et 100 !'), findsOneWidget);
    expect(find.text('Tu as 10 tentatives maximum !'), findsOneWidget);
    expect(find.text('Tentatives : 0 / 10'), findsOneWidget);
  });

  testWidgets('Un essai invalide affiche un message d erreur',
      (WidgetTester tester) async {
    await tester.pumpWidget(const MonJeu());

    await tester.enterText(find.byType(TextField), 'abc');
    await tester.tap(find.text('Essayer'));
    await tester.pump();

    expect(find.text('Écris un vrai nombre (1 à 100) 🤔'), findsOneWidget);
    expect(find.text('Tentatives : 0 / 10'), findsOneWidget);
  });

  testWidgets('Un mauvais essai réduit le compteur', (WidgetTester tester) async {
    await tester.pumpWidget(const MonJeu());

    await tester.enterText(find.byType(TextField), '42');
    await tester.tap(find.text('Essayer'));
    await tester.pump();

    expect(find.text('Tentatives : 1 / 10'), findsOneWidget);
    expect(find.textContaining('Dernier essai : 42'), findsOneWidget);
  });
}
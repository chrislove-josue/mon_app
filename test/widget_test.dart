import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:mon_app/screens/game_page.dart';
import 'package:mon_app/screens/memory_page.dart';

Widget fabriqueJeu({
  Future<void> Function(int)? saveScore,
  VoidCallback? onLogout,
  int Function()? secretGenerator,
}) {
  return MaterialApp(
    // Ripple classique (comme dans l'app) : évite le shader "sparkle"
    // Material 3, qui échoue à se compiler dans l'environnement de test.
    theme: ThemeData(splashFactory: InkRipple.splashFactory),
    home: GamePage(
      saveScore: saveScore,
      onLogout: onLogout,
      secretGenerator: secretGenerator,
    ),
  );
}

void main() {
  testWidgets('Le jeu se lance et affiche le message de départ',
      (WidgetTester tester) async {
    await tester.pumpWidget(fabriqueJeu());

    expect(find.text('🎯 Devine le nombre'), findsOneWidget);
    expect(find.text('Entrée un nombre entre 1 et 100 !'), findsOneWidget);
    expect(find.text('Tu as 10 tentatives maximum !'), findsOneWidget);
    expect(find.text('Tentatives : 0 / 10'), findsOneWidget);
  });

  testWidgets('Un essai invalide affiche un message d erreur',
      (WidgetTester tester) async {
    await tester.pumpWidget(fabriqueJeu());

    await tester.enterText(find.byType(TextField), 'abc');
    await tester.tap(find.text('Essayer'));
    await tester.pump();

    expect(find.text('Écris un vrai nombre (1 à 100) 🤔'), findsOneWidget);
    expect(find.text('Tentatives : 0 / 10'), findsOneWidget);
  });

  testWidgets('Un mauvais essai réduit le compteur', (WidgetTester tester) async {
    await tester.pumpWidget(fabriqueJeu(secretGenerator: () => 7));

    await tester.enterText(find.byType(TextField), '42');
    await tester.tap(find.text('Essayer'));
    await tester.pump();

    expect(find.textContaining('Tentatives : 1 / 10'), findsOneWidget);
    expect(find.textContaining('Dernier essai : 42'), findsOneWidget);
  });

  testWidgets('La victoire sauvegarde le score', (WidgetTester tester) async {
    final sauvegardes = <int>[];
    await tester.pumpWidget(
      fabriqueJeu(
        saveScore: (tentatives) async {
          sauvegardes.add(tentatives);
        },
        secretGenerator: () => 42, // le secret est connu
      ),
    );

    await tester.enterText(find.byType(TextField), '42');
    await tester.tap(find.text('Essayer'));
    await tester.pumpAndSettle();

    expect(sauvegardes, isNotEmpty);
    expect(sauvegardes.first, 1);
    expect(find.textContaining('BRAVO'), findsOneWidget);
    expect(find.text('🔄 Rejouer'), findsOneWidget);
  });

  testWidgets('Le bouton de déconnexion est appelé',
      (WidgetTester tester) async {
    var deconnecte = false;
    await tester.pumpWidget(
      fabriqueJeu(onLogout: () => deconnecte = true),
    );

    await tester.tap(find.byIcon(Icons.logout));
    await tester.pump();

    expect(deconnecte, isTrue);
  });

  testWidgets('Le Mémory démarre carte ouvertes, puis referme après 5 s',
      (WidgetTester tester) async {
    await tester.pumpWidget(const MaterialApp(home: MemoryPage()));

    expect(find.text('Coups : 0'), findsOneWidget);
    // Phase de mémorisation : toutes les cartes sont ouvertes (aucun « ? »).
    expect(find.byIcon(Icons.question_mark), findsNothing);

    // Après 5 secondes, les cartes se referment.
    await tester.pump(const Duration(seconds: 5));
    expect(find.byIcon(Icons.question_mark), findsWidgets);
  });

  testWidgets('Le Mémory permet de retourner des cartes',
      (WidgetTester tester) async {
    await tester.pumpWidget(const MaterialApp(home: MemoryPage()));

    // Attend la fin de la mémorisation pour pouvoir jouer.
    await tester.pump(const Duration(seconds: 5));

    // Retourner une première carte change le compteur de paires visibles.
    final cartes = find.byType(GestureDetector);
    await tester.tap(cartes.at(0));
    await tester.pumpAndSettle();

    // Un coup = retourner deux cartes.
    await tester.tap(cartes.at(1));
    await tester.pump(const Duration(milliseconds: 800)); // laisse le timer finir

    expect(find.text('Coups : 1'), findsOneWidget);
  });
}
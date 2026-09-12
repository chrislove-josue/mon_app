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

/// Lance le Mémory dans une app de test avec un ripple classique
/// (évite le shader M3 "sparkle" non compilable dans les tests).
Widget fabriqueMemoire() {
  return MaterialApp(
    theme: ThemeData(splashFactory: InkRipple.splashFactory),
    home: const MemoryPage(),
  );
}

/// Démarre la partie : clique sur « Commencer ».
Future<void> demarrePartie(WidgetTester tester) async {
  await tester.tap(find.text('Commencer'));
  await tester.pump();
}

void main() {
  testWidgets('Le jeu se lance et affiche l écran de démarrage',
      (WidgetTester tester) async {
    await tester.pumpWidget(fabriqueJeu());

    expect(find.text('🎯 Devine le nombre'), findsOneWidget);
    expect(find.textContaining('Commencer'), findsWidgets);
    expect(find.text('Tu as 10 tentatives maximum !'), findsOneWidget);
    // Le chrono affiche les 2 minutes pleines.
    expect(find.text('⏱ Temps restant : 2:00'), findsOneWidget);
  });

  testWidgets('Un essai invalide affiche un message d erreur',
      (WidgetTester tester) async {
    await tester.pumpWidget(fabriqueJeu());
    await demarrePartie(tester);

    await tester.enterText(find.byType(TextField), 'abc');
    await tester.tap(find.text('Essayer'));
    await tester.pump();

    expect(find.text('Écris un vrai nombre (1 à 100) 🤔'), findsOneWidget);
    expect(find.text('Tentatives : 0 / 10'), findsOneWidget);
  });

  testWidgets('Un mauvais essai réduit le compteur', (WidgetTester tester) async {
    await tester.pumpWidget(fabriqueJeu(secretGenerator: () => 7));
    await demarrePartie(tester);

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
    await demarrePartie(tester);

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

  testWidgets('Le chrono décompte toutes les secondes une fois lancé',
      (WidgetTester tester) async {
    await tester.pumpWidget(fabriqueJeu());
    await demarrePartie(tester);

    expect(find.text('⏱ Temps restant : 2:00'), findsOneWidget);

    await tester.pump(const Duration(seconds: 5));
    expect(find.text('⏱ Temps restant : 1:55'), findsOneWidget);
  });

  testWidgets('Le temps écoulé termine la partie', (WidgetTester tester) async {
    await tester.pumpWidget(fabriqueJeu());
    await demarrePartie(tester);

    await tester.pump(const Duration(seconds: 120));

    expect(find.textContaining('Temps écoulé'), findsOneWidget);
    expect(find.text('🔄 Rejouer'), findsOneWidget);
  });

  testWidgets('Le Mémory affiche un écran Commencer au lancement',
      (WidgetTester tester) async {
    await tester.pumpWidget(fabriqueMemoire());

    expect(find.text('Prêt à jouer au Mémory ?'), findsOneWidget);
    expect(find.text('Commencer'), findsOneWidget);
  });

  testWidgets('Le Mémory démarre, mémorise 5 s puis referme les cartes',
      (WidgetTester tester) async {
    await tester.pumpWidget(fabriqueMemoire());
    await tester.tap(find.text('Commencer'));
    await tester.pump();

    expect(find.text('Coups : 0'), findsOneWidget);
    expect(find.text('⏱ 2:00'), findsOneWidget);
    // Phase de mémorisation : toutes les cartes sont ouvertes (aucun « ? »).
    expect(find.byIcon(Icons.question_mark), findsNothing);

    // Après 5 secondes, les cartes se referment.
    await tester.pump(const Duration(seconds: 5));
    expect(find.byIcon(Icons.question_mark), findsWidgets);
  });

  testWidgets('Le Mémory permet de retourner des cartes',
      (WidgetTester tester) async {
    await tester.pumpWidget(fabriqueMemoire());
    await tester.tap(find.text('Commencer'));
    await tester.pump();

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

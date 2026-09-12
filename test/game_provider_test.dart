import 'package:flutter_test/flutter_test.dart';

import 'package:mon_app/providers/game_provider.dart';

/// Tests « unitaires » : on teste la LOGIQUE DU JEU sans interface.
/// Grâce au Provider, le jeu est testable directement.
void main() {
  test('Un essai invalide ne compte pas', () {
    final game = GameProvider(secretGenerator: () => 42);
    game.nouvellePartie();

    game.essayer('ceci n est pas un nombre');

    expect(game.tentatives, 0);
    expect(game.message, contains('vrai nombre'));
  });

  test('Trouver le nombre gagne et sauvegarde le score', () {
    final scores = <int>[];
    final game = GameProvider(
      secretGenerator: () => 42,
      saveScore: (tentatives) async => scores.add(tentatives),
    );
    game.nouvellePartie();

    game.essayer('42');

    expect(game.gagne, isTrue);
    expect(game.message, contains('BRAVO'));
    expect(scores, [1]);
  });

  test('10 mauvais essais = défaite', () {
    final game = GameProvider(secretGenerator: () => 1);
    game.nouvellePartie();

    // On essaie TOUS les nombres sauf le secret (1)...
    for (var i = 2; i <= 100 && !game.perdu; i++) {
      game.essayer('$i');
    }

    expect(game.perdu, isTrue);
    expect(game.gagne, isFalse);
    expect(game.tentatives, GameProvider.maxTentatives);
    expect(game.message, contains('Perdu'));
  });

  test('Redémarrer une partie réinitialise tout', () {
    final game = GameProvider(secretGenerator: () => 42);
    game.nouvellePartie();
    game.essayer('10'); // un mauvais essai

    game.nouvellePartie();

    expect(game.tentatives, 0);
    expect(game.gagne, isFalse);
    expect(game.perdu, isFalse);
    expect(game.dernierChiffre, isNull);
    expect(game.message, 'Entrée un nombre entre 1 et 100 !');
  });

  test('Le nombre magique est utilisé et conservé entre les parties', () {
    final game = GameProvider(
      nombreMagique: 42,
      saveScore: (_) async {},
    );
    game.nouvellePartie();

    game.essayer('41');
    expect(game.message, contains('Plus grand'));

    // On relance une partie : le nombre magique reste le même (42).
    game.nouvellePartie();
    game.essayer('41');
    expect(game.message, contains('Plus grand'));

    game.essayer('42');
    expect(game.gagne, isTrue);
    expect(game.message, contains('BRAVO'));
  });

  group('Chrono (1 minute de jeu)', () {
    test('Le temps écoulé déclenche la défaite', () {
      final game = GameProvider(
        dureePartieSecondes: 3,
        secretGenerator: () => 42,
      );
      game.nouvellePartie();

      expect(game.tempsRestant, 3);
      expect(game.perdu, isFalse);

      game.decrementerTemps();
      game.decrementerTemps();
      expect(game.perdu, isFalse);
      expect(game.tempsRestant, 1);

      game.decrementerTemps();
      expect(game.perdu, isTrue);
      expect(game.tempsRestant, 0);
      expect(game.gagne, isFalse);
      expect(game.message, contains('Temps écoulé'));
    });

    test('Une fois le temps écoulé, on ne peut plus jouer', () {
      final game = GameProvider(
        dureePartieSecondes: 1,
        secretGenerator: () => 42,
      );
      game.nouvellePartie();
      game.decrementerTemps(); // temps écoulé

      game.essayer('42'); // tentative après la fin : ignorée
      expect(game.tentatives, 0);
      expect(game.perdu, isTrue);
    });

    test('Un temps écoulé ne sauvegarde pas de score', () {
      final scores = <int>[];
      final game = GameProvider(
        dureePartieSecondes: 1,
        secretGenerator: () => 42,
        saveScore: (tentatives) async => scores.add(tentatives),
      );
      game.nouvellePartie();

      game.decrementerTemps();

      expect(game.perdu, isTrue);
      expect(scores, isEmpty);
    });

    test('Nouvelle partie remet le chrono au complet', () {
      final game = GameProvider(
        dureePartieSecondes: 3,
        secretGenerator: () => 42,
      );
      game.nouvellePartie();
      game.decrementerTemps();
      game.decrementerTemps();

      game.nouvellePartie();

      expect(game.tempsRestant, 3);
      expect(game.perdu, isFalse);
    });

    test('Le chrono ne décompte plus après une victoire', () {
      final game = GameProvider(
        dureePartieSecondes: 5,
        secretGenerator: () => 42,
        saveScore: (_) async {},
      );
      game.nouvellePartie();
      game.essayer('42');

      expect(game.gagne, isTrue);
      expect(game.tempsRestant, 5);

      game.decrementerTemps();
      expect(game.tempsRestant, 5); // inchangé
    });
  });
}
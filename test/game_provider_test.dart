import 'package:flutter_test/flutter_test.dart';

import 'package:mon_app/providers/game_provider.dart';

/// Tests « unitaires » : on teste la LOGIQUE DU JEU sans interface.
/// Grâce au Provider, le jeu est testable directement.
void main() {
  test('Avant de cliquer Commencer, une proposition est ignorée', () {
    final game = GameProvider(secretGenerator: () => 42);
    game.nouvellePartie();

    expect(game.partieEnCours, isFalse);

    game.essayer('42');

    expect(game.tentatives, 0);
    expect(game.gagne, isFalse);
  });

  test('Un essai invalide ne compte pas', () {
    final game = GameProvider(secretGenerator: () => 42);
    game.commencerPartie();

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
    game.commencerPartie();

    game.essayer('42');

    expect(game.gagne, isTrue);
    expect(game.message, contains('BRAVO'));
    expect(scores, [1]);
  });

  test('10 mauvais essais = défaite', () {
    final game = GameProvider(secretGenerator: () => 1);
    game.commencerPartie();

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
    game.commencerPartie();
    game.essayer('10'); // un mauvais essai

    game.nouvellePartie();

    expect(game.tentatives, 0);
    expect(game.gagne, isFalse);
    expect(game.perdu, isFalse);
    expect(game.dernierChiffre, isNull);
    expect(game.partieEnCours, isFalse);
    expect(game.message, contains('Commencer'));
  });

  test('Le nombre magique est utilisé et conservé entre les parties', () {
    final game = GameProvider(
      nombreMagique: 42,
      saveScore: (_) async {},
    );
    game.commencerPartie();

    game.essayer('41');
    expect(game.message, contains('Plus grand'));

    // On relance une partie : le nombre magique reste le même (42).
    game.nouvellePartie();
    game.commencerPartie();
    game.essayer('41');
    expect(game.message, contains('Plus grand'));

    game.essayer('42');
    expect(game.gagne, isTrue);
    expect(game.message, contains('BRAVO'));
  });

  test('definirNombreMagique met à jour le jeu en cours', () {
    final game = GameProvider(saveScore: (_) async {});
    game.definirNombreMagique(42);
    game.commencerPartie();

    game.essayer('41');
    expect(game.message, contains('Plus grand'));

    // L'admin change le nombre : la partie en cours garde son secret,
    // mais la SUIVANTE utilisera 77.
    game.definirNombreMagique(77);
    expect(game.nombreMagique, 77);

    game.nouvellePartie();
    game.commencerPartie();
    game.essayer('76');
    expect(game.message, contains('Plus grand'));
    game.essayer('77');
    expect(game.gagne, isTrue);
  });

  test('Trouver le nombre magique déclenche sa régénération', () {
    final trouves = <int>[];
    final game = GameProvider(
      nombreMagique: 42,
      saveScore: (_) async {},
      onNombreMagiqueTrouve: (nombre) async => trouves.add(nombre),
    );
    game.commencerPartie();

    // Une partie non magique : pas de régénération.
    game.essayer('41');
    expect(trouves, isEmpty);

    // On gagne sur le nombre magique → régénération déclenchée.
    game.essayer('42');
    expect(game.gagne, isTrue);
    expect(trouves, [42]);
  });

  test('Une victoire sans nombre magique ne régénère rien', () {
    final trouves = <int>[];
    final game = GameProvider(
      secretGenerator: () => 42,
      saveScore: (_) async {},
      onNombreMagiqueTrouve: (nombre) async => trouves.add(nombre),
    );
    game.commencerPartie();

    game.essayer('42');
    expect(game.gagne, isTrue);
    expect(trouves, isEmpty);
  });

  group('Chrono (2 minutes de jeu)', () {
    test('Le temps écoulé déclenche la défaite', () {
      final game = GameProvider(
        dureePartieSecondes: 3,
        secretGenerator: () => 42,
      );
      game.commencerPartie();

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
      expect(game.partieEnCours, isFalse);
      expect(game.message, contains('Temps écoulé'));
    });

    test('Une fois le temps écoulé, on ne peut plus jouer', () {
      final game = GameProvider(
        dureePartieSecondes: 1,
        secretGenerator: () => 42,
      );
      game.commencerPartie();
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
      game.commencerPartie();

      game.decrementerTemps();

      expect(game.perdu, isTrue);
      expect(scores, isEmpty);
    });

    test('Nouvelle partie remet le chrono au complet', () {
      final game = GameProvider(
        dureePartieSecondes: 3,
        secretGenerator: () => 42,
      );
      game.commencerPartie();
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
      game.commencerPartie();
      game.essayer('42');

      expect(game.gagne, isTrue);
      expect(game.tempsRestant, 5);

      game.decrementerTemps();
      expect(game.tempsRestant, 5); // inchangé
    });
  });
}
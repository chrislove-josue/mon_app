import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

/// ============================================================
/// PROVIDER DU JEU (ChangeNotifier)
/// ============================================================
///
/// Avant : toute la logique du jeu vivait dans le widget GamePage,
/// mélangée avec l'interface (build, TextField, boutons...).
///
/// Maintenant : L'ÉTAT vit ici, dans un objet indépendant.
///   - les widgets lisent l'état (game.tentatives, game.message...)
///   - l'écran n'appelle que des actions : essayer(), nouvellePartie()
///   - notifyListeners() prévient les widgets d'un changement
///
/// Avantage : on peut tester la logique du jeu SANS interface,
/// et réutiliser le même état à plusieurs endroits.
/// ============================================================

class GameProvider extends ChangeNotifier {
  GameProvider({
    this.saveScore,
    this.secretGenerator,
    this.onNombreMagiqueTrouve,
    this._nombreMagique,
    this.dureePartieSecondes = defaultDureePartie,
  });

  // --- Injection (utilisée dans les tests) ---
  final Future<void> Function(int tentatives)? saveScore;
  final int Function()? secretGenerator;

  /// Appelé dès qu'un joueur trouve le nombre magique : permet de le
  /// régénérer automatiquement (un nouveau nombre pour les parties à venir).
  /// Null en mode test → aucune régénération.
  final Future<void> Function(int nombreTrouve)? onNombreMagiqueTrouve;

  /// Nombre magique central (défini par l'admin dans `config/magic`).
  /// S'il est fourni, TOUTES les parties se jouent avec ce nombre :
  /// tout le monde devine le même nombre. Sinon, tirage aléatoire.
  /// Volatile : l'app l'écoute en direct, il change quand l'admin le modifie.
  int? _nombreMagique;
  int? get nombreMagique => _nombreMagique;

  /// Met à jour le nombre magique (appelé quand le document `config/magic`
  /// change en base) : le prochain « Commencer » en tiendra compte.
  void definirNombreMagique(int? nombre) {
    if (_nombreMagique == nombre) return;
    _nombreMagique = nombre;
    notifyListeners();
  }

  /// Durée d'une partie (compte à rebours). 2 minutes par défaut.
  final int dureePartieSecondes;

  // --- Constantes ---
  static const maxTentatives = 10;
  static const defaultDureePartie = 120;

  // --- État interne (privé, accessible en lecture via les getters) ---
  int _secret = 0;
  int _tentatives = 0;
  String _message = '';
  int? _dernierChiffre;
  bool _gagne = false;
  bool _perdu = false;
  int _tempsRestant = 0;
  bool _partieEnCours = false;

  /// La partie en cours se joue-t-elle sur le nombre magique ?
  /// (au moment de « Commencer », le secret était celui du document
  /// config/magic). Permet de savoir s'il faut le régénérer à la victoire.
  bool _partieSurNombreMagique = false;

  // --- Getters : les widgets affichent ces valeurs ---
  int get tentatives => _tentatives;
  String get message => _message;
  int? get dernierChiffre => _dernierChiffre;
  bool get gagne => _gagne;
  bool get perdu => _perdu;

  /// Secondes restantes avant la fin du temps de jeu.
  int get tempsRestant => _tempsRestant;

  /// La partie a-t-elle été lancée par le joueur (« Commencer ») ?
  bool get partieEnCours => _partieEnCours;

  /// Prépare une nouvelle partie (état initial, chrono remis à zéro).
  /// Le jeu ne démarre réellement que quand le joueur clique « Commencer ».
  void nouvellePartie() {
    _tentatives = 0;
    _dernierChiffre = null;
    _gagne = false;
    _perdu = false;
    _tempsRestant = dureePartieSecondes;
    _partieEnCours = false;
    _message = 'Appuie sur Commencer pour lancer la partie !';

    // On prévient toutes les pages qui écoutent : « jeux mis à jour ! »
    notifyListeners();
  }

  /// Le joueur clique « Commencer » : on tire le nombre secret et on lance
  /// le chrono. Le nombre magique de l'admin prime ; sinon tirage 1 → 100.
  void commencerPartie() {
    if (_nombreMagique != null) {
      _secret = _nombreMagique!;
      _partieSurNombreMagique = true;
    } else {
      final aleatoire = secretGenerator ?? () => Random().nextInt(100) + 1;
      _secret = aleatoire();
      _partieSurNombreMagique = false;
    }
    _tentatives = 0;
    _dernierChiffre = null;
    _gagne = false;
    _perdu = false;
    _tempsRestant = dureePartieSecondes;
    _partieEnCours = true;
    _message = 'Entrée un nombre entre 1 et 100 !';

    notifyListeners();
  }

  /// Analyse et compare une proposition au nombre secret.
  void essayer(String texte) {
    // Une partie non lancée ou terminée n'accepte plus de proposition.
    if (!_partieEnCours || _gagne || _perdu) return;
    // int.tryParse : essaie de transformer le texte en nombre.
    final proposition = int.tryParse(texte);

    if (proposition == null) {
      _message = 'Écris un vrai nombre (1 à 100) 🤔';
      notifyListeners();
      return;
    }

    _tentatives++;
    _dernierChiffre = proposition;

    if (proposition == _secret) {
      // Victoire !
      _gagne = true;
      _partieEnCours = false;
      _message = '🎉 BRAVO ! Tu as trouvé $proposition en '
          '$_tentatives tentatives !';
      // On sauvegarde le score (les erreurs sont ignorées).
      _enregistrerScore(_tentatives);
      // Nombre magique trouvé → on en tire un nouveau pour la suite
      // (les erreurs sont ignorées : le jeu continue).
      _regenererNombreMagiqueSiTrouve();
    } else if (_tentatives >= maxTentatives) {
      // Plus aucun essai restant → défaite
      _perdu = true;
      _partieEnCours = false;
      _message = '😞 Perdu ! Le nombre était $_secret. '
          'Tu as utilisé tes $maxTentatives tentatives !';
    } else if (proposition < _secret) {
      _message = '⬆️ Plus grand que $proposition !';
    } else {
      _message = '⬇️ Plus petit que $proposition !';
    }

    notifyListeners();
  }

  /// Appelé chaque seconde par le chrono : décompte le temps restant.
  /// Si le temps tombe à zéro, la partie est perdue.
  void decrementerTemps() {
    if (!_partieEnCours || _gagne || _perdu || _tempsRestant <= 0) return;
    _tempsRestant--;
    if (_tempsRestant == 0) {
      _perdu = true;
      _partieEnCours = false;
      _message = '⏰ Temps écoulé ! Le nombre était $_secret.';
    }
    notifyListeners();
  }

  /// Si la partie se jouait sur le nombre magique ET que le joueur a gagné,
  /// on prévient (via le callback injecté) qu'il faut en tirer un nouveau.
  void _regenererNombreMagiqueSiTrouve() {
    if (!_partieSurNombreMagique || onNombreMagiqueTrouve == null) return;
    onNombreMagiqueTrouve!(_secret);
  }

  /// Sauvegarde le record. Le « meilleur » score = le moins de tentatives.
  Future<void> _enregistrerScore(int tentatives) async {
    try {
      if (saveScore != null) {
        await saveScore!(tentatives); // mode test
      } else {
        await _sauverDansFirestore(tentatives);
      }
    } catch (e) {
      // Le jeu continue même si la sauvegarde échoue (pas d'internet...).
      debugPrint('Échec de la sauvegarde du score : $e');
    }
  }

  Future<void> _sauverDansFirestore(int tentatives) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    // Chaque joueur a UN document dans « scores », identifié par son uid.
    final ref =
        FirebaseFirestore.instance.collection('scores').doc(user.uid);

    final doc = await ref.get();
    final actuel =
        doc.exists ? (doc['tentatives'] as num?)?.toInt() : null;

    // On garde le MEILLEUR score (le plus petit nombre de tentatives).
    final meilleur =
        (actuel == null || tentatives < actuel) ? tentatives : actuel;

    await ref.set({
      'email': user.email ?? 'anonyme',
      'tentatives': meilleur,
      'date': FieldValue.serverTimestamp(),
    });
  }
}
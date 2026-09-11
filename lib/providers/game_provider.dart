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
  GameProvider({this.saveScore, this.secretGenerator});

  // --- Injection (utilisée dans les tests) ---
  final Future<void> Function(int tentatives)? saveScore;
  final int Function()? secretGenerator;

  // --- Constantes ---
  static const maxTentatives = 10;

  // --- État interne (privé, accessible en lecture via les getters) ---
  int _secret = 0;
  int _tentatives = 0;
  String _message = '';
  int? _dernierChiffre;
  bool _gagne = false;
  bool _perdu = false;

  // --- Getters : les widgets affichent ces valeurs ---
  int get tentatives => _tentatives;
  String get message => _message;
  int? get dernierChiffre => _dernierChiffre;
  bool get gagne => _gagne;
  bool get perdu => _perdu;

  /// Démarre un nouveau nombre secret.
  void nouvellePartie() {
    // Par défaut : tirage aléatoire 1 → 100 (injectable dans les tests).
    final aleatoire = secretGenerator ?? () => Random().nextInt(100) + 1;

    _secret = aleatoire();
    _tentatives = 0;
    _dernierChiffre = null;
    _gagne = false;
    _perdu = false;
    _message = 'Entrée un nombre entre 1 et 100 !';

    // On prévient toutes les pages qui écoutent : « jeux mis à jour ! »
    notifyListeners();
  }

  /// Analyse et compare une proposition au nombre secret.
  void essayer(String texte) {
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
      _message = '🎉 BRAVO ! Tu as trouvé $proposition en '
          '$_tentatives tentatives !';
      // On sauvegarde le score (les erreurs sont ignorées).
      _enregistrerScore(_tentatives);
    } else if (_tentatives >= maxTentatives) {
      // Plus aucun essai restant → défaite
      _perdu = true;
      _message = '😞 Perdu ! Le nombre était $_secret. '
          'Tu as utilisé tes $maxTentatives tentatives !';
    } else if (proposition < _secret) {
      _message = '⬆️ Plus grand que $proposition !';
    } else {
      _message = '⬇️ Plus petit que $proposition !';
    }

    notifyListeners();
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
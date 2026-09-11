import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'leaderboard_page.dart';

/// ============================================================
/// LE JEU « DEVINE LE NOMBRE »
/// ============================================================
///
/// Découpé en 3 responsabilités :
///   - afficher et jouer (StatefulWidget + setState)
///   - sauvegarder le score dans Firestore (mise à jour du record)
///   - déconnexion + accès au classement
///
/// Astuce tests : saveScore et onLogout peuvent être injectés
/// pour tester le jeu sans connexion réelle à Firebase.
/// ============================================================

class GamePage extends StatefulWidget {
  const GamePage({
    super.key,
    this.saveScore,
    this.onLogout,
    this.secretGenerator,
  });

  /// Remplace le comportement Firestore (utilisé dans les tests).
  final Future<void> Function(int tentatives)? saveScore;

  /// Remplace la déconnexion Firebase (utilisé dans les tests).
  final VoidCallback? onLogout;

  /// Remplace le tirage aléatoire du nombre secret (utilisé dans les tests).
  final int Function()? secretGenerator;

  @override
  State<GamePage> createState() => _GamePageState();
}

class _GamePageState extends State<GamePage> {
  // --- Les variables qui représentent l'état du jeu ---

  static const _maxTentatives = 10; // nombre maximum d'essais
  final _controller = TextEditingController(); // l'entrée de texte
  int _secret = 0; // le nombre mystère
  int _tentatives = 0; // compteur de tentatives
  String _message = 'Entrée un nombre entre 1 et 100 !'; // message affiché
  int? _dernierChiffre; // le dernier nombre proposé
  bool _gagne = false; // la partie est-elle gagnée ?
  bool _perdu = false; // a-t-on épuisé toutes les tentatives ?

  @override
  void initState() {
    super.initState();
    _nouvellePartie();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// Choisit un nouveau nombre secret.
  void _nouvellePartie() {
    // Par défaut : tirage aléatoire 1 → 100.
    // Dans les tests : on peut imposer un nombre précis.
    final aleatoire =
        widget.secretGenerator ?? () => Random().nextInt(100) + 1;

    setState(() {
      _secret = aleatoire();
      _tentatives = 0;
      _message = 'Entrée un nombre entre 1 et 100 !';
      _dernierChiffre = null;
      _gagne = false;
      _perdu = false;
      _controller.clear();
    });
  }

  /// Compare la proposition au nombre secret.
  void _essayer() {
    // int.tryParse : essaie de transformer le texte en nombre.
    // Retourne null si ce n'est pas un nombre valide.
    final proposition = int.tryParse(_controller.text);

    if (proposition == null) {
      setState(() {
        _message = 'Écris un vrai nombre (1 à 100) 🤔';
      });
      return;
    }

    setState(() {
      _tentatives++;
      _dernierChiffre = proposition;

      // Les conditions classiques if / else !
      if (proposition == _secret) {
        _gagne = true;
        _message = '🎉 BRAVO ! Tu as trouvé $proposition en '
            '$_tentatives tentatives !';
        // Victoire → on sauvegarde le score.
        _enregistrerScore(_tentatives);
      } else if (_tentatives >= _maxTentatives) {
        // Plus aucun essai restant → défaite
        _perdu = true;
        _message = '😞 Perdu ! Le nombre était $_secret. '
            'Tu as utilisé tes $_maxTentatives tentatives !';
      } else if (proposition < _secret) {
        _message = '⬆️ Plus grand que $proposition !';
      } else {
        _message = '⬇️ Plus petit que $proposition !';
      }
    });
  }

  /// Sauvegarde le record. Le « meilleur » score = le moins de tentatives.
  Future<void> _enregistrerScore(int tentatives) async {
    try {
      if (widget.saveScore != null) {
        // Mode test : on utilise la fonction fournie.
        await widget.saveScore!(tentatives);
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

    // Chaque joueur a UN document dans la collection « scores »,
    // identifié par son uid Firebase.
    final ref =
        FirebaseFirestore.instance.collection('scores').doc(user.uid);

    final doc = await ref.get();
    // Le record existant, si présent.
    final actuel = doc.exists
        ? (doc['tentatives'] as num?)?.toInt()
        : null;

    // On garde le MEILLEUR score (le plus petit nombre de tentatives).
    final meilleur =
        (actuel == null || tentatives < actuel) ? tentatives : actuel;

    await ref.set({
      'email': user.email ?? 'anonyme',
      'tentatives': meilleur,
      'date': FieldValue.serverTimestamp(),
    });
  }

  /// Déconnexion : retombe sur l'écran de connexion (via la Racine).
  void _deconnexion() {
    if (widget.onLogout != null) {
      widget.onLogout!();
    } else {
      FirebaseAuth.instance.signOut();
    }
  }

  /// Ouvre l'écran de classement mondial.
  void _ouvrirClassement() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const LeaderboardPage()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('🎯 Devine le nombre'),
        centerTitle: true,
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            tooltip: 'Classement mondial',
            icon: const Icon(Icons.leaderboard),
            onPressed: _ouvrirClassement,
          ),
          IconButton(
            tooltip: 'Déconnexion',
            icon: const Icon(Icons.logout),
            onPressed: _deconnexion,
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: .center,
          children: [
            // L'énoncé
            const Text(
              'Je pense à un nombre entre 1 et 100',
              style: TextStyle(fontSize: 18),
              textAlign: .center,
            ),
            const SizedBox(height: 8),
            Text(
              'Tu as $_maxTentatives tentatives maximum !',
              style: const TextStyle(fontSize: 14, color: Colors.grey),
              textAlign: .center,
            ),
            const SizedBox(height: 24),

            // Le champ de saisie du nombre
            TextField(
              controller: _controller,
              keyboardType: .number,
              enabled: !_gagne && !_perdu, // désactivé quand la partie est finie
              decoration: InputDecoration(
                labelText: 'Ta proposition',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onSubmitted: (_) => _essayer(),
            ),
            const SizedBox(height: 24),

            // Le bouton pour essayer
            FilledButton.icon(
              onPressed: _gagne || _perdu ? null : _essayer,
              icon: const Icon(Icons.send),
              label: const Text('Essayer'),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 32,
                  vertical: 16,
                ),
                backgroundColor: Colors.teal,
              ),
            ),
            const SizedBox(height: 24),

            // La zone de message (réponse du jeu)
            Container(
              width: .infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.teal.withValues(alpha: .1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                _message,
                style: const TextStyle(fontSize: 18, fontWeight: .w600),
                textAlign: .center,
              ),
            ),
            const SizedBox(height: 16),

            // Le compteur de tentatives + dernière proposition
            Text(
              'Tentatives : $_tentatives / $_maxTentatives'
              '${_dernierChiffre != null ? ' • Dernier essai : $_dernierChiffre' : ''}',
              style: const TextStyle(color: Colors.grey),
            ),

            // Le bouton « Rejouer » apparaît quand la partie est finie
            if (_gagne || _perdu) ...[
              const SizedBox(height: 24),
              FilledButton(
                onPressed: _nouvellePartie,
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.orange,
                ),
                child: const Text('🔄 Rejouer'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
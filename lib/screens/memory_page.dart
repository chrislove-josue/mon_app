import 'dart:async';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'leaderboard_page.dart';

/// ============================================================
/// LE JEU « MÉMORY »
/// ============================================================
///
/// On retourne des cartes par paires pour retrouver les jumeaux.
/// Ce mini-jeu repose sur les mêmes bases que les précédents :
///   - état de la partie avec setState
///   - listes, boucles, index
///
/// Ici on travaille beaucoup avec des List et des indexes :
///  - _premiereCarte : l'index de la première carte retournée
///  - _coups : le nombre de tentatives
/// ============================================================

/// Représente une carte du mémory.
class _Carte {
  _Carte({required this.emoji});

  final String emoji; // le symbole caché
  bool faceVisible = false; // carte retournée ?
  bool trouvee = false; // paire déjà découverte ?
}

class MemoryPage extends StatefulWidget {
  const MemoryPage({super.key, this.saveScore});

  /// Injection utilisée dans les tests (remplace Firestore).
  final Future<void> Function(int coups)? saveScore;

  @override
  State<MemoryPage> createState() => _MemoryPageState();
}

class _MemoryPageState extends State<MemoryPage> {
  // 8 paires d'emojis → 16 cartes.
  static const _symboles = [
    '🐶', '🐱', '🦊', '🐼', '🐸', '🦁', '🐵', '🐙',
  ];

  late final List<_Carte> _cartes;
  int? _premiereCarte; // index de la première carte retournée
  int _coups = 0; // nombre de tentatives
  bool _bloque = false; // on vérifie les cartes, clique désactivé

  // Phase de mémorisation : toutes les cartes sont ouvertes pendant 5 s.
  bool _memorisation = true;
  int _secondesRestantes = 5;
  Timer? _timerMemorisation;

  // Le joueur doit d'abord lancer la partie (« Commencer »).
  bool _partieDemarree = false;

  // Chrono de jeu : 2 minutes pour tout trouver.
  static const _dureeJeuSecondes = 120;
  int _tempsJeuRestant = _dureeJeuSecondes;
  Timer? _timerJeu;
  bool _tempsEcoule = false;

  _MemoryPageState() {
    _cartes = _melangerCartes();
  }

  @override
  void initState() {
    super.initState();
    // Plus de mémorisation auto : le joueur doit appuyer sur « Commencer ».
  }

  @override
  void dispose() {
    _timerMemorisation?.cancel();
    _timerJeu?.cancel();
    super.dispose();
  }

  /// Le joueur clique « Commencer » : on ouvre tout pour mémoriser (5 s)
  /// et on lance le chrono de 2 minutes.
  void _demarrer() {
    setState(() {
      _partieDemarree = true;
      _tempsEcoule = false;
      _tempsJeuRestant = _dureeJeuSecondes;
      for (final carte in _cartes) {
        carte.faceVisible = true;
      }
    });
    _demarrerCompteARebours();
    _demarrerChronoJeu();
  }

  /// Démarre le compte à rebours de mémorisation (1 tick / seconde).
  void _demarrerCompteARebours() {
    _timerMemorisation?.cancel();
    _secondesRestantes = 5;
    _timerMemorisation =
        Timer.periodic(const Duration(seconds: 1), _tickCompteARebours);
  }

  /// Démarre le chrono de jeu (2 minutes).
  void _demarrerChronoJeu() {
    _timerJeu?.cancel();
    _timerJeu = Timer.periodic(const Duration(seconds: 1), _tickChronoJeu);
  }

  /// Une seconde de jeu s'écoule… à 0, le temps est écoulé.
  void _tickChronoJeu(Timer timer) {
    if (!mounted) {
      timer.cancel();
      return;
    }
    setState(() => _tempsJeuRestant--);

    if (_tempsJeuRestant <= 0 || _gagne) {
      timer.cancel();
      if (_tempsJeuRestant <= 0) {
        setState(() {
          _tempsEcoule = true;
          _bloque = true;
        });
      }
    }
  }

  /// Une seconde s'écoule… à 0, on referme toutes les cartes.
  void _tickCompteARebours(Timer timer) {
    if (!mounted) {
      timer.cancel();
      return;
    }
    setState(() => _secondesRestantes--);

    if (_secondesRestantes <= 0) {
      timer.cancel();
      setState(() {
        _memorisation = false;
        for (final carte in _cartes) {
          carte.faceVisible = false;
        }
      });
    }
  }

  /// Crée les 16 cartes (2 de chaque symbole) puis les mélange.
  List<_Carte> _melangerCartes() {
    final cartes = <_Carte>[
      // Boucle : pour chaque symbole, on ajoute 2 cartes identiques.
      for (var i = 0; i < _symboles.length; i++)
        for (var j = 0; j < 2; j++) _Carte(emoji: _symboles[i]),
    ];

    // Mélange aléatoire (Fisher-Yates) : on échange les positions.
    cartes.shuffle(Random());
    return cartes;
  }

  void _recommencer() {
    _timerMemorisation?.cancel();
    _timerJeu?.cancel();
    setState(() {
      final nouvelle = _melangerCartes();
      // Notre liste est `final`, on l'absorbe complètement.
      _cartes
        ..clear()
        ..addAll(nouvelle);
      _premiereCarte = null;
      _coups = 0;
      _bloque = false;
      _tempsEcoule = false;
      _tempsJeuRestant = _dureeJeuSecondes;
      _partieDemarree = false; // retour à l'écran « Commencer »
      _memorisation = true;
      _secondesRestantes = 5;
    });
  }

  void _taperCarte(int position) {
    final carte = _cartes[position];

    // On ignore les clics inutiles (mémorisation, carte visible/trouvée).
    if (_bloque ||
        _memorisation ||
        _tempsEcoule ||
        carte.faceVisible ||
        carte.trouvee) {
      return;
    }

    setState(() => carte.faceVisible = true);

    if (_premiereCarte == null) {
      // Première carte de la tentative.
      _premiereCarte = position;
      return;
    }

    // Deuxième carte → on compare.
    _coups++;
    final premiere = _cartes[_premiereCarte!];
    _premiereCarte = null;

    if (premiere.emoji == carte.emoji) {
      // Paire trouvée !
      setState(() {
        premiere.trouvee = true;
        carte.trouvee = true;
      });

      // Toutes les cartes trouvées → victoire → sauvegarde du score.
      if (_gagne) {
        _enregistrerScore(_coups);
      }
      return;
    }

    // Pas une paire → on les retourne après un court délai.
    _bloque = true;
    Future.delayed(const Duration(milliseconds: 700), () {
      if (!mounted) return;
      setState(() {
        premiere.faceVisible = false;
        carte.faceVisible = false;
        _bloque = false;
      });
    });
  }

  /// La partie est gagnée quand toutes les cartes sont trouvées.
  bool get _gagne => _cartes.every((c) => c.trouvee);

  /// Sauvegarde le record. Le « meilleur » score = le moins de coups.
  Future<void> _enregistrerScore(int coups) async {
    try {
      if (widget.saveScore != null) {
        await widget.saveScore!(coups); // mode test
      } else {
        await _sauverDansFirestore(coups);
      }
    } catch (e) {
      debugPrint('Échec de la sauvegarde du score Mémory : $e');
    }
  }

  Future<void> _sauverDansFirestore(int coups) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    // Un document par joueur, dans la collection « memory_scores ».
    final ref = FirebaseFirestore.instance
        .collection('memory_scores')
        .doc(user.uid);

    final doc = await ref.get();
    final actuel = doc.exists ? (doc['coups'] as num?)?.toInt() : null;

    // On garde le MEILLEUR score (le plus petit nombre de coups).
    final meilleur = (actuel == null || coups < actuel) ? coups : actuel;

    await ref.set({
      'email': user.email ?? 'anonyme',
      'coups': meilleur,
      'date': FieldValue.serverTimestamp(),
    });
  }

  /// Ouvre le classement du Mémory.
  void _ouvrirClassement() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const LeaderboardPage(
          collection: 'memory_scores',
          titre: '🧠 Classement Mémory',
          champTri: 'coups',
          unite: 'coups',
          messageVide: 'Aucune partie de Mémory pour le moment. Joue ! 🐠',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('🐠 Mémory'),
        centerTitle: true,
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            tooltip: 'Classement Mémory',
            icon: const Icon(Icons.leaderboard),
            onPressed: _ouvrirClassement,
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: !_partieDemarree
          // ===== Écran « Commencer » : le joueur lance la partie =====
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: .center,
                  children: [
                    const Text(
                      '🧠',
                      style: TextStyle(fontSize: 72),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Prêt à jouer au Mémory ?',
                      style: TextStyle(fontSize: 22, fontWeight: .bold),
                      textAlign: .center,
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Trouve les 8 paires en moins de 2 minutes !',
                      style: TextStyle(color: Colors.grey, fontSize: 14),
                      textAlign: .center,
                    ),
                    const SizedBox(height: 24),
                    FilledButton.icon(
                      onPressed: _demarrer,
                      icon: const Icon(Icons.play_arrow, size: 28),
                      label: const Text(
                        'Commencer',
                        style: TextStyle(fontSize: 20),
                      ),
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 40,
                          vertical: 18,
                        ),
                        backgroundColor: Colors.teal,
                      ),
                    ),
                  ],
                ),
              ),
            )
          : Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Barre de statut + chrono
            Row(
              mainAxisAlignment: .spaceBetween,
              children: [
                Text(
                  'Coups : $_coups',
                  style: const TextStyle(fontSize: 16, fontWeight: .w600),
                ),
Text(
                  '⏱ ${_formatTemps(_tempsJeuRestant)}',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: .w600,
                    color: _tempsJeuRestant <= 10 ? Colors.red : Colors.teal,
                  ),
                ),
                Text(
                  'Paires : ${_cartes.where((c) => c.trouvee).length ~/ 2} / '
                  '${_symboles.length}',
                  style: const TextStyle(fontSize: 16, fontWeight: .w600),
                ),
              ],
            ),
            const SizedBox(height: 16),


            // Bandeau de mémorisation (visible pendant les 5 premières secondes).
            if (_memorisation) ...[
              Container(
                width: .infinity,
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.orange.withValues(alpha: .15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '👀 Mémorise la grille ! $_secondesRestantes s',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: .w600,
                    color: Colors.orange,
                  ),
                  textAlign: .center,
                ),
              ),
              const SizedBox(height: 12),
            ],

            // Grille de cartes (4 colonnes x 4 lignes).
            // Sur écran large (web, tablette) on limite la largeur de la
            // grille pour garder des cartes de taille raisonnable.
            Expanded(
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 400),
                  child: GridView.builder(
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 4,
                      mainAxisSpacing: 8,
                      crossAxisSpacing: 8,
                    ),
                    itemCount: _cartes.length,
                    itemBuilder: (context, i) => _carteWidget(_cartes[i], i),
                  ),
                ),
              ),
            ),

            // Message de victoire / temps écoulé + bouton rejouer
            if (_gagne) ...[
              const SizedBox(height: 12),
              Text(
                '🎉 Bravo, tout trouvé en $_coups coups !',
                style: const TextStyle(fontSize: 18, fontWeight: .bold),
              ),
              const SizedBox(height: 8),
              FilledButton.icon(
                onPressed: _recommencer,
                icon: const Icon(Icons.refresh),
                label: const Text('Rejouer'),
                style: FilledButton.styleFrom(backgroundColor: Colors.orange),
              ),
            ] else if (_tempsEcoule) ...[
              const SizedBox(height: 12),
              const Text(
                '⏰ Temps écoulé ! Réessaie de battre ton record.',
                style: TextStyle(fontSize: 18, fontWeight: .bold),
              ),
              const SizedBox(height: 8),
              FilledButton.icon(
                onPressed: _recommencer,
                icon: const Icon(Icons.refresh),
                label: const Text('Rejouer'),
                style: FilledButton.styleFrom(backgroundColor: Colors.orange),
              ),
            ],
            ],
          ),
        ),
      );
  }

  /// Formate des secondes en « m:ss » (ex. 120 → 2:00).
  String _formatTemps(int secondes) {
    final m = secondes ~/ 60;
    final s = (secondes % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  Widget _carteWidget(_Carte carte, int position) {
    return GestureDetector(
      onTap: () => _taperCarte(position),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
        decoration: BoxDecoration(
          color: carte.faceVisible || carte.trouvee
              ? Colors.teal.shade50
              : Colors.teal,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.teal, width: 2),
        ),
        child: Center(
          child: (carte.faceVisible || carte.trouvee)
              ? Text(carte.emoji, style: const TextStyle(fontSize: 32))
              : const Icon(
                  Icons.question_mark,
                  color: Colors.white,
                  size: 28,
                ),
        ),
      ),
    );
  }
}
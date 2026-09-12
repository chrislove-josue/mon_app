import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/game_provider.dart';
import '../services/admin_service.dart';
import 'admin_page.dart';
import 'classement_general_page.dart';
import 'memory_page.dart';

/// ============================================================
/// LE JEU « DEVINE LE NOMBRE » (version Provider)
/// ============================================================
///
/// GamePage ne fait que 2 choses :
///   1. créer le GameProvider (ChangeNotifier)
///   2. afficher _GameView, qui « écoute » ce provider
///
/// L'état du jeu vit dans GameProvider (providers/game_provider.dart).
/// ============================================================

class GamePage extends StatefulWidget {
  const GamePage({
    super.key,
    this.saveScore,
    this.onLogout,
    this.secretGenerator,
    this.nombreMagique,
  });

  /// Injection utilisée dans les tests.
  final Future<void> Function(int tentatives)? saveScore;
  final VoidCallback? onLogout;
  final int Function()? secretGenerator;

  /// Nombre magique global (défini par l'admin dans config/magic).
  /// Null → tirage aléatoire habituel. Le widget le met à jour en direct
  /// quand le StreamBuilder de la Racine détecte un changement.
  final int? nombreMagique;

  @override
  State<GamePage> createState() => _GamePageState();
}

class _GamePageState extends State<GamePage> {
  /// Le provider du jeu. Créé UNE fois (sinon chaque rebuild du parent
  /// relancerait la partie).
  late final GameProvider _game;

  @override
  void initState() {
    super.initState();
    _game = GameProvider(
      saveScore: widget.saveScore,
      secretGenerator: widget.secretGenerator,
      nombreMagique: widget.nombreMagique,
    )..nouvellePartie();
  }

  @override
  void didUpdateWidget(GamePage oldWidget) {
    super.didUpdateWidget(oldWidget);
    // L'admin a changé le nombre magique : on le propage au jeu en cours
    // pour que la PROCHAINE partie (bouton « Commencer ») l'utilise.
    if (oldWidget.nombreMagique != widget.nombreMagique) {
      _game.definirNombreMagique(widget.nombreMagique);
    }
  }

  @override
  void dispose() {
    _game.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // ChangeNotifierProvider.value : le provider appartient à ce State et
    // reste le même d'un build à l'autre (l'état du jeu est préservé).
    return ChangeNotifierProvider<GameProvider>.value(
      value: _game,
      child: _GameView(onLogout: widget.onLogout),
    );
  }
}

/// La partie « interface » du jeu. StatefulWidget parce qu'elle possède
/// le TextEditingController (qui doit être libéré avec dispose()).
class _GameView extends StatefulWidget {
  const _GameView({this.onLogout});

  final VoidCallback? onLogout;

  @override
  State<_GameView> createState() => _GameViewState();
}

class _GameViewState extends State<_GameView> {
  final _controller = TextEditingController();

  bool _estAdmin = false;

  /// Le chrono de la partie (1 tick par seconde).
  Timer? _chrono;

  @override
  void initState() {
    super.initState();
    _verifierAdmin();
    _demarrerChrono();
  }

  @override
  void dispose() {
    _chrono?.cancel();
    _controller.dispose();
    super.dispose();
  }

  /// Fait tourner le compte à rebours pendant toute la vie de l'écran.
  /// Le chrono s'arrête tout seul quand la partie est finie.
  void _demarrerChrono() {
    _chrono?.cancel();
    _chrono = Timer.periodic(const Duration(seconds: 1), (_) {
      final game = context.read<GameProvider>();
      game.decrementerTemps();
      // Plus besoin du chrono une fois la partie terminée.
      if (game.gagne || game.perdu) {
        _chrono?.cancel();
        _chrono = null;
      }
    });
  }

  /// Formatte des secondes en « m:ss » (ex. 60 → 1:00).
  String _formaterTemps(int secondes) {
    final m = secondes ~/ 60;
    final s = (secondes % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  /// Détecte si l'utilisateur connecté est admin (document `admins/{email}`).
  /// En mode test (pas de Firebase), l'appel échoue → pas d'icône admin.
  Future<void> _verifierAdmin() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;
      final email = user.email;
      if (email == null) return;
      final admin = await AdminService.instance.estAdmin(email);
      if (mounted) setState(() => _estAdmin = admin);
    } catch (_) {
      // Ignoré : en test l'icône admin ne s'affiche pas.
    }
  }

  /// Déconnexion : retombe sur l'écran de connexion (via la Racine).
  void _deconnexion() {
    if (widget.onLogout != null) {
      widget.onLogout!(); // mode test : callback injecté
    } else {
      FirebaseAuth.instance.signOut(); // production : déconnexion réelle
    }
  }

  /// Ouvre le jeu du Mémory.
  void _ouvrirMemory() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const MemoryPage()),
    );
  }

  /// Ouvre l'espace admin.
  void _ouvrirAdmin() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const AdminPage()),
    );
  }

  /// Ouvre l'écran des classements (jeu principal + Mémory).
  void _ouvrirClassement() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const ClassementGeneralPage()),
    );
  }

  @override
  Widget build(BuildContext context) {
    // context.watch : abonne ce widget au provider.
    // Dès que notifyListeners() est appelé, ce build() tourne à nouveau.
    final game = context.watch<GameProvider>();
    final partieFinie = game.gagne || game.perdu;

    return Scaffold(
      appBar: AppBar(
        title: const Text('🎯 Devine le nombre'),
        centerTitle: true,
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
        actions: [
          // Espace admin : visible uniquement pour les admins.
          if (_estAdmin)
            IconButton(
              tooltip: 'Espace admin',
              icon: const Icon(Icons.admin_panel_settings),
              onPressed: _ouvrirAdmin,
            ),
          IconButton(
            tooltip: 'Jouer au Mémory',
            icon: const Icon(Icons.extension),
            onPressed: _ouvrirMemory,
          ),
          IconButton(
            tooltip: 'Classements',
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
              'Tu as ${GameProvider.maxTentatives} tentatives maximum !',
              style: const TextStyle(fontSize: 14, color: Colors.grey),
              textAlign: .center,
            ),
            const SizedBox(height: 8),
            // Le compte à rebours de la partie (rouge si ≤ 10 secondes).
            Text(
              '⏱ Temps restant : ${_formaterTemps(game.tempsRestant)}',
              style: TextStyle(
                fontSize: 16,
                fontWeight: .bold,
                color:
                    game.tempsRestant <= 10 ? Colors.red : Colors.teal,
              ),
            ),
            const SizedBox(height: 24),

            // Avant le lancement par le joueur : on n'affiche PAS la saisie,
            // seulement un gros bouton « Commencer ».
            if (!game.partieEnCours && !partieFinie) ...[
              FilledButton.icon(
                onPressed: () {
                  _controller.clear();
                  game.commencerPartie();
                  _demarrerChrono();
                },
                icon: const Icon(Icons.play_arrow, size: 28),
                label: const Text('Commencer'),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 40,
                    vertical: 18,
                  ),
                  backgroundColor: Colors.teal,
                  textStyle: const TextStyle(fontSize: 20),
                ),
              ),
            ] else ...[
              // Le champ de saisie du nombre
              TextField(
                controller: _controller,
                keyboardType: .number,
                enabled: !partieFinie,
                decoration: InputDecoration(
                  labelText: 'Ta proposition',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onSubmitted: (_) => game.essayer(_controller.text),
              ),
              const SizedBox(height: 24),

              // Le bouton pour essayer
              FilledButton.icon(
                onPressed: partieFinie
                    ? null
                    : () => game.essayer(_controller.text),
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
            ],
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
                game.message,
                style: const TextStyle(fontSize: 18, fontWeight: .w600),
                textAlign: .center,
              ),
            ),
            const SizedBox(height: 16),

            // Le compteur de tentatives + dernière proposition
            Text(
              'Tentatives : ${game.tentatives} / ${GameProvider.maxTentatives}'
              '${game.dernierChiffre != null ? ' • Dernier essai : ${game.dernierChiffre}' : ''}',
              style: const TextStyle(color: Colors.grey),
            ),

            // Le bouton « Rejouer » apparaît quand la partie est finie
            if (partieFinie) ...[
              const SizedBox(height: 24),
              FilledButton(
                onPressed: () {
                  _controller.clear();
                  game.nouvellePartie(); // remet le chrono à zéro
                  _demarrerChrono();
                },
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
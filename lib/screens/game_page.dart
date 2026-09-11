import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/game_provider.dart';
import 'leaderboard_page.dart';
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

class GamePage extends StatelessWidget {
  const GamePage({
    super.key,
    this.saveScore,
    this.onLogout,
    this.secretGenerator,
  });

  /// Injection utilisée dans les tests.
  final Future<void> Function(int tentatives)? saveScore;
  final VoidCallback? onLogout;
  final int Function()? secretGenerator;

  @override
  Widget build(BuildContext context) {
    // ChangeNotifierProvider : rend le provider disponible dans tout
    // les widgets sous GamePage. « create » construit l'objet.
    return ChangeNotifierProvider(
      create: (_) => GameProvider(
        saveScore: saveScore,
        secretGenerator: secretGenerator,
      )..nouvellePartie(),
      child: _GameView(onLogout: onLogout),
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

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
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

  /// Ouvre l'écran de classement mondial.
  void _ouvrirClassement() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const LeaderboardPage()),
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
          IconButton(
            tooltip: 'Jouer au Mémory',
            icon: const Icon(Icons.extension),
            onPressed: _ouvrirMemory,
          ),
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
              'Tu as ${GameProvider.maxTentatives} tentatives maximum !',
              style: const TextStyle(fontSize: 14, color: Colors.grey),
              textAlign: .center,
            ),
            const SizedBox(height: 24),

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
              onPressed: partieFinie ? null : () => game.essayer(_controller.text),
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
                  game.nouvellePartie();
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
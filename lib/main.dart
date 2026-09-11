import 'dart:math';
import 'package:flutter/material.dart';

/// ============================================================
/// MON PREMIER JEU FLUTTER : « DEVINE LE NOMBRE »
/// ============================================================
/// Un nombre aléatoire entre 1 et 100 est choisi, tu dois le deviner !
///
/// Ce fichier couvre les bases du Dart :
///   - Variables (int, String, bool)
///   - Fonctions et paramètres
///   - Conditions (if / else)
///   - Gestion d'état avec setState
///   - Widgets (Text, TextField, Button, AppBar...)
/// ============================================================

void main() {
  // runApp() démarre l'application Flutter.
  // Elle reçoit le widget racine : MonJeu.
  runApp(const MonJeu());
}

/// MonJeu = l'application entière (ton nom, ton thème, tes couleurs).
class MonJeu extends StatelessWidget {
  const MonJeu({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Devine le nombre',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        // couleur principale de l'app
        colorScheme: .fromSeed(seedColor: Colors.teal),
      ),
      home: const PageDevine(),
    );
  }
}

/// Une page avec état : NumberPage va « se souvenir » du nombre à deviner.
class PageDevine extends StatefulWidget {
  const PageDevine({super.key});

  @override
  State<PageDevine> createState() => _PageDevineState();
}

class _PageDevineState extends State<PageDevine> {
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

  /// Choisit un nouveau nombre secret.
  void _nouvellePartie() {
    setState(() {
      _secret = Random().nextInt(100) + 1; // 1 → 100
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('🎯 Devine le nombre'),
        centerTitle: true,
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
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
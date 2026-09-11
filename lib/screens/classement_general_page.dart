import 'package:flutter/material.dart';

import 'leaderboard_page.dart';

/// ============================================================
/// CLASSEMENT GÉNÉRAL — les deux jeux sur une seule page
/// ============================================================
///
/// Affiche en une seule page le classement du jeu principal
/// (« Devine le nombre ») ET celui du Mémory.
///
/// Chaque jeu est une `ClassementSection` indépendante :
///   - 'scores'         → tri sur 'tentatives' (moins d'essais = mieux)
///   - 'memory_scores'  → tri sur 'coups' (moins de coups = mieux)
/// ============================================================

class ClassementGeneralPage extends StatelessWidget {
  const ClassementGeneralPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('🏆 Classements'),
        centerTitle: true,
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 8),
        children: const [
          ClassementSection(
            collection: 'scores',
            champTri: 'tentatives',
            unite: 'essais',
            messageVide: 'Aucune partie pour le moment. Sois le premier ! 🎯',
            titre: '🎯 Devine le nombre',
            icone: Icons.casino,
          ),
          Divider(
            height: 32,
            thickness: 1,
            indent: 16,
            endIndent: 16,
          ),
          ClassementSection(
            collection: 'memory_scores',
            champTri: 'coups',
            unite: 'coups',
            messageVide: 'Aucune partie de Mémory pour le moment. Joue ! 🐠',
            titre: '🧠 Mémory',
            icone: Icons.extension,
          ),
        ],
      ),
    );
  }
}
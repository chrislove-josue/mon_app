import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

/// ============================================================
/// CLASSEMENT (Cloud Firestore) — écran RÉUTILISABLE
/// ============================================================
///
/// Paramétré par : la collection, le titre, le champ de tri et l'unité.
///   - Jeu principal  : collection 'scores', tri sur 'tentatives', 'essais'
///   - Mémory         : collection 'memory_scores', tri sur 'coups', 'coups'
///
/// Firestore fonctionne en temps réel : si un autre joueur bat un record
/// pendant que tu regardes le classement, il se met à jour tout seul !
/// ============================================================

class LeaderboardPage extends StatelessWidget {
  const LeaderboardPage({
    super.key,
    this.collection = 'scores',
    this.titre = '🏆 Classement mondial',
    this.champTri = 'tentatives',
    this.unite = 'essais',
    this.messageVide = 'Aucun score pour le moment. Sois le premier ! 🎯',
  });

  final String collection;
  final String titre;
  final String champTri;
  final String unite;
  final String messageVide;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(titre),
        centerTitle: true,
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
      ),
      body: StreamBuilder<QuerySnapshot>(
        // Souscription en temps réel aux 10 meilleurs scores.
        stream: FirebaseFirestore.instance
            .collection(collection)
            .orderBy(champTri, descending: false)
            .limit(10)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Center(
              child: Text('Impossible de charger le classement.'),
            );
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final docs = snapshot.data!.docs;
          if (docs.isEmpty) {
            return Center(child: Text(messageVide));
          }

          // Liste du classement, une ligne par joueur.
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final data = docs[index].data() as Map<String, dynamic>;
              final email = (data['email'] as String?) ?? 'anonyme';
              final valeur = (data[champTri] as num?)?.toInt() ?? 0;
              final position = index + 1;

              return Card(
                margin: const EdgeInsets.symmetric(vertical: 6),
                child: ListTile(
                  // Médaille pour le top 3, sinon le numéro.
                  leading: _medaille(position),
                  title: Text(
                    email,
                    style: const TextStyle(fontWeight: .w600),
                    overflow: .ellipsis,
                  ),
                  trailing: Text(
                    '$valeur $unite',
                    style: TextStyle(
                      fontWeight: .bold,
                      color: Colors.teal.shade700,
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _medaille(int position) {
    final (emoji, couleur) = switch (position) {
      1 => ('🥇', Colors.amber.shade600),
      2 => ('🥈', Colors.grey.shade400),
      3 => ('🥉', Colors.brown.shade400),
      _ => ('$position', Colors.grey),
    };

    return CircleAvatar(
      backgroundColor: couleur.withValues(alpha: .15),
      child: Text(emoji, style: const TextStyle(fontSize: 18)),
    );
  }
}
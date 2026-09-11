import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

/// ============================================================
/// CLASSEMENT MONDIAL (Cloud Firestore)
/// ============================================================
///
/// Firestore fonctionne en temps réel : StreamBuilder s'abonne
/// aux données et l'écran se met à jour tout seul quand un
/// autre joueur bat son record. 
///
/// On trie par « tentatives » croissant (le plus petit = le meilleur).
/// ============================================================

class LeaderboardPage extends StatelessWidget {
  const LeaderboardPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('🏆 Classement mondial'),
        centerTitle: true,
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
      ),
      body: StreamBuilder<QuerySnapshot>(
        // Souscription en temps réel aux 10 meilleurs scores.
        stream: FirebaseFirestore.instance
            .collection('scores')
            .orderBy('tentatives', descending: false)
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
            return const Center(
              child: Text('Aucun score pour le moment. Sois le premier ! 🎯'),
            );
          }

          // Liste du classement, une ligne par joueur.
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final data = docs[index].data() as Map<String, dynamic>;
              final email = (data['email'] as String?) ?? 'anonyme';
              final tentatives = (data['tentatives'] as num?)?.toInt() ?? 0;
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
                    '$tentatives essais',
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
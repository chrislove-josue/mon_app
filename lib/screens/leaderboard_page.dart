import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

/// ============================================================
/// CLASSEMENT (Cloud Firestore) — composants RÉUTILISABLES
/// ============================================================
///
/// - `LeaderboardPage`   : un classement plein écran (UNE collection).
/// - `ClassementSection` : une « section » de classement. Permet d'afficher
///   plusieurs classements sur une même page (voir ClassementGeneralPage).
///
/// Collections :
///   - Jeu principal  : 'scores', tri sur 'tentatives', unité 'essais'
///   - Mémory         : 'memory_scores', tri sur 'coups', unité 'coups'
///
/// Firestore fonctionne en temps réel : si un autre joueur bat un record
/// pendant que tu regardes le classement, il se met à jour tout seul !
/// ============================================================

/// Une page entière dédiée à un seul classement.
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
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 8),
        children: [
          ClassementSection(
            collection: collection,
            champTri: champTri,
            unite: unite,
            messageVide: messageVide,
          ),
        ],
      ),
    );
  }
}

/// Une section indépendante : en-tête optionnel + les meilleurs scores.
/// S'utilise seule ou empilée avec d'autres dans un scrollable parent.
class ClassementSection extends StatelessWidget {
  const ClassementSection({
    super.key,
    required this.collection,
    required this.champTri,
    required this.unite,
    required this.messageVide,
    this.titre,
    this.icone,
    this.max = 10,
  });

  final String collection;
  final String champTri;
  final String unite;
  final String messageVide;

  /// Titre affiché au-dessus de la liste (optionnel).
  final String? titre;

  /// Petite icône à côté du titre (optionnelle).
  final IconData? icone;

  /// Nombre de joueurs affichés (10 par défaut).
  final int max;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (titre != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Row(
              children: [
                if (icone != null) ...[
                  Icon(icone, color: Colors.teal),
                  const SizedBox(width: 8),
                ],
                Expanded(
                  child: Text(
                    titre!,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: .bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
        StreamBuilder<QuerySnapshot>(
          // Souscription en temps réel aux `max` meilleurs scores.
          stream: FirebaseFirestore.instance
              .collection(collection)
              .orderBy(champTri, descending: false)
              .limit(max)
              .snapshots(),
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return const Padding(
                padding: EdgeInsets.all(24),
                child: Center(
                  child: Text('Impossible de charger le classement.'),
                ),
              );
            }

            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Padding(
                padding: EdgeInsets.all(24),
                child: Center(child: CircularProgressIndicator()),
              );
            }

            final docs = snapshot.data!.docs;
            if (docs.isEmpty) {
              return Padding(
                padding: const EdgeInsets.all(24),
                child: Center(child: Text(messageVide)),
              );
            }

            // Liste du classement, une ligne par joueur. `shrinkWrap` permet
            // d'empiler plusieurs sections dans la même page.
            return ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 16),
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
      ],
    );
  }
}

/// Médaille (🥇🥈🥉) pour le top 3, sinon le numéro de position.
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
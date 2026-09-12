import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../services/admin_service.dart';

/// ============================================================
/// ESPACE ADMIN
/// ============================================================
///
/// L'admin peut :
///   1. VOIR le « nombre magique » du moment et en définir un nouveau
///      (tous les joueurs devineront ce même nombre).
///   2. MODIFIER / SUPPRIMER les points des joueurs, pour le jeu
///      principal (scores) et pour le Mémory (memory_scores).
///
/// Un utilisateur n'a accès qu'à s'il a un document `admins/{uid}`.
/// ============================================================

class AdminPage extends StatefulWidget {
  const AdminPage({super.key});

  @override
  State<AdminPage> createState() => _AdminPageState();
}

class _AdminPageState extends State<AdminPage> {
  final _controllerNombre = TextEditingController();

  int? _nombreActuel;
  bool _chargementNombre = true;

  @override
  void initState() {
    super.initState();
    _chargerNombre();
  }

  @override
  void dispose() {
    _controllerNombre.dispose();
    super.dispose();
  }

  Future<void> _chargerNombre() async {
    try {
      final nombre = await AdminService.instance.chargerNombreMagique();
      if (!mounted) return;
      setState(() {
        _nombreActuel = nombre;
        _chargementNombre = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _chargementNombre = false);
      debugPrint('Admin > échec du chargement du nombre magique : $e');
    }
  }

  /// Enregistre un nouveau nombre magique (1 → 100).
  Future<void> _definirNombre(int nombre) async {
    final email = FirebaseAuth.instance.currentUser?.email ?? 'admin';

    try {
      await AdminService.instance.definirNombreMagique(nombre, email);
      if (!mounted) return;
      setState(() => _nombreActuel = nombre);
      _afficher('✅ Nombre magique défini : $nombre');
    } catch (e) {
      _afficher('❌ Impossible d\'enregistrer le nombre.');
      debugPrint('Admin > échec definirNombreMagique : $e');
    }
  }

  /// Lecture du champ de saisie → clamps 1..100 → enregistrement.
  void _soumettreNombre() {
    final valeur = int.tryParse(_controllerNombre.text);
    if (valeur == null) {
      _afficher('Écris un nombre entier (1 à 100).');
      return;
    }
    _definirNombre(valeur.clamp(1, 100).toInt());
  }

  void _afficher(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('🛡️ Espace admin'),
        centerTitle: true,
        backgroundColor: Colors.indigo.shade800,
        foregroundColor: Colors.white,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _carteNombreMagique(),
          const Divider(height: 40),
          const _SectionScores(
            titre: '🎯 Devine le nombre',
            icone: Icons.casino,
            collection: 'scores',
            champ: 'tentatives',
            sousTitre: 'Tentatives (moins = mieux)',
          ),
          const Divider(height: 40),
          const _SectionScores(
            titre: '🧠 Mémory',
            icone: Icons.extension,
            collection: 'memory_scores',
            champ: 'coups',
            sousTitre: 'Coups (moins = mieux)',
          ),
        ],
      ),
    );
  }

  /// Carte « Nombre magique » : valeur actuelle + définition d'un nouveau.
  Widget _carteNombreMagique() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.psychology, color: Colors.indigo),
                SizedBox(width: 8),
                Text(
                  'Nombre magique',
                  style: TextStyle(fontSize: 18, fontWeight: .bold),
                ),
              ],
            ),
            const SizedBox(height: 6),
            const Text(
              'Tous les joueurs devinent ce nombre.',
              style: TextStyle(color: Colors.grey, fontSize: 13),
            ),
            const SizedBox(height: 12),
            // La valeur actuelle, bien visible.
            if (_chargementNombre)
              const Center(child: CircularProgressIndicator())
            else
              Container(
                width: .infinity,
                padding: const EdgeInsets.symmetric(vertical: 16),
                decoration: BoxDecoration(
                  color: Colors.indigo.withValues(alpha: .08),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  _nombreActuel?.toString() ?? 'Aucun nombre défini',
                  style: TextStyle(
                    fontSize: 40,
                    fontWeight: .bold,
                    color: _nombreActuel == null
                        ? Colors.grey
                        : Colors.indigo.shade800,
                  ),
                  textAlign: .center,
                ),
              ),
            const SizedBox(height: 16),
            TextField(
              controller: _controllerNombre,
              keyboardType: .number,
              decoration: const InputDecoration(
                labelText: 'Nouveau nombre (1 à 100)',
                border: OutlineInputBorder(),
              ),
              onSubmitted: (_) => _soumettreNombre(),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      final aleatoire = Random().nextInt(100) + 1;
                      _controllerNombre.text = '$aleatoire';
                      _definirNombre(aleatoire);
                    },
                    icon: const Icon(Icons.casino),
                    label: const Text('🎲 Aléatoire'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: _soumettreNombre,
                    icon: const Icon(Icons.save),
                    label: const Text('💾 Définir'),
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.indigo,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// ============================================================
/// SECTION « Scores d'un jeu » : liste des joueurs, éditable.
/// ============================================================

class _SectionScores extends StatefulWidget {
  const _SectionScores({
    required this.titre,
    required this.icone,
    required this.collection,
    required this.champ,
    required this.sousTitre,
  });

  final String titre;
  final IconData icone;
  final String collection;
  final String champ;
  final String sousTitre;

  @override
  State<_SectionScores> createState() => _SectionScoresState();
}

class _SectionScoresState extends State<_SectionScores> {
  Future<void> _sauvegarder(
      String uid, String email, int nouvelleValeur) async {
    try {
      await AdminService.instance.modifierScore(
        collection: widget.collection,
        uid: uid,
        champ: widget.champ,
        valeur: nouvelleValeur,
        email: email,
      );
      if (mounted) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(
              content: Text(
                  '✅ ${widget.collection} / $email : score mis à jour')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(const SnackBar(content: Text('❌ Échec de la mise à jour.')));
      }
      debugPrint('Admin > échec modifierScore : $e');
    }
  }

  Future<void> _supprimer(String uid, String email) async {
    try {
      await AdminService.instance.supprimerScore(widget.collection, uid);
      if (mounted) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
              SnackBar(content: Text('🗑️ ${widget.collection} / $email : supprimé')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(const SnackBar(content: Text('❌ Échec de la suppression.')));
      }
      debugPrint('Admin > échec supprimerScore : $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(widget.icone, color: Colors.indigo),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                widget.titre,
                style: const TextStyle(fontSize: 18, fontWeight: .bold),
              ),
            ),
          ],
        ),
        Text(
          widget.sousTitre,
          style: const TextStyle(color: Colors.grey, fontSize: 13),
        ),
        const SizedBox(height: 8),
        StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection(widget.collection)
              .orderBy(widget.champ, descending: false)
              .limit(50)
              .snapshots(),
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return const Padding(
                padding: EdgeInsets.all(16),
                child: Center(child: Text('Impossible de charger les scores.')),
              );
            }
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Padding(
                padding: EdgeInsets.all(16),
                child: Center(child: CircularProgressIndicator()),
              );
            }

            final docs = snapshot.data!.docs;
            if (docs.isEmpty) {
              return const Padding(
                padding: EdgeInsets.all(16),
                child: Center(
                  child: Text('Aucun joueur pour le moment.'),
                ),
              );
            }

            return Column(
              children: [
                for (final doc in docs)
                  _LigneScore(
                    uid: doc.id,
                    champ: widget.champ,
                    collection: widget.collection,
                    data: doc.data() as Map<String, dynamic>,
                    onSauvegarder: _sauvegarder,
                    onSupprimer: _supprimer,
                  ),
              ],
            );
          },
        ),
      ],
    );
  }
}

/// Une ligne de score avec champ d'édition + boutons sauvegarder/supprimer.
class _LigneScore extends StatefulWidget {
  const _LigneScore({
    required this.uid,
    required this.champ,
    required this.collection,
    required this.data,
    required this.onSauvegarder,
    required this.onSupprimer,
  });

  final String uid;
  final String champ;
  final String collection;
  final Map<String, dynamic> data;
  final Future<void> Function(String uid, String email, int valeur)
      onSauvegarder;
  final Future<void> Function(String uid, String email) onSupprimer;

  @override
  State<_LigneScore> createState() => _LigneScoreState();
}

class _LigneScoreState extends State<_LigneScore> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(
      text: '${(widget.data[widget.champ] as num?)?.toInt() ?? 0}',
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  String get _email => (widget.data['email'] as String?) ?? 'anonyme';

  void _sauvegarder() {
    final valeur = int.tryParse(_controller.text);
    if (valeur == null) return;
    widget.onSauvegarder(widget.uid, _email, valeur);
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: .start,
                children: [
                  Text(
                    _email,
                    style: const TextStyle(fontWeight: .w600),
                    overflow: .ellipsis,
                  ),
                  Text(
                    widget.uid,
                    style: const TextStyle(
                      fontSize: 11,
                      color: Colors.grey,
                    ),
                    overflow: .ellipsis,
                  ),
                ],
              ),
            ),
            SizedBox(
              width: 72,
              child: TextField(
                controller: _controller,
                keyboardType: .number,
                textAlign: .center,
                decoration: const InputDecoration(
                  isDense: true,
                  border: OutlineInputBorder(),
                ),
                onSubmitted: (_) => _sauvegarder(),
              ),
            ),
            IconButton(
              tooltip: 'Sauvegarder',
              icon: const Icon(Icons.save_outlined, color: Colors.green),
              onPressed: _sauvegarder,
            ),
            IconButton(
              tooltip: 'Supprimer',
              icon: const Icon(Icons.delete_outline, color: Colors.red),
              onPressed: () => widget.onSupprimer(widget.uid, _email),
            ),
          ],
        ),
      ),
    );
  }
}
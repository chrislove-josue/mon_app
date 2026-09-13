import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// ============================================================
/// SERVICE ADMIN (Firestore)
/// ============================================================
///
/// Côté base de données, il n'y a pas de « rôle » : on EST admin si un
/// document existe dans la collection `admins/{email}` (l'ID du document
/// est L'EMAIL du compte, ce qui est simple à créer depuis la console).
/// C'est l'admin qui, le premier, y ajoute son email via la console.
///
/// Ce service regroupe tout ce que l'espace admin doit savoir faire :
///   - vérifier si un utilisateur est admin
///   - lire / modifier le « nombre magique » (config/magic)
///   - modifier / supprimer les scores d'un joueur (scores, memory_scores)
/// ============================================================

class AdminService {
  AdminService._();
  static final AdminService instance = AdminService._();

  Future<DocumentSnapshot> _doc(String collection, String id) =>
      FirebaseFirestore.instance.collection(collection).doc(id).get();

  /// L'utilisateur est-il admin ? (document `admins/{email}` existe)
  Future<bool> estAdmin(String email) async {
    final doc = await _doc('admins', email);
    return doc.exists;
  }

  /// Nombre magique actuel (config/magic), null si pas encore défini.
  Future<int?> chargerNombreMagique() async {
    final doc = await _doc('config', 'magic');
    if (!doc.exists) return null;
    final data = doc.data() as Map<String, dynamic>?;
    return (data?['nombre'] as num?)?.toInt();
  }

  /// Définit le nombre magique pour TOUS les joueurs.
  Future<void> definirNombreMagique(int nombre, String email) async {
    await FirebaseFirestore.instance.collection('config').doc('magic').set({
      'nombre': nombre,
      'choisiPar': email,
      'miseAJour': FieldValue.serverTimestamp(),
    });
  }

  /// Tire un NOUVEAU nombre magique (1 → 100, différent de l'actuel) et
  /// l'enregistre pour tous les joueurs. Appelé automatiquement dès qu'un
  /// joueur trouve le nombre en cours.
  Future<void> regenererNombreMagique() async {
    final actuel = await chargerNombreMagique();
    // On garantit un nombre DIFFÉRENT du précédent, sinon le jeu serait
    // figé sur le même nombre.
    var nouveau = Random().nextInt(100) + 1;
    if (nouveau == actuel) {
      nouveau = actuel == 100 ? 1 : (actuel ?? 1) + 1;
    }
    final email = FirebaseAuth.instance.currentUser?.email ?? 'partie';
    await definirNombreMagique(nouveau, email);
  }

  /// Modifie le score d'un joueur (champ = 'tentatives' ou 'coups').
  Future<void> modifierScore({
    required String collection,
    required String uid,
    required String champ,
    required int valeur,
    required String email,
  }) async {
    await FirebaseFirestore.instance.collection(collection).doc(uid).set({
      'email': email,
      champ: valeur,
      'date': FieldValue.serverTimestamp(),
    });
  }

  /// Supprime la ligne de score d'un joueur.
  Future<void> supprimerScore(String collection, String uid) async {
    await FirebaseFirestore.instance.collection(collection).doc(uid).delete();
  }
}
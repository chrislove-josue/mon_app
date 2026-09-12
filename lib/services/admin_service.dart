import 'package:cloud_firestore/cloud_firestore.dart';

/// ============================================================
/// SERVICE ADMIN (Firestore)
/// ============================================================
///
/// Côté base de données, il n'y a pas de « rôle » : on EST admin si un
/// document existe dans la collection `admins/{uid}`. C'est l'admin qui,
/// le premier, y ajoute son uid (console Firebase ou via le code).
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

  /// L'utilisateur est-il admin ? (un document `admins/{uid}` existe)
  Future<bool> estAdmin(String uid) async {
    final doc = await _doc('admins', uid);
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
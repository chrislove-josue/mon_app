import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import 'firebase_options.dart';
import 'screens/game_page.dart';
import 'services/admin_service.dart';
import 'services/notification_service.dart';

/// ============================================================
/// MON APP FLUTTER + FIREBASE
/// ============================================================
/// Le jeu « Devine le nombre » devient multijoueur grâce à :
///   - Firebase Auth  : connexion / inscription par email
///   - Cloud Firestore : classement mondial des meilleurs scores
///
/// Ne pas oublier : flutterfire configure (déjà fait) génère
/// lib/firebase_options.dart avec les clés de ton projet.
/// ============================================================

Future<void> main() async {
  // 1. Assure que les plugins natifs sont prêts avant toute chose.
  WidgetsFlutterBinding.ensureInitialized();

  // 2. Démarre Firebase avec la config de ta plateforme (web, android...).
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // 3. Active la persistance locale de Firestore : les données (scores,
  //    config...) sont mises en cache sur l'appareil → le jeu reste
  //    utilisable SANS connexion internet.
  try {
    FirebaseFirestore.instance.settings =
        const Settings(persistenceEnabled: true);
  } catch (_) {
    // Certains environnements n'autorisent pas les settings : on ignore.
  }

  // 4. Prépare les notifications push (permission, token, topic).
  //    Hors ligne, ces appels échouent : on les ignore avec un délai max
  //    pour ne PAS bloquer le démarrage de l'app sans internet.
  await NotificationService.instance.initialiser().timeout(
    const Duration(seconds: 8),
  ).catchError((_) {});

  // 5. Lance l'application.
  runApp(const MonJeu());
}

/// L'application entière.
class MonJeu extends StatelessWidget {
  const MonJeu({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Devine le nombre',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: .fromSeed(seedColor: Colors.teal),
        // Ripple classique au lieu de l'effet "sparkle" Material 3 :
        // 1) plus fiable sur tous les GPU Android,
        // 2) supprime la dépendance à un shader pendant les tests.
        splashFactory: InkRipple.splashFactory,
      ),
      home: const Racine(),
    );
  }
}

/// Racine : donne accès au JEU dès le lancement.
/// Firebase Auth émet l'état de connexion via authStateChanges() :
///   - personne connectée  → on joue en INVIÉTÉ (100 % local)
///   - utilisateur connecté → le jeu avec nombre magique + classements
///
/// Plus d'écran de connexion bloquant : chacun joue tout de suite.
/// Chacun peut se connecter plus tard (bouton « Se connecter » dans le jeu)
/// pour sauvegarder ses scores au classement.
class Racine extends StatelessWidget {
  const Racine({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      // Ce stream se met à jour automatiquement à chaque login/logout.
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final user = snapshot.data;

        // Pas de compte → jeu en mode invité (sans libellé « recherche
        // nombre magique » : il vient de Firestore, donc tirage aléatoire).
        if (user == null) {
          return const GamePage(guest: true);
        }

        // Connecté : on suit EN DIRECT le « nombre magique » (config/magic).
        // S'il existe, tous les joueurs devinent ce même nombre ; sinon,
        // le jeu garde son tirage aléatoire habituel. Un Stream plutôt
        // qu'un Future : dès que l'admin change le nombre, le jeu l'écoute.
        return StreamBuilder<DocumentSnapshot>(
          stream: FirebaseFirestore.instance
              .collection('config')
              .doc('magic')
              .snapshots(),
          builder: (context, magicSnapshot) {
            if (magicSnapshot.connectionState == ConnectionState.waiting) {
              return const Scaffold(
                body: Center(child: CircularProgressIndicator()),
              );
            }
            final data =
                magicSnapshot.data?.data() as Map<String, dynamic>?;
            final nombreMagique = data?['nombre'] as int?;
            return GamePage(
              nombreMagique: nombreMagique,
              // Dès qu'un joueur trouve le nombre magique, la base en tire
              // un nouveau tout seul → tous les suivants devinent un AUTRE
              // nombre.
              onNombreMagiqueTrouve: (_) =>
                  AdminService.instance.regenererNombreMagique(),
            );
          },
        );
      },
    );
  }
}
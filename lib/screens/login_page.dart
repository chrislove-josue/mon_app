import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

/// ============================================================
/// ÉCRAN DE CONNEXION / INSCRIPTION (Firebase Auth)
/// ============================================================
///
/// Dès que l'utilisateur se connecte, le StreamBuilder de la Racine
/// (main.dart) le redirige automatiquement vers le jeu.
/// ============================================================

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  // L'app peut être en mode « connexion » ou « inscription ».
  bool _modeInscription = false;

  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _chargement = false;
  String? _erreur;

  @override
  void dispose() {
    // Toujours libérer les contrôleurs quand la page est fermée.
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  /// Fire and await l'action choisie (connexion OU inscription).
  Future<void> _soumettre() async {
    // Petite validation locale.
    if (_emailController.text.trim().isEmpty ||
        _passwordController.text.isEmpty) {
      setState(() => _erreur = 'Remplis l\'email et le mot de passe.');
      return;
    }

    setState(() {
      _chargement = true;
      _erreur = null;
    });

    try {
      if (_modeInscription) {
        // Création d'un compte puis connexion automatique.
        await FirebaseAuth.instance.createUserWithEmailAndPassword(
          email: _emailController.text.trim(),
          password: _passwordController.text,
        );
      } else {
        // Connexion d'un compte existant.
        await FirebaseAuth.instance.signInWithEmailAndPassword(
          email: _emailController.text.trim(),
          password: _passwordController.text,
        );
      }
      // Succès → plus rien à faire ici : la Racine bascule vers le jeu.
    } on FirebaseAuthException catch (e) {
      // Erreurs connues de Firebase → messages clairs en français.
      setState(() => _erreur = _traduireErreur(e.code));
    } catch (_) {
      setState(() => _erreur = 'Une erreur inattendue est survenue.');
    } finally {
      if (mounted) {
        setState(() => _chargement = false);
      }
    }
  }

  String _traduireErreur(String code) {
    return switch (code) {
      'invalid-email' => 'Adresse email invalide.',
      'user-not-found' => 'Aucun compte trouvé avec cet email.',
      'wrong-password' => 'Mot de passe incorrect.',
      'weak-password' => 'Mot de passe trop faible (6 caractères minimum).',
      'email-already-in-use' => 'Un compte existe déjà avec cet email.',
      'too-many-requests' => 'Trop de tentatives. Réessaie plus tard.',
      'network-request-failed' => 'Problème de connexion internet.',
      'invalid-credential' => 'Email ou mot de passe incorrect.',
      _ => 'Erreur : $code',
    };
  }

  /// Lance directement le téléchargement de l'APK (aucune redirection).
  Future<void> _telechargerApk() async {
    // Lien "raw" de GitHub : le navigateur télécharge le fichier
    // immédiatement au lieu d'afficher la page du dépôt.
    final uri = Uri.parse(
        'https://raw.githubusercontent.com/chrislove-josue/mon_app/main/apk/devine-le-nombre.apk');
    try {
      await launchUrl(uri);
    } catch (e) {
      debugPrint('Échec du téléchargement APK : $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    const largeurMax = 420.0;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Connexion'),
        centerTitle: true,
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: largeurMax),
            child: Column(
              mainAxisAlignment: .center,
              crossAxisAlignment: .stretch,
              children: [
                const Icon(Icons.emoji_events, size: 72, color: Colors.teal),
                const SizedBox(height: 12),
                Text(
                  '🎯 Devine le nombre',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: .bold,
                    color: Colors.teal.shade800,
                  ),
                  textAlign: .center,
                ),
                const SizedBox(height: 8),
                Text(
                  _modeInscription
                      ? 'Crée ton compte pour jouer'
                      : 'Connecte-toi pour jouer',
                  textAlign: .center,
                  style: const TextStyle(color: Colors.grey),
                ),
                const SizedBox(height: 32),

                // Champ email
                TextField(
                  controller: _emailController,
                  keyboardType: .emailAddress,
                  autocorrect: false,
                  decoration: InputDecoration(
                    labelText: 'Email',
                    hintText: 'toi@exemple.com',
                    prefixIcon: const Icon(Icons.email),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Champ mot de passe
                TextField(
                  controller: _passwordController,
                  obscureText: true,
                  onSubmitted: (_) => _soumettre(),
                  decoration: InputDecoration(
                    labelText: 'Mot de passe',
                    prefixIcon: const Icon(Icons.lock),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),

                // Zone d'erreur
                if (_erreur != null) ...[
                  const SizedBox(height: 16),
                  Text(
                    _erreur!,
                    style: const TextStyle(color: Colors.red),
                    textAlign: .center,
                  ),
                ],

                const SizedBox(height: 24),

                // Bouton principal (connexion ou inscription)
                FilledButton.icon(
                  onPressed: _chargement ? null : _soumettre,
                  icon: _chargement
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Icon(
                          _modeInscription
                              ? Icons.person_add
                              : Icons.login,
                        ),
                  label: Text(_modeInscription
                      ? 'Créer mon compte'
                      : 'Se connecter'),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    backgroundColor: Colors.teal,
                  ),
                ),

                const SizedBox(height: 16),

                // Lien pour basculer connexion / inscription
                TextButton(
                  onPressed: _chargement
                      ? null
                      : () {
                          setState(() {
                            _modeInscription = !_modeInscription;
                            _erreur = null;
                          });
                        },
                  child: Text(
                    _modeInscription
                        ? 'Déjà un compte ? Se connecter'
                        : 'Pas de compte ? Créer un compte',
                    style: const TextStyle(color: Colors.teal),
                  ),
                ),

                // Zone de téléchargement de l'APK Android (visible seulement
                // sur le web — c'est sur un navigateur qu'on veut l'APK !).
                if (kIsWeb) ...[
                  const SizedBox(height: 32),
                  const Divider(),
                  const SizedBox(height: 16),
                  OutlinedButton.icon(
                    onPressed: _chargement ? null : _telechargerApk,
                    icon: const Icon(Icons.android),
                    label: const Text('Télécharger l\'APK Android'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.teal,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      side: const BorderSide(color: Colors.teal),
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Installe l\'app sur ton téléphone Android',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                    textAlign: .center,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
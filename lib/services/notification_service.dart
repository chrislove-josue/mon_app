import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

/// ============================================================
/// SERVICE DE NOTIFICATIONS (Firebase Cloud Messaging)
/// ============================================================
///
/// Cette classe prépare l'app à RECEVOIR des notifications push :
///   1. demander la permission à l'utilisateur (mobile)
///   2. récupérer le TOKEN unique de cet appareil
///   3. s'abonner à un « topic » (thème) pour recevoir les messages
///
/// Pour ENVOYER réellement un message, deux options :
///   - test manuel : console Firebase → Cloud Messaging → Nouveau message
///   - automatique : Cloud Functions (code serveur) → étape avancée
///
/// ⚠️ Limitations :
///   - web : nécessite une clé VAPID et un service worker
///   - Android : nécessite un téléphone/émulateur + google-services.json
/// ============================================================

class NotificationService {
  // Singleton : un seul service pour toute l'app.
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  FirebaseMessaging get _messaging => FirebaseMessaging.instance;

  /// Appelé une fois au démarrage de l'app (dans main()).
  Future<void> initialiser() async {
    // 1. Permission (uniquement nécessaire sur mobile).
    if (!kIsWeb) {
      final settings = await _messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );
      debugPrint('NotificationService > permission: '
          '${settings.authorizationStatus}');
    }

    // 2. Récupère le token unique de cet appareil/app.
    final token = await _messaging.getToken(vapidKey: _vapidKey);
    debugPrint('NotificationService > token: $token');

    // 3. S'abonne au topic « nouveautes ».
    // Un message envoyé à ce thème arrive sur TOUS les appareils abonnés.
    if (token != null) {
      await _messaging.subscribeToTopic('nouveautes');
      debugPrint('NotificationService > abonné au topic "nouveautes"');
    }
  }
}

/// Clé VAPID (Web Push) du projet Firebase.
/// Console Firebase → Cloud Messaging → paramètres → Clés Web Push.
const _vapidKey =
    'BPEOcC_2uz-_796H-9M6K7646GhDVI4QSnDEIkDx1aHrP9YKTem7XMdw6Xp9MA8T5OW39AEq8bUZlJ-QEzNUKIw';
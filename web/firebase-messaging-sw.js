// ============================================================
// SERVICE WORKER des notifications web (Firebase Cloud Messaging)
// ============================================================
// Ce fichier est chargé par le plugin firebase_messaging (Flutter)
// pour les messages reçus alors que le site est en ARRIÈRE-PLAN
// (onglet fermé/en arrière). Il reçoit le push et affiche une
// notification système, même si l'app n'est pas ouverte.
// ============================================================

importScripts('https://www.gstatic.com/firebasejs/10.12.2/firebase-app-compat.js');
importScripts('https://www.gstatic.com/firebasejs/10.12.2/firebase-messaging-compat.js');

firebase.initializeApp({
  apiKey: 'AIzaSyAbLnmevoAP1nIjWm_Wm-tDOf8Q47RmAHY',
  authDomain: 'club-1778796717158.firebaseapp.com',
  projectId: 'club-1778796717158',
  storageBucket: 'club-1778796717158.firebasestorage.app',
  messagingSenderId: '1027456897573',
  appId: '1:1027456897573:web:34c02a6ea5ce71f74365cc',
});

const messaging = firebase.messaging();

// Message reçu en arrière-plan : on l'affiche comme notification.
messaging.onBackgroundMessage((payload) => {
  console.log('[firebase-messaging-sw.js] Message en arrière-plan :', payload);

  const notificationTitle = payload.notification?.title || 'Nouveau message';
  const notificationOptions = {
    body: payload.notification?.body || '',
    icon: payload.notification?.icon || '/icons/Icon-192.png',
    badge: '/icons/Icon-192.png',
  };

  return self.registration.showNotification(notificationTitle, notificationOptions);
});
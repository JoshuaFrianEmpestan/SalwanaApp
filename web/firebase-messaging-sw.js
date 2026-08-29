// Background push handler for web (§12). The Flutter firebase_messaging
// plugin auto-registers this exact file at the site root, so the name and
// location matter — don't rename or move it.
//
// IMPORTANT: keep the config below in sync with
// lib/firebase_options.dart (DefaultFirebaseOptions.web) — running
// `flutterfire configure` updates the Dart file automatically but does
// NOT touch this one, so update it by hand after switching to a real
// Firebase project.
importScripts('https://www.gstatic.com/firebasejs/10.12.2/firebase-app-compat.js');
importScripts('https://www.gstatic.com/firebasejs/10.12.2/firebase-messaging-compat.js');

firebase.initializeApp({
  apiKey: 'demo-api-key',
  appId: '1:1234567890:web:abcdef1234567890abcdef',
  messagingSenderId: '1234567890',
  projectId: 'demo-salwana',
  authDomain: 'demo-salwana.firebaseapp.com',
  storageBucket: 'demo-salwana.appspot.com',
});

const messaging = firebase.messaging();

messaging.onBackgroundMessage((payload) => {
  const title = payload.notification?.title ?? 'Salwana';
  const body = payload.notification?.body ?? '';
  self.registration.showNotification(title, { body, icon: '/icons/Icon-192.png' });
});

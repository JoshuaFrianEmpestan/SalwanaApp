# Salwana

Inventory management, merchant finance tracking, product reservation, and
online marketplace app for small/medium merchants — built with Flutter
(client) and Firebase (cloud backend: Auth, Firestore, Storage, Cloud
Functions, Cloud Messaging).

Four roles: **Consumer**, **Merchant**, **Supplier**, **Administrator** —
each with their own dashboard, navigation, and permissions.

## Status

Being built module by module (see the build order below). Screens not yet
implemented show an honest "under construction" state rather than fake
data — check a screen's empty state for which module it belongs to.

Completed so far: authentication & role-based routing, the full data
model, Firestore/Storage security rules, and the Cloud Functions project
scaffold.

## One-time project setup

1. **Install tooling** (not included in this environment):
   - [Flutter SDK](https://docs.flutter.dev/get-started/install) (3.x, Dart ^3.3.0)
   - [Node.js 20](https://nodejs.org) (for Cloud Functions)
   - Firebase CLI: `npm install -g firebase-tools`
   - FlutterFire CLI: `dart pub global activate flutterfire_cli`

2. **Create a Firebase project** at https://console.firebase.google.com,
   then enable:
   - Authentication → Email/Password sign-in
   - Firestore Database (start in production mode — rules are already written)
   - Storage
   - Cloud Functions (requires the Blaze pay-as-you-go plan)
   - Cloud Messaging (for push notifications)

3. **Wire the Flutter app to your project**:
   ```
   firebase login
   flutterfire configure
   ```
   This overwrites the placeholder `lib/firebase_options.dart` with your
   real project keys.

4. **Install dependencies**:
   ```
   flutter pub get
   cd functions && npm install && cd ..
   ```

5. **Deploy security rules and functions**:
   ```
   firebase deploy --only firestore:rules,storage:rules,functions
   ```

6. **Run the app**:
   ```
   flutter run
   ```

## Payments

GCash and Maya are wired up as **simulated payment flows** (§6 of the
spec) — no live payment credentials are required or stored. Cash on
Delivery is a real order-status path. Swapping in real GCash/Maya
sandbox APIs later only touches the payment Cloud Function, not the UI.

## Architecture

- `lib/core` — theme, shared widgets, router, Riverpod providers, utils
- `lib/models` — one file per Firestore entity (mirrors `firestore.rules`)
- `lib/features/{auth,consumer,merchant,supplier,admin}` — one folder per
  role/module, each with `data/` (repositories) and `presentation/` (screens)
- `functions/src` — Cloud Functions, grouped by module
- `firestore.rules`, `storage.rules`, `firestore.indexes.json` — backend
  security & indexing, source of truth for the schema alongside `lib/models`

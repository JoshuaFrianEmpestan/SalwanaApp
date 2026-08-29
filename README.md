# Salwana

Inventory management, merchant finance tracking, product reservation, and
online marketplace app for small/medium merchants — built with Flutter
(client) and Firebase (cloud backend: Auth, Firestore, Storage, Cloud
Functions, Cloud Messaging).

Four roles: **Consumer**, **Merchant**, **Supplier**, **Administrator** —
each with their own dashboard, navigation, and permissions.

## Status

Feature-complete: all 16 build-order modules (auth & RBAC, catalog &
inventory, suppliers & restocking, orders, reservations, payments, reviews,
consumer discovery, merchant finance, notifications, dashboards &
analytics, subscriptions, reports, admin panel) plus barcode/QR scanning
are implemented end-to-end against real Cloud Functions and Firestore —
no static/placeholder screens remain. `flutter analyze` and the Cloud
Functions TypeScript build are both clean.

## Responsive & adaptive UI

- **Layout** — grids (`lib/core/utils/breakpoints.dart`) compute their
  column count from available width via `LayoutBuilder` (2 columns on
  phones, 3 on tablets ≥600px, 4 on desktop ≥1024px) instead of a fixed
  count.
- **Navigation** — `RoleScaffold` (`lib/core/widgets/role_scaffold.dart`)
  switches between a bottom navigation bar below the tablet breakpoint and
  a side `NavigationRail` (extended with labels at desktop width) above
  it, per role.
- **Forms** — every form screen is wrapped in `ResponsiveFormBody`
  (`lib/core/widgets/responsive_form_body.dart`), which caps content at a
  readable width and centers it on wide screens instead of stretching a
  single-column form edge to edge.
- **Orientation** — since layout is width-driven rather than
  device-orientation-driven, screens reflow correctly on rotation with no
  special-casing; verify by resizing the browser window or using Chrome
  DevTools' device toolbar in rotated mode.

## Offline support & polish

- Firestore persistence is enabled (`lib/main.dart`) so cached reads and
  queued writes keep the app usable when connectivity drops; on web this
  is IndexedDB-backed and best-effort (disabled automatically if the
  browser blocks it, e.g. multiple tabs or private mode).
- An app-wide offline banner (`lib/core/widgets/offline_banner.dart`,
  via `connectivity_plus`) surfaces that state to the user instead of
  leaving stale data unexplained.
- Real animation: shared-element `Hero` transitions between product cards
  and their detail screens, an `AnimatedSwitcher` on cart quantity
  changes, and an animated offline-banner reveal — on top of Flutter's
  default animated route transitions.
- Accessibility: icon-only buttons carry `tooltip`s, which Flutter also
  exposes as the screen-reader semantic label.

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

## Local development without a real Firebase project

The whole app also runs against the Firebase Local Emulator Suite (Auth,
Firestore, Storage, Functions) with a fake `demo-salwana` project — no
real Firebase project or credentials required:

```
firebase emulators:start
flutter run --dart-define=USE_FIREBASE_EMULATOR=true
```

On Windows, the emulator connection code in `lib/main.dart` deliberately
uses the literal `127.0.0.1` rather than `localhost`, since `localhost`
can resolve to the IPv6 loopback first, which the emulators never answer
on — that mismatch hangs the app on the splash screen with no error.

## QA

- `flutter analyze` — static analysis, must report no issues.
- `cd functions && npm run build` — Cloud Functions TypeScript build, must
  compile with no errors.
- Manual cross-size QA: resize the browser window (or use Chrome DevTools'
  device toolbar) across phone / tablet / desktop widths and both
  orientations to confirm grids, navigation, and forms adapt as described
  above. No automated device farm is wired up.

## Demo-ready build

```
flutter build web --dart-define=USE_FIREBASE_EMULATOR=true
```

Serve `build/web` with any static file server (e.g. `dart pub global
activate dhttpd && dhttpd --path build/web`) for a build that isn't tied
to a `flutter run` debug session. Drop `--dart-define` (and point
`firebase_options.dart` at a real project via `flutterfire configure`) for
a production build.

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

## Known gaps

Not built, and out of scope unless requested: automated tests, a CI
pipeline, custom app icons, dark mode, in-app legal pages (Privacy
Policy / Terms of Service), and account deletion / data export.

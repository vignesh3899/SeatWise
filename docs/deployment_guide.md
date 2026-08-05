# Deployment guide

## Prerequisites

- Firebase CLI (`npm i -g firebase-tools`) and `firebase login`.
- A Firebase project on the **Blaze** plan (required to deploy Cloud Functions).
- Node 20 for the functions.

## 1. Select your project

```bash
firebase use --add        # pick your project, give it an alias like "default"
```

## 2. Firestore rules & indexes

```bash
firebase deploy --only firestore:rules,firestore:indexes
```

## 3. Storage rules (optional)

```bash
firebase deploy --only storage
```

## 4. Cloud Functions

### Configure secrets (never commit keys)

```bash
firebase functions:secrets:set OPEN_ROUTE_API_KEY
firebase functions:secrets:set OPEN_WEATHER_API_KEY
```

### Build & deploy

```bash
cd functions
npm install
npm run build
cd ..
firebase deploy --only functions
```

The callable `recommendSeat` (region `us-central1`) requires an authenticated
caller and returns a recommendation identical in shape to the on‑device engine.

### Enable the cloud engine in the app

Set in `.env`:

```dotenv
USE_CLOUD_ENGINE=true
```

When on, the app calls `recommendSeat` and automatically falls back to the local
engine if the function is unreachable.

## 5. Local emulation

```bash
# functions/.env should contain the two API keys for local runs
cd functions && npm run build
firebase emulators:start --only functions,firestore,auth
```

Point the app at the emulators during development by adding, in `main.dart`
(dev only), calls such as `FirebaseFunctions.instance.useFunctionsEmulator(
'localhost', 5001)` and the matching Firestore/Auth emulator hooks. Keep these
behind a debug flag.

## 6. Build the app for release

### Android

```bash
flutter build apk --release        # or: flutter build appbundle --release
```

### iOS (macOS only)

```bash
flutter build ios --release        # then archive/upload via Xcode
```

### Web

```bash
flutter build web --release
firebase deploy --only hosting     # if you configure Firebase Hosting
```

## Troubleshooting

- **`401 Unauthorized` from OpenRouteService** → the `OPEN_ROUTE_API_KEY` is
  missing/incorrect in `.env` (app) or secrets (functions).
- **Weather is blank** → OpenWeather keys can take a while to activate; the app
  degrades gracefully and still recommends a side without weather.
- **Functions deploy fails on Spark plan** → upgrade to Blaze, or just use the
  on‑device engine (`USE_CLOUD_ENGINE=false`).
- **`firebase_options.dart` placeholder values** → run `flutterfire configure`.

# Firebase setup guide

SeatWise uses Firebase Authentication, Cloud Firestore, Cloud Functions, Storage,
Analytics and Crashlytics.

## 1. Create the project

1. Open the [Firebase console](https://console.firebase.google.com/) → **Add
   project**.
2. Name it (e.g. `seatwise`), accept defaults, and create it.

## 2. Connect the Flutter app with FlutterFire

```bash
dart pub global activate flutterfire_cli
cd seatwise
flutterfire configure
```

Select your Firebase project and the platforms you want (Android/iOS/Web). This
generates **`lib/firebase_options.dart`** (overwriting the placeholder) and adds
the platform config files (`google-services.json`, `GoogleService-Info.plist`).

## 3. Authentication

- **Build → Authentication → Get started**.
- Enable **Email/Password**.

## 4. Cloud Firestore

- **Build → Firestore Database → Create database → Production mode.**
- Pick a location close to your users.
- Deploy rules and indexes from the repo:

```bash
firebase deploy --only firestore:rules,firestore:indexes
```

### Data model

| Collection | Document shape (key fields) |
|-----------|------------------------------|
| `users`    | `email`, `displayName`, `preferShade`, `createdAt` |
| `journeys` | `userId`, `origin`, `destination`, `recommendedSide`, `headline`, `etaSeconds`, `recommendation`, `createdAt` |
| `feedback` | `userId`, `journeyId`, `wasHelpful`, `actualSide`, `rating`, `comment`, `createdAt` |

Security rules (`firestore.rules`) ensure a user can only read/write their own
documents.

## 5. Storage (optional — profile avatars)

- **Build → Storage → Get started.**
- Deploy the rules:

```bash
firebase deploy --only storage
```

## 6. Crashlytics & Analytics

Both are wired up in `main.dart`. Analytics starts collecting automatically in
release builds. For Crashlytics on Android, ensure the
`com.google.firebase.crashlytics` Gradle plugin is applied (added by
`flutterfire configure` / the FlutterFire docs). Uncaught errors are reported in
release builds only.

## 7. Cloud Functions

See `docs/deployment_guide.md`.

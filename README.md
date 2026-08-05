# SeatWise 🚌🌤️

**SeatWise recommends whether you should sit on the LEFT or RIGHT side of a
vehicle (buses first)** — based on sun/shade prediction, scenic views, nearby
highly‑rated attractions, weather along the journey, an estimated crowd level,
ETA, and a clear explanation of *why*.

It is a production‑oriented **Flutter + Firebase** application built with clean
architecture, Riverpod, and a deterministic recommendation engine that runs both
**on‑device** (offline‑aware) and **in the cloud** (Firebase Cloud Functions).

Everything uses **free APIs only**: OpenRouteService, OpenWeather, OpenStreetMap
(Nominatim + Overpass), and a local SunCalc port.

---

## Table of contents

1. [How it works](#how-it-works)
2. [Architecture](#architecture)
3. [Project structure](#project-structure)
4. [Prerequisites & tooling](#prerequisites--tooling)
   - [1. Install Flutter](#1-install-flutter)
   - [2. Install Android Studio](#2-install-android-studio)
   - [3. Install VS Code](#3-install-vs-code)
   - [4. Install the Flutter extension](#4-install-the-flutter-extension)
   - [5. Install the Firebase CLI](#5-install-the-firebase-cli)
5. [Firebase setup](#firebase-setup)
   - [6. Create a Firebase project](#6-create-a-firebase-project)
   - [7. Firestore setup](#7-firestore-setup)
   - [8. Authentication setup](#8-authentication-setup)
   - [9. Cloud Functions deployment](#9-cloud-functions-deployment)
6. [10. Configure environment variables (.env)](#10-configure-environment-variables-env)
7. [11. `flutter pub get`](#11-flutter-pub-get)
8. [12. `flutter run`](#12-flutter-run)
9. [13. App workflow](#13-app-workflow)
10. [Testing](#testing)
11. [Free API notes & limits](#free-api-notes--limits)
12. [About the Ponytail reference](#about-the-ponytail-reference)

---

## How it works

For a given origin, destination and departure time the engine:

1. Fetches a driving route from **OpenRouteService** (full polyline + ETA).
2. Samples the polyline into ~2 km **segments**, each with a travel heading and
   an estimated clock time (derived from the route's average speed).
3. For each segment it computes the **sun position** (a dependency‑free SunCalc
   port) and decides which side of the vehicle the sun falls on, weighted by how
   perpendicular and how strong the sun is, and by sky **clearness** from
   **OpenWeather**.
4. It finds scenic **attractions** near the route with **OpenStreetMap Overpass**
   and assigns each to the left or right of travel.
5. It blends three 0–100 sub‑scores per side — **comfort** (shade), **scenery**,
   and **weather** — into a final score, picks the better side (or "either" when
   close), and writes a plain‑English explanation.

The exact same algorithm is implemented twice — in Dart (`lib/engine/`) and in
TypeScript (`functions/src/engines/`) — so the app can call the Cloud Function or
fall back to the on‑device engine transparently.

## Architecture

```
UI (screens/widgets)
      │  watches
Providers / Controllers (Riverpod)
      │  call
Repositories  ── translate errors into typed Failures, return Result<T>
      │  use
Services (HTTP clients)      Engine (pure, deterministic)
      │                          │
Free APIs (ORS/OpenWeather/OSM)  SunCalc + scoring
```

- **Clean architecture + repository pattern**: the UI never touches Firebase or
  `http` directly.
- **`Result<T>` / `Failure`**: explicit, exhaustively‑switched error handling.
- **Riverpod**: dependency injection and state, no service locators or globals.
- **Material 3** with light/dark theming from a single seed colour.

## Project structure

```
seatwise/
├── lib/
│   ├── config/        env, theme
│   ├── core/          Result, Failure, exceptions, constants, geo math
│   ├── models/        immutable domain models (+ JSON)
│   ├── services/      OpenRouteService, OpenWeather, Nominatim, Overpass, …
│   ├── repositories/  auth, journeys, feedback, places, recommendation
│   ├── engine/        SunCalculator, RouteSampler, SeatEngine (scoring)
│   ├── providers/     Riverpod providers & controllers
│   ├── screens/       auth, home, planner, recommendation, weather, scenic,
│   │                  map, history, feedback, profile
│   ├── widgets/       reusable UI (seat card, score bars, tiles, …)
│   ├── app.dart       MaterialApp + auth gate
│   └── main.dart      bootstrap (Firebase, Crashlytics, dotenv)
├── functions/         Cloud Functions (TypeScript) — server-side engine
├── test/              unit + widget tests
├── integration_test/  primary journey flow
├── firebase.json, firestore.rules, firestore.indexes.json, storage.rules
├── docs/              detailed setup & deployment guides
└── .env.example
```

---

## Prerequisites & tooling

You need Flutter, an editor, and the Firebase CLI. The steps below are the quick
version; see `docs/vscode_setup.md` for a fuller walkthrough with screenshots‑
worthy detail.

### 1. Install Flutter

Install the latest stable Flutter SDK from
<https://docs.flutter.dev/get-started/install>.

```bash
# macOS/Linux example (or use the official installer for your OS)
git clone https://github.com/flutter/flutter.git -b stable ~/flutter
export PATH="$PATH:$HOME/flutter/bin"   # add to your shell profile
flutter --version
flutter doctor                          # follow any prompts it prints
```

`flutter doctor` should eventually show all green checks for the platforms you
intend to target (Android, and iOS/macOS if on a Mac).

### 2. Install Android Studio

Install Android Studio from <https://developer.android.com/studio>. On first
launch, use the setup wizard to install:

- the **Android SDK**,
- the **Android SDK Command‑line Tools**, and
- an **Android Virtual Device (AVD)** (an emulator) or enable USB debugging on a
  physical device.

Then accept the licences:

```bash
flutter doctor --android-licenses
```

### 3. Install VS Code

Install Visual Studio Code from <https://code.visualstudio.com/>. (You can use
Android Studio/IntelliJ instead — VS Code is used here as the primary example.)

### 4. Install the Flutter extension

In VS Code open **Extensions** (`Ctrl/Cmd+Shift+X`) and install the **Flutter**
extension (it pulls in the **Dart** extension automatically). This gives you run/
debug, hot reload, and the command palette entries used below.

### 5. Install the Firebase CLI

```bash
npm install -g firebase-tools
firebase login
```

You will also use **FlutterFire** to generate platform config:

```bash
dart pub global activate flutterfire_cli
```

---

## Firebase setup

### 6. Create a Firebase project

1. Go to the [Firebase console](https://console.firebase.google.com/) and click
   **Add project**. Give it a name (e.g. `seatwise`) and finish the wizard.
2. In the project, add the apps you plan to run (Android / iOS / Web) — or let
   FlutterFire do it for you in one step:

```bash
cd seatwise
flutterfire configure
```

`flutterfire configure` will create/overwrite **`lib/firebase_options.dart`** with
your real (non‑secret) client configuration. The repo ships a clearly‑marked
placeholder so it compiles before you run this.

### 7. Firestore setup

1. In the console, open **Build → Firestore Database → Create database** and start
   in **production mode**.
2. Deploy the security rules and indexes included in this repo:

```bash
firebase deploy --only firestore:rules,firestore:indexes
```

The app uses three collections: `users`, `journeys`, and `feedback`. Rules
restrict every document to its owner (see `firestore.rules`).

### 8. Authentication setup

1. Open **Build → Authentication → Get started**.
2. Enable the **Email/Password** sign‑in provider.

That's all the app needs — registration, login and password‑reset all work
against Email/Password.

### 9. Cloud Functions deployment

The server‑side engine lives in `functions/`. It exposes one callable,
`recommendSeat`, that mirrors the on‑device engine.

```bash
cd functions
npm install
npm run build          # compiles TypeScript -> lib/

# Store the API keys as Firebase secrets (never in source):
firebase functions:secrets:set OPEN_ROUTE_API_KEY
firebase functions:secrets:set OPEN_WEATHER_API_KEY

# Deploy:
firebase deploy --only functions
```

> Deploying Cloud Functions requires the Firebase **Blaze (pay‑as‑you‑go)** plan.
> The app works fully **without** deploying functions — it simply uses the
> on‑device engine. Set `USE_CLOUD_ENGINE=true` in `.env` to prefer the cloud.

See `docs/deployment_guide.md` for local emulation and troubleshooting.

---

## 10. Configure environment variables (.env)

**Never hardcode API keys.** Copy the example and fill in your keys:

```bash
cp .env.example .env
```

```dotenv
OPEN_ROUTE_API_KEY=your_openrouteservice_key
OPEN_WEATHER_API_KEY=your_openweather_key
FIREBASE_PROJECT_ID=your_project_id
FIREBASE_API_KEY=your_web_api_key
USE_CLOUD_ENGINE=false
```

For the Cloud Functions, also:

```bash
cp functions/.env.example functions/.env   # for local emulation only
```

How to obtain each free key is documented in `docs/api_setup.md`.

## 11. `flutter pub get`

```bash
flutter pub get
```

## 12. `flutter run`

Start an emulator (or plug in a device) and run:

```bash
flutter run
```

Hot‑reload with `r`, hot‑restart with `R`. To build a release APK:

```bash
flutter build apk --release
```

## 13. App workflow

1. **Sign up / sign in** with email and password.
2. On **Home**, tap **Plan a journey**.
3. In the **planner**, search and pick a **From** and **To** (OpenStreetMap
   geocoding), choose a **departure time**, and set your **shade preference**.
4. Tap **Get seat recommendation**. SeatWise fetches the route, sun, weather and
   attractions and shows:
   - the recommended **LEFT / RIGHT** side with a confidence chip and a bus
     diagram,
   - a **"Why this side"** explanation,
   - a **score breakdown** (comfort / scenery / weather, left vs right),
   - a **weather timeline** along the route,
   - **scenic highlights** grouped by side, and
   - the **route on a map** (OpenStreetMap tiles).
5. The journey is saved to **History** automatically; open any past journey to
   review it again.
6. Leave **feedback** ("was this helpful?") to help improve future tuning.
7. Manage your **profile**: shade preference, **dark mode**, and sign‑out.

---

## Testing

```bash
flutter test                                   # unit + widget tests
flutter test integration_test/app_test.dart    # primary journey flow
cd functions && npm run build                  # type-checks the cloud engine
```

See `docs/testing_guide.md` for details and coverage.

## Free API notes & limits

- **OpenRouteService** – free key, generous daily quota; used for directions.
- **OpenWeather** – free "current weather" tier; sampled at a few route points.
- **Nominatim** (OSM) – geocoding; **max ~1 request/second**, requires a
  descriptive User‑Agent (both handled in code).
- **Overpass** (OSM) – POI lookup; shared public instance, be gentle.
- **SunCalc** – implemented locally, no network, no key.

All OSM usage in this app follows the OSMF usage policies (identifying
User‑Agent, debounced search, bounded queries).

## About the Ponytail reference

The original brief asked to use *"Ponytail"* as a planning/milestone framework.
The repository at `github.com/DietrichGebert/ponytail` is real, but it is **not**
a milestone/task tracker — it is an AI‑agent ruleset that pushes for *minimal
code* ("the best code is the code you never wrote"). It therefore can't "track
milestones." This project was instead built with an explicit, structured task
plan (see the commit/section breakdown), while honoring Ponytail's actual spirit:
pragmatic clean architecture with no dead scaffolding or over‑engineering.

---

Made with Flutter + Firebase. Contributions and feedback welcome.

## New: icon, splash screen, and liquid-glass 3D UI

This build adds:
- **App icon** — `assets/icon/icon.png` (+ `icon_foreground.png` for Android adaptive icons), a seat + sun mark on the brand teal/amber gradient. Config for `flutter_launcher_icons` is in `pubspec.yaml`.
- **Splash screen** — an in-app animated splash (`lib/screens/splash/splash_screen.dart`) shown on launch, plus `flutter_native_splash` config for a matching native cold-start splash.
- **Liquid-glass, 3D-interactive UI** — two new reusable widgets:
  - `lib/widgets/glass_container.dart` — frosted, blurred "glass" panel.
  - `lib/widgets/tilt_card.dart` — drag-to-tilt 3D card with a moving light sheen (`TiltCard`), plus a gentle bob animation (`FloatingWidget`).
  These are wired into the home screen's plan card and recent-journey cards, with emoji accents throughout.

### One-time setup to generate the native icon/splash files

This project currently ships **without** `android/` and `ios/` platform folders. Before the icon and native splash can be generated, run:

```bash
flutter create .          # adds android/ and ios/ folders for this project
flutter pub get
dart run flutter_launcher_icons
dart run flutter_native_splash:create
```

`flutter create .` is safe to run on an existing project — it only fills in the missing platform folders, it won't touch your `lib/` code. After that, the icon and native splash screen will be wired into the Android/iOS projects automatically. The in-app Dart splash screen already works with no extra steps.

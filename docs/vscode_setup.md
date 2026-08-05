# VS Code setup guide

This guide gets a fresh machine ready to build and run SeatWise.

## 1. Install the Flutter SDK

Follow the official guide for your OS: <https://docs.flutter.dev/get-started/install>.

Verify:

```bash
flutter --version
flutter doctor
```

Resolve anything `flutter doctor` flags before continuing. On Windows, enable
Developer Mode when prompted (needed for symlinks/plugins).

## 2. Install Android Studio (for the Android toolchain)

Download from <https://developer.android.com/studio>. During first‑run setup,
install the **Android SDK**, **SDK command‑line tools**, and create an **AVD**
(emulator). Then accept licences:

```bash
flutter doctor --android-licenses
```

Android Studio is required even if you edit in VS Code, because it provides the
Android SDK, platform tools and emulator.

## 3. Install VS Code

Download from <https://code.visualstudio.com/> and install.

## 4. Install the Flutter extension

- Open the **Extensions** panel (`Ctrl/Cmd+Shift+X`).
- Search **Flutter** and install it (the **Dart** extension is installed with it).
- Reload VS Code if prompted.

Useful commands (via `Ctrl/Cmd+Shift+P`):

- **Flutter: New Project**
- **Flutter: Select Device**
- **Flutter: Run Flutter Doctor**

## 5. Recommended VS Code settings

Create `.vscode/settings.json` (git‑ignored except for these):

```json
{
  "editor.formatOnSave": true,
  "editor.defaultFormatter": "Dart-Code.dart-code",
  "dart.lineLength": 80,
  "[dart]": {
    "editor.rulers": [80],
    "editor.selectionHighlight": false
  }
}
```

And a run configuration `.vscode/launch.json`:

```json
{
  "version": "0.2.0",
  "configurations": [
    { "name": "SeatWise (debug)", "request": "launch", "type": "dart" },
    {
      "name": "SeatWise (profile)",
      "request": "launch",
      "type": "dart",
      "flutterMode": "profile"
    }
  ]
}
```

## 6. Open and run the project

```bash
cd seatwise
flutter pub get
```

Select a device (bottom‑right of VS Code or **Flutter: Select Device**), then
press **F5** or run:

```bash
flutter run
```

## 7. Node.js (for Cloud Functions, optional)

The Cloud Functions use Node 20. Install from <https://nodejs.org/> (or via nvm),
then:

```bash
cd functions
npm install
npm run build
```

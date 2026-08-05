import 'dart:async';

import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app.dart';
import 'config/env.dart';
import 'firebase_options.dart';
import 'providers/providers.dart';
import 'utils/logger.dart';

/// Application entry point.
///
/// Order matters: bindings first, then environment + Firebase, then Crashlytics
/// error routing, and finally the widget tree inside a [ProviderScope] with the
/// initialised [SharedPreferences] injected as an override.
Future<void> main() async {
  await runZonedGuarded<Future<void>>(() async {
    WidgetsFlutterBinding.ensureInitialized();

    await Env.load();

    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );

    // Route uncaught Flutter + platform errors to Crashlytics (release only).
    if (!kDebugMode) {
      FlutterError.onError =
          FirebaseCrashlytics.instance.recordFlutterFatalError;
      PlatformDispatcher.instance.onError = (error, stack) {
        FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
        return true;
      };
    }

    await FirebaseAnalytics.instance
        .setAnalyticsCollectionEnabled(!kDebugMode);

    final prefs = await SharedPreferences.getInstance();

    runApp(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
        ],
        child: const SeatWiseApp(),
      ),
    );
  }, (error, stack) {
    Log.e('Uncaught zone error', error: error, stackTrace: stack);
    if (!kDebugMode) {
      FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
    }
  });
}

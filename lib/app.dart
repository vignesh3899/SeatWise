import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'config/theme.dart';
import 'core/constants.dart';
import 'providers/providers.dart';
import 'providers/theme_controller.dart';
import 'screens/auth/login_screen.dart';
import 'screens/home/home_screen.dart';
import 'screens/splash/splash_screen.dart';
import 'widgets/error_view.dart';
import 'widgets/loading_view.dart';

/// Root widget: wires up theming and routes between the splash screen, the
/// auth flow and the home shell based on the single [authStateProvider]
/// source of truth.
class SeatWiseApp extends ConsumerStatefulWidget {
  const SeatWiseApp({super.key});

  @override
  ConsumerState<SeatWiseApp> createState() => _SeatWiseAppState();
}

class _SeatWiseAppState extends ConsumerState<SeatWiseApp> {
  bool _showSplash = true;

  @override
  Widget build(BuildContext context) {
    final themeMode = ref.watch(themeControllerProvider);

    return MaterialApp(
      title: AppConstants.appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: themeMode,
      home: AnimatedSwitcher(
        duration: const Duration(milliseconds: 450),
        child: _showSplash
            ? SplashScreen(
                key: const ValueKey('splash'),
                onFinished: () => setState(() => _showSplash = false),
              )
            : const _AuthGate(key: ValueKey('auth-gate')),
      ),
    );
  }
}

/// Decides which top-level screen to show while the auth state resolves.
class _AuthGate extends ConsumerWidget {
  const _AuthGate({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authStateProvider);

    return auth.when(
      loading: () => const Scaffold(body: LoadingView(message: 'Starting SeatWise…')),
      error: (error, _) => Scaffold(
        body: ErrorView(
          message: 'Could not start the app.\n$error',
          onRetry: () => ref.invalidate(authStateProvider),
        ),
      ),
      data: (user) =>
          user == null ? const LoginScreen() : const HomeShell(),
    );
  }
}

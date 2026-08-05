import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/failure.dart';
import '../core/result.dart';
import '../models/app_user.dart';
import 'providers.dart';

/// Drives the sign-in / register / sign-out actions and surfaces their progress
/// as an [AsyncValue]. Screens listen to the state for a spinner + error snack
/// while the [authStateProvider] stream handles navigation once auth succeeds.
class AuthController extends AsyncNotifier<void> {
  @override
  Future<void> build() async {}

  Future<Result<AppUser>> signIn(String email, String password) async {
    state = const AsyncLoading();
    final result = await ref
        .read(authRepositoryProvider)
        .signIn(email: email, password: password);
    state = result.isSuccess
        ? const AsyncData<void>(null)
        : AsyncError<void>(result.failureOrNull!, StackTrace.current);
    return result;
  }

  Future<Result<AppUser>> register({
    required String email,
    required String password,
    String? displayName,
  }) async {
    state = const AsyncLoading();
    final result = await ref.read(authRepositoryProvider).register(
          email: email,
          password: password,
          displayName: displayName,
        );
    state = result.isSuccess
        ? const AsyncData<void>(null)
        : AsyncError<void>(result.failureOrNull!, StackTrace.current);
    return result;
  }

  Future<Result<void>> sendPasswordReset(String email) {
    return ref.read(authRepositoryProvider).sendPasswordReset(email);
  }

  Future<Result<AppUser>> setPreferShade(bool value) {
    return ref.read(authRepositoryProvider).updatePreferShade(value);
  }

  Future<void> signOut() async {
    await ref.read(authRepositoryProvider).signOut();
    state = const AsyncData(null);
  }
}

final authControllerProvider =
    AsyncNotifierProvider<AuthController, void>(AuthController.new);

/// Human-readable message for the most recent auth error, or null.
String? authErrorMessage(AsyncValue<void> state) {
  if (state case AsyncError(:final error) when error is Failure) {
    return error.message;
  }
  return null;
}

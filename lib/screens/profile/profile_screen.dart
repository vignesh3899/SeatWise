import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/auth_controller.dart';
import '../../providers/providers.dart';
import '../../providers/theme_controller.dart';

/// Profile and settings: user identity, shade preference, theme (dark mode) and
/// sign out.
class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    final themeMode = ref.watch(themeControllerProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Center(
            child: Column(
              children: [
                CircleAvatar(
                  radius: 40,
                  backgroundColor: theme.colorScheme.primaryContainer,
                  child: Text(
                    _initials(user?.displayName, user?.email),
                    style: theme.textTheme.headlineSmall?.copyWith(
                      color: theme.colorScheme.onPrimaryContainer,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  user?.displayName ?? 'Traveller',
                  style: theme.textTheme.titleLarge,
                ),
                Text(
                  user?.email ?? '',
                  style: theme.textTheme.bodyMedium
                      ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Text('Preferences', style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          Card(
            child: SwitchListTile(
              secondary: const Icon(Icons.beach_access),
              title: const Text('Prefer shaded seat'),
              subtitle:
                  const Text('Bias recommendations toward the cooler side.'),
              value: user?.preferShade ?? true,
              onChanged: (value) async {
                final result = await ref
                    .read(authControllerProvider.notifier)
                    .setPreferShade(value);
                if (context.mounted && result.isFailure) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(result.failureOrNull!.message)),
                  );
                }
              },
            ),
          ),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.brightness_6_outlined),
                  title: const Text('Appearance'),
                  subtitle: Text(_themeLabel(themeMode)),
                ),
                const Divider(height: 1),
                for (final mode in ThemeMode.values)
                  RadioListTile<ThemeMode>(
                    value: mode,
                    groupValue: themeMode,
                    onChanged: (selected) {
                      if (selected != null) {
                        ref
                            .read(themeControllerProvider.notifier)
                            .setMode(selected);
                      }
                    },
                    title: Text(_themeOption(mode)),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          OutlinedButton.icon(
            onPressed: () => ref.read(authControllerProvider.notifier).signOut(),
            icon: const Icon(Icons.logout),
            label: const Text('Sign out'),
          ),
        ],
      ),
    );
  }

  String _themeLabel(ThemeMode mode) => switch (mode) {
        ThemeMode.system => 'Follows your device setting',
        ThemeMode.light => 'Light',
        ThemeMode.dark => 'Dark',
      };

  String _themeOption(ThemeMode mode) => switch (mode) {
        ThemeMode.system => 'System default',
        ThemeMode.light => 'Light',
        ThemeMode.dark => 'Dark',
      };

  String _initials(String? name, String? email) {
    if (name != null && name.trim().isNotEmpty) {
      final parts = name.trim().split(RegExp(r'\s+'));
      return parts.take(2).map((p) => p[0].toUpperCase()).join();
    }
    if (email != null && email.isNotEmpty) return email[0].toUpperCase();
    return '🙂';
  }
}

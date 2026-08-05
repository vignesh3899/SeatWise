import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../config/env.dart';
import '../../config/theme.dart';
import '../../core/constants.dart';
import '../../providers/providers.dart';
import '../../providers/recommendation_controller.dart';
import '../../utils/formatters.dart';
import '../../widgets/glass_container.dart';
import '../../widgets/tilt_card.dart';
import '../history/history_screen.dart';
import '../planner/journey_planner_screen.dart';
import '../profile/profile_screen.dart';
import '../recommendation/recommendation_screen.dart';

/// The signed-in shell: a bottom navigation bar over Home, History and Profile.
class HomeShell extends ConsumerStatefulWidget {
  const HomeShell({super.key});

  @override
  ConsumerState<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends ConsumerState<HomeShell> {
  int _index = 0;

  static const _tabs = [_HomeTab(), HistoryScreen(), ProfileScreen()];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _index, children: _tabs),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.history_outlined),
            selectedIcon: Icon(Icons.history),
            label: 'History',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}

class _HomeTab extends ConsumerWidget {
  const _HomeTab();

  void _startPlanner(BuildContext context, WidgetRef ref) {
    ref.read(recommendationControllerProvider.notifier).clear();
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const JourneyPlannerScreen()),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    final journeys = ref.watch(journeysProvider);
    final theme = Theme.of(context);
    final greeting = user?.displayName?.split(' ').first ?? 'there';

    return Scaffold(
      appBar: AppBar(
        title: const Text(AppConstants.appName),
        actions: [
          if (!Env.hasRoutingKey || !Env.hasWeatherKey)
            IconButton(
              tooltip: 'API keys missing',
              onPressed: () => _showKeyWarning(context),
              icon: Icon(Icons.warning_amber, color: theme.colorScheme.error),
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('Hi $greeting 👋', style: theme.textTheme.headlineSmall),
          const SizedBox(height: 4),
          Text(
            'Where are you headed today? 🗺️',
            style: theme.textTheme.bodyLarge
                ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: 20),
          _PlanCard(onTap: () => _startPlanner(context, ref)),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('🕒 Recent journeys', style: theme.textTheme.titleMedium),
            ],
          ),
          const SizedBox(height: 8),
          journeys.when(
            loading: () => const Padding(
              padding: EdgeInsets.all(24),
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (e, _) => Text('Could not load history: $e'),
            data: (list) {
              if (list.isEmpty) {
                return const _EmptyRecent();
              }
              return Column(
                children: list.take(3).map((j) {
                  final color = AppTheme.sideColor(j.recommendedSide);
                  final sideEmoji = switch (j.recommendedSide) {
                    SeatSide.left => '⬅️',
                    SeatSide.right => '➡️',
                    SeatSide.either => '↔️',
                  };
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: TiltCard(
                      borderRadius: 18,
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) =>
                              RecommendationScreen.fromJourney(journey: j),
                        ),
                      ),
                      child: GlassContainer(
                        borderRadius: 18,
                        tint: color,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 12),
                        child: Row(
                          children: [
                            CircleAvatar(
                              backgroundColor: color.withValues(alpha: 0.22),
                              child: Text(sideEmoji,
                                  style: const TextStyle(fontSize: 18)),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '${j.originLabel} → ${j.destinationLabel}',
                                    style: theme.textTheme.titleSmall,
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    '${j.recommendedSide.label} • '
                                    '⏱️ ${Formatters.duration(j.eta)} • '
                                    '${Formatters.dateTime(j.departureAt)}',
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: theme.colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const Icon(Icons.chevron_right_rounded),
                          ],
                        ),
                      ),
                    ),
                  );
                }).toList(),
              );
            },
          ),
        ],
      ),
    );
  }

  void _showKeyWarning(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('API keys missing'),
        content: const Text(
          'Add your OpenRouteService and OpenWeather keys to the .env file to '
          'enable live routing and weather. See the README for setup steps.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Got it'),
          ),
        ],
      ),
    );
  }
}

class _PlanCard extends StatelessWidget {
  const _PlanCard({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return TiltCard(
      borderRadius: 24,
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [AppTheme.leftColor, AppTheme.rightColor],
          ),
        ),
        child: GlassContainer(
          borderRadius: 24,
          tint: Colors.white,
          opacity: 0.06,
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              const FloatingWidget(
                amplitude: 5,
                child: Text('🚌☀️', style: TextStyle(fontSize: 38)),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Plan a journey',
                      style: textTheme.titleLarge?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Get a left / right seat pick with reasons why 🪑✨',
                      style: textTheme.bodyMedium?.copyWith(
                        color: Colors.white.withValues(alpha: 0.92),
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.arrow_forward_rounded, color: Colors.white),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyRecent extends StatelessWidget {
  const _EmptyRecent();

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            const Text('🗺️', style: TextStyle(fontSize: 36)),
            const SizedBox(height: 12),
            const Text(
              'No journeys yet. Plan your first trip to see it here. 🚌',
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

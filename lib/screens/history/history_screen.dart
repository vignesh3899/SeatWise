import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../config/theme.dart';
import '../../models/journey.dart';
import '../../providers/providers.dart';
import '../../providers/recommendation_controller.dart';
import '../../utils/formatters.dart';
import '../../widgets/error_view.dart';
import '../recommendation/recommendation_screen.dart';

/// The user's saved journeys, newest first. Swipe to delete, tap to reopen the
/// full recommendation.
class HistoryScreen extends ConsumerWidget {
  const HistoryScreen({super.key});

  Future<void> _delete(WidgetRef ref, BuildContext context, Journey j) async {
    final result = await ref.read(journeyRepositoryProvider).delete(j.id);
    if (!context.mounted) return;
    if (result.isFailure) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result.failureOrNull!.message)),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final journeys = ref.watch(journeysProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Journey history')),
      body: journeys.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => ErrorView(
          message: 'Could not load your journeys.\n$e',
          onRetry: () => ref.invalidate(journeysProvider),
        ),
        data: (list) {
          if (list.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: Text(
                  'Your planned journeys will appear here.',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: list.length,
            itemBuilder: (context, i) {
              final j = list[i];
              final color = AppTheme.sideColor(j.recommendedSide);
              return Dismissible(
                key: ValueKey(j.id),
                direction: DismissDirection.endToStart,
                background: Container(
                  alignment: Alignment.centerRight,
                  padding: const EdgeInsets.only(right: 24),
                  margin: const EdgeInsets.symmetric(vertical: 4),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.errorContainer,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Icon(Icons.delete_outline),
                ),
                onDismissed: (_) => _delete(ref, context, j),
                child: Card(
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: color.withValues(alpha: 0.15),
                      child: Text(
                        j.recommendedSide.label.substring(0, 1),
                        style: TextStyle(
                            color: color, fontWeight: FontWeight.bold),
                      ),
                    ),
                    title: Text('${j.originLabel} → ${j.destinationLabel}'),
                    subtitle: Text(
                      '${j.headline}\n'
                      '${Formatters.dateTime(j.departureAt)} • '
                      'ETA ${Formatters.duration(j.eta)}',
                    ),
                    isThreeLine: true,
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) =>
                            RecommendationScreen.fromJourney(journey: j),
                      ),
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

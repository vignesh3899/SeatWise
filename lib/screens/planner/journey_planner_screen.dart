import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../config/env.dart';
import '../../providers/planner_controller.dart';
import '../../providers/recommendation_controller.dart';
import '../../utils/formatters.dart';
import '../../widgets/place_search_field.dart';
import '../recommendation/recommendation_screen.dart';

/// Lets the user choose origin, destination, departure time and shade preference
/// before requesting a recommendation.
class JourneyPlannerScreen extends ConsumerWidget {
  const JourneyPlannerScreen({super.key});

  Future<void> _pickDeparture(
    BuildContext context,
    WidgetRef ref,
    DateTime current,
  ) async {
    final date = await showDatePicker(
      context: context,
      initialDate: current,
      firstDate: DateTime.now().subtract(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 30)),
    );
    if (date == null || !context.mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(current),
    );
    if (time == null) return;
    ref.read(plannerControllerProvider.notifier).setDeparture(
          DateTime(date.year, date.month, date.day, time.hour, time.minute),
        );
  }

  void _submit(BuildContext context, WidgetRef ref) {
    ref.read(recommendationControllerProvider.notifier).run();
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const RecommendationScreen()),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final planner = ref.watch(plannerControllerProvider);
    final notifier = ref.read(plannerControllerProvider.notifier);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Plan a journey')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (!Env.hasRoutingKey)
            Card(
              color: theme.colorScheme.errorContainer,
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Row(
                  children: [
                    Icon(Icons.info_outline,
                        color: theme.colorScheme.onErrorContainer),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'No OpenRouteService key found. Add it to .env to fetch '
                        'real routes.',
                        style: TextStyle(
                            color: theme.colorScheme.onErrorContainer),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          PlaceSearchField(
            label: 'From',
            icon: Icons.trip_origin,
            initial: planner.origin,
            onSelected: notifier.setOrigin,
          ),
          const SizedBox(height: 4),
          Align(
            alignment: Alignment.centerRight,
            child: IconButton.filledTonal(
              tooltip: 'Swap',
              onPressed: notifier.swap,
              icon: const Icon(Icons.swap_vert),
            ),
          ),
          PlaceSearchField(
            label: 'To',
            icon: Icons.place,
            initial: planner.destination,
            onSelected: notifier.setDestination,
          ),
          const SizedBox(height: 20),
          Card(
            child: ListTile(
              leading: const Icon(Icons.schedule),
              title: const Text('Departure'),
              subtitle: Text(Formatters.dateTime(planner.departure)),
              trailing: const Icon(Icons.edit_calendar_outlined),
              onTap: () => _pickDeparture(context, ref, planner.departure),
            ),
          ),
          Card(
            child: SwitchListTile(
              secondary: Icon(
                planner.preferShade ? Icons.beach_access : Icons.wb_sunny,
              ),
              title: const Text('Prefer the shaded side'),
              subtitle: Text(
                planner.preferShade
                    ? 'We will favour the cooler, shadier side.'
                    : 'We will favour the sunnier side.',
              ),
              value: planner.preferShade,
              onChanged: notifier.setPreferShade,
            ),
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: planner.isReady ? () => _submit(context, ref) : null,
            icon: const Icon(Icons.event_seat),
            label: const Text('Get seat recommendation'),
          ),
          if (!planner.isReady)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(
                'Choose both a start and destination to continue.',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall,
              ),
            ),
        ],
      ),
    );
  }
}

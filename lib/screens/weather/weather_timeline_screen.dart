import 'package:flutter/material.dart';

import '../../models/weather_point.dart';
import '../../utils/formatters.dart';

/// Full-screen vertical weather timeline sampled along the route.
class WeatherTimelineScreen extends StatelessWidget {
  const WeatherTimelineScreen({super.key, required this.samples});

  final List<WeatherPoint> samples;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Weather timeline')),
      body: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: samples.length,
        separatorBuilder: (_, __) => const SizedBox(height: 4),
        itemBuilder: (context, i) {
          final w = samples[i];
          final label = i == 0
              ? 'Start of journey'
              : i == samples.length - 1
                  ? 'Destination'
                  : 'Along the route (${i + 1})';
          return IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Column(
                  children: [
                    Icon(Icons.circle, size: 14, color: theme.colorScheme.primary),
                    if (i != samples.length - 1)
                      Expanded(
                        child: Container(
                          width: 2,
                          color: theme.colorScheme.outlineVariant,
                        ),
                      ),
                  ],
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          Icon(_iconFor(w),
                              size: 40, color: theme.colorScheme.primary),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(label,
                                    style: theme.textTheme.titleSmall),
                                const SizedBox(height: 4),
                                Text(
                                  '${w.description.isEmpty ? w.condition : w.description} • '
                                  'cloud ${w.cloudPercent.round()}%'
                                  '${w.isRaining ? ' • rain likely' : ''}',
                                  style: theme.textTheme.bodyMedium,
                                ),
                              ],
                            ),
                          ),
                          Text(
                            Formatters.temperature(w.temperatureC),
                            style: theme.textTheme.titleLarge
                                ?.copyWith(fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  IconData _iconFor(WeatherPoint w) {
    final c = w.condition.toLowerCase();
    if (c.contains('thunder')) return Icons.thunderstorm;
    if (c.contains('drizzle') || c.contains('rain')) return Icons.grain;
    if (c.contains('snow')) return Icons.ac_unit;
    if (c.contains('cloud')) return Icons.cloud;
    if (c.contains('mist') || c.contains('fog') || c.contains('haze')) {
      return Icons.foggy;
    }
    return Icons.wb_sunny;
  }
}

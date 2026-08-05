import 'package:flutter/material.dart';

import '../models/weather_point.dart';
import '../utils/formatters.dart';

/// A single stop on the weather timeline. [label] is typically a position along
/// the route such as "Start", "Midway" or "Destination".
class WeatherTile extends StatelessWidget {
  const WeatherTile({super.key, required this.label, required this.weather});

  final String label;
  final WeatherPoint weather;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: 120,
      margin: const EdgeInsets.only(right: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: theme.textTheme.labelLarge),
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(_iconFor(weather), size: 30, color: theme.colorScheme.primary),
              const Spacer(),
              Text(
                Formatters.temperature(weather.temperatureC),
                style: theme.textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            weather.description.isEmpty ? weather.condition : weather.description,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodySmall,
          ),
          const SizedBox(height: 4),
          Text(
            'Cloud ${weather.cloudPercent.round()}%',
            style: theme.textTheme.bodySmall
                ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }

  /// Maps OpenWeather condition groups to Material icons (offline-friendly, no
  /// need to fetch the icon PNGs).
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

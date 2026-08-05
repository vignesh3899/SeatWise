import 'package:flutter/material.dart';

import '../config/theme.dart';
import '../core/constants.dart';
import '../models/attraction.dart';
import '../utils/formatters.dart';

/// A list row describing one scenic attraction, colour-coded by which side of
/// the vehicle it appears on.
class AttractionTile extends StatelessWidget {
  const AttractionTile({super.key, required this.attraction});

  final Attraction attraction;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = AppTheme.sideColor(attraction.side);

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 4),
      leading: CircleAvatar(
        backgroundColor: color.withValues(alpha: 0.15),
        child: Icon(_iconFor(attraction.category), color: color),
      ),
      title: Text(attraction.name),
      subtitle: Text(
        '${_prettyCategory(attraction.category)} • '
        '${Formatters.distanceKm(attraction.distanceFromRouteMeters)} from route',
      ),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              attraction.side == SeatSide.either
                  ? 'Ahead'
                  : attraction.side.label,
              style: theme.textTheme.labelMedium?.copyWith(color: color),
            ),
          ),
          if (attraction.rating != null) ...[
            const SizedBox(height: 4),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.star, size: 14, color: Colors.amber),
                const SizedBox(width: 2),
                Text(attraction.rating!.toStringAsFixed(1),
                    style: theme.textTheme.labelSmall),
              ],
            ),
          ],
        ],
      ),
    );
  }

  IconData _iconFor(String category) {
    return switch (category) {
      'viewpoint' => Icons.landscape,
      'peak' => Icons.terrain,
      'beach' || 'bay' => Icons.beach_access,
      'water' || 'waterfall' => Icons.water,
      'castle' || 'fort' || 'ruins' => Icons.castle,
      'monument' || 'memorial' => Icons.account_balance,
      'museum' || 'gallery' || 'artwork' => Icons.museum,
      'park' || 'garden' || 'nature_reserve' => Icons.park,
      'zoo' || 'theme_park' => Icons.attractions,
      _ => Icons.place,
    };
  }

  String _prettyCategory(String category) =>
      category.replaceAll('_', ' ').replaceFirstMapped(
            RegExp(r'^\w'),
            (m) => m.group(0)!.toUpperCase(),
          );
}

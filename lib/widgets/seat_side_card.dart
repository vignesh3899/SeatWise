import 'package:flutter/material.dart';

import '../config/theme.dart';
import '../core/constants.dart';
import '../models/seat_recommendation.dart';
import '../utils/formatters.dart';
import 'bus_seat_diagram.dart';

/// The hero card at the top of the recommendation screen: the recommended side,
/// a confidence chip and the bus diagram.
class SeatSideCard extends StatelessWidget {
  const SeatSideCard({super.key, required this.recommendation});

  final SeatRecommendation recommendation;

  @override
  Widget build(BuildContext context) {
    final side = recommendation.recommendedSide;
    final color = AppTheme.sideColor(side);
    final theme = Theme.of(context);

    return Card(
      color: color.withValues(alpha: 0.10),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(_iconFor(side), color: color, size: 34),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    recommendation.headline,
                    style: theme.textTheme.titleLarge
                        ?.copyWith(fontWeight: FontWeight.bold, color: color),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            BusSeatDiagram(recommended: side),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _chip(
                  context,
                  Icons.verified_outlined,
                  'Confidence ${Formatters.percent(recommendation.confidence)}',
                ),
                _chip(
                  context,
                  Icons.schedule,
                  'ETA ${Formatters.duration(recommendation.eta)}',
                ),
                _chip(
                  context,
                  Icons.groups_outlined,
                  'Crowd ${recommendation.crowdLabel}',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _chip(BuildContext context, IconData icon, String label) {
    return Chip(
      avatar: Icon(icon, size: 18),
      label: Text(label),
      visualDensity: VisualDensity.compact,
    );
  }

  IconData _iconFor(SeatSide side) => switch (side) {
        SeatSide.left => Icons.arrow_back,
        SeatSide.right => Icons.arrow_forward,
        SeatSide.either => Icons.swap_horiz,
      };
}

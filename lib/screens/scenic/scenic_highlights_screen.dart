import 'package:flutter/material.dart';

import '../../config/theme.dart';
import '../../core/constants.dart';
import '../../models/attraction.dart';
import '../../widgets/attraction_tile.dart';

/// Lists scenic attractions grouped by the side of the vehicle they appear on.
class ScenicHighlightsScreen extends StatelessWidget {
  const ScenicHighlightsScreen({super.key, required this.attractions});

  final List<Attraction> attractions;

  @override
  Widget build(BuildContext context) {
    final left =
        attractions.where((a) => a.side == SeatSide.left).toList();
    final right =
        attractions.where((a) => a.side == SeatSide.right).toList();
    final ahead =
        attractions.where((a) => a.side == SeatSide.either).toList();

    return Scaffold(
      appBar: AppBar(title: const Text('Scenic highlights')),
      body: attractions.isEmpty
          ? const Center(child: Text('No notable landmarks near this route.'))
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _group(context, 'Left side', AppTheme.leftColor, left),
                _group(context, 'Right side', AppTheme.rightColor, right),
                _group(context, 'Straight ahead', AppTheme.seed, ahead),
              ],
            ),
    );
  }

  Widget _group(
    BuildContext context,
    String title,
    Color color,
    List<Attraction> items,
  ) {
    if (items.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            children: [
              Container(width: 12, height: 12, decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(3),
              )),
              const SizedBox(width: 8),
              Text(
                '$title (${items.length})',
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(color: color),
              ),
            ],
          ),
        ),
        Card(
          child: Column(
            children: [for (final a in items) AttractionTile(attraction: a)],
          ),
        ),
        const SizedBox(height: 12),
      ],
    );
  }
}

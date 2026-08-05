import 'package:flutter/material.dart';

import '../config/theme.dart';
import '../core/constants.dart';

/// A small top-down bus diagram that highlights the recommended side. Purely
/// decorative but makes the recommendation instantly legible.
class BusSeatDiagram extends StatelessWidget {
  const BusSeatDiagram({super.key, required this.recommended, this.height = 150});

  final SeatSide recommended;
  final double height;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final leftHighlighted =
        recommended == SeatSide.left || recommended == SeatSide.either;
    final rightHighlighted =
        recommended == SeatSide.right || recommended == SeatSide.either;

    return SizedBox(
      height: height,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: _SeatColumn(
              label: 'LEFT',
              color: AppTheme.leftColor,
              highlighted: leftHighlighted,
            ),
          ),
          Container(width: 22, color: scheme.surfaceContainerHighest),
          Expanded(
            child: _SeatColumn(
              label: 'RIGHT',
              color: AppTheme.rightColor,
              highlighted: rightHighlighted,
            ),
          ),
        ],
      ),
    );
  }
}

class _SeatColumn extends StatelessWidget {
  const _SeatColumn({
    required this.label,
    required this.color,
    required this.highlighted,
  });

  final String label;
  final Color color;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final base = highlighted ? color : scheme.surfaceContainerHighest;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: base.withValues(alpha: highlighted ? 0.18 : 0.4),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: highlighted ? color : Colors.transparent,
          width: 2,
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          Text(
            label,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: highlighted ? color : scheme.onSurfaceVariant,
              letterSpacing: 1,
            ),
          ),
          for (var row = 0; row < 3; row++)
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _seat(color, highlighted),
                const SizedBox(width: 8),
                _seat(color, highlighted),
              ],
            ),
        ],
      ),
    );
  }

  Widget _seat(Color color, bool highlighted) {
    return Container(
      width: 22,
      height: 22,
      decoration: BoxDecoration(
        color: highlighted ? color : color.withValues(alpha: 0.25),
        borderRadius: BorderRadius.circular(5),
      ),
    );
  }
}

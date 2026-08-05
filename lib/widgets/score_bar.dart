import 'package:flutter/material.dart';

import '../config/theme.dart';
import '../models/seat_recommendation.dart';
import '../utils/formatters.dart';

/// Compares the left vs right sub-scores (comfort, scenic, weather, total) as a
/// row of paired bars so the user sees exactly why one side won.
class ScoreComparison extends StatelessWidget {
  const ScoreComparison({
    super.key,
    required this.left,
    required this.right,
  });

  final SideScores left;
  final SideScores right;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _row(context, 'Overall', left.total, right.total, emphasise: true),
        _row(context, 'Shade / comfort', left.comfort, right.comfort),
        _row(context, 'Scenery', left.scenic, right.scenic),
        _row(context, 'Weather', left.weather, right.weather),
      ],
    );
  }

  Widget _row(
    BuildContext context,
    String label,
    double leftValue,
    double rightValue, {
    bool emphasise = false,
  }) {
    final style = emphasise
        ? Theme.of(context).textTheme.titleSmall
        : Theme.of(context).textTheme.bodyMedium;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              SizedBox(
                width: 40,
                child: Text(Formatters.score(leftValue),
                    style: style, textAlign: TextAlign.left),
              ),
              Expanded(child: Center(child: Text(label, style: style))),
              SizedBox(
                width: 40,
                child: Text(Formatters.score(rightValue),
                    style: style, textAlign: TextAlign.right),
              ),
            ],
          ),
          const SizedBox(height: 4),
          _bars(context, leftValue, rightValue),
        ],
      ),
    );
  }

  Widget _bars(BuildContext context, double leftValue, double rightValue) {
    final track = Theme.of(context).colorScheme.surfaceContainerHighest;
    return Row(
      children: [
        Expanded(
          child: _halfBar(
            value: leftValue,
            color: AppTheme.leftColor,
            track: track,
            alignEnd: true,
          ),
        ),
        const SizedBox(width: 4),
        Expanded(
          child: _halfBar(
            value: rightValue,
            color: AppTheme.rightColor,
            track: track,
            alignEnd: false,
          ),
        ),
      ],
    );
  }

  Widget _halfBar({
    required double value,
    required Color color,
    required Color track,
    required bool alignEnd,
  }) {
    final fraction = (value / 100.0).clamp(0.0, 1.0);
    return ClipRRect(
      borderRadius: BorderRadius.circular(6),
      child: Container(
        height: 10,
        color: track,
        child: Align(
          alignment: alignEnd ? Alignment.centerRight : Alignment.centerLeft,
          child: FractionallySizedBox(
            widthFactor: fraction,
            child: Container(color: color),
          ),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/geo_coord.dart';
import '../../models/journey.dart';
import '../../models/seat_recommendation.dart';
import '../../providers/recommendation_controller.dart';
import '../../widgets/attraction_tile.dart';
import '../../widgets/error_view.dart';
import '../../widgets/loading_view.dart';
import '../../widgets/score_bar.dart';
import '../../widgets/seat_side_card.dart';
import '../../widgets/weather_tile.dart';
import '../feedback/feedback_screen.dart';
import '../map/map_screen.dart';
import '../scenic/scenic_highlights_screen.dart';
import '../weather/weather_timeline_screen.dart';

/// Shows a computed recommendation. Two entry points:
///  * the live planner flow (watches the recommendation controller), and
///  * opening a saved [Journey] from history (uses its stored recommendation).
class RecommendationScreen extends ConsumerWidget {
  const RecommendationScreen({super.key}) : journey = null;

  const RecommendationScreen.fromJourney({super.key, required this.journey});

  final Journey? journey;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (journey != null) {
      final rec = journey!.recommendation;
      if (rec == null) {
        return Scaffold(
          appBar: AppBar(title: const Text('Recommendation')),
          body: const ErrorView(message: 'This journey has no saved details.'),
        );
      }
      return _Content(
        recommendation: rec,
        origin: journey!.origin,
        destination: journey!.destination,
        polyline: const [],
        journeyId: journey!.id,
        title: '${journey!.originLabel} → ${journey!.destinationLabel}',
      );
    }

    final async = ref.watch(recommendationControllerProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Seat recommendation')),
      body: async.when(
        loading: () => const LoadingView(
          message: 'Analysing sun, scenery and weather along your route…',
        ),
        error: (error, _) => ErrorView(
          message: error.toString().replaceFirst('Instance of ', ''),
          onRetry: () => ref.read(recommendationControllerProvider.notifier).run(),
        ),
        data: (bundle) {
          if (bundle == null) {
            return const LoadingView(message: 'Preparing…');
          }
          return _Content(
            recommendation: bundle.recommendation,
            origin: bundle.route.polyline.first,
            destination: bundle.route.polyline.last,
            polyline: bundle.route.polyline,
            journeyId: '',
            title: null,
            embedAppBar: false,
          );
        },
      ),
    );
  }
}

class _Content extends StatelessWidget {
  const _Content({
    required this.recommendation,
    required this.origin,
    required this.destination,
    required this.polyline,
    required this.journeyId,
    this.title,
    this.embedAppBar = true,
  });

  final SeatRecommendation recommendation;
  final GeoCoord origin;
  final GeoCoord destination;
  final List<GeoCoord> polyline;
  final String journeyId;
  final String? title;
  final bool embedAppBar;

  List<GeoCoord> get _mapLine =>
      polyline.isNotEmpty ? polyline : [origin, destination];

  @override
  Widget build(BuildContext context) {
    final body = ListView(
      padding: const EdgeInsets.all(16),
      children: [
        SeatSideCard(recommendation: recommendation),
        const SizedBox(height: 20),
        _section(context, 'Why this side'),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final reason in recommendation.reasons)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Padding(
                          padding: EdgeInsets.only(top: 3, right: 10),
                          child: Icon(Icons.check_circle_outline, size: 18),
                        ),
                        Expanded(child: Text(reason)),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),
        _section(context, 'Score breakdown'),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: ScoreComparison(
              left: recommendation.leftScores,
              right: recommendation.rightScores,
            ),
          ),
        ),
        const SizedBox(height: 20),
        if (recommendation.weatherSamples.isNotEmpty) ...[
          _sectionWithAction(
            context,
            'Weather along the way',
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => WeatherTimelineScreen(
                  samples: recommendation.weatherSamples,
                ),
              ),
            ),
          ),
          SizedBox(
            height: 150,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: recommendation.weatherSamples.length,
              itemBuilder: (context, i) => WeatherTile(
                label: _weatherLabel(i, recommendation.weatherSamples.length),
                weather: recommendation.weatherSamples[i],
              ),
            ),
          ),
          const SizedBox(height: 20),
        ],
        if (recommendation.attractions.isNotEmpty) ...[
          _sectionWithAction(
            context,
            'Scenic highlights',
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => ScenicHighlightsScreen(
                  attractions: recommendation.attractions,
                ),
              ),
            ),
          ),
          Card(
            child: Column(
              children: [
                for (final a in recommendation.attractions.take(4))
                  AttractionTile(attraction: a),
              ],
            ),
          ),
          const SizedBox(height: 20),
        ],
        OutlinedButton.icon(
          onPressed: () => Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => MapScreen(
                polyline: _mapLine,
                attractions: recommendation.attractions,
                side: recommendation.recommendedSide,
                origin: origin,
                destination: destination,
              ),
            ),
          ),
          icon: const Icon(Icons.map_outlined),
          label: const Text('View route on map'),
        ),
        const SizedBox(height: 12),
        FilledButton.tonalIcon(
          onPressed: () => Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => FeedbackScreen(
                journeyId: journeyId,
                suggestedSide: recommendation.recommendedSide,
              ),
            ),
          ),
          icon: const Icon(Icons.rate_review_outlined),
          label: const Text('Was this helpful?'),
        ),
      ],
    );

    if (!embedAppBar) return body;
    return Scaffold(
      appBar: AppBar(title: Text(title ?? 'Recommendation')),
      body: body,
    );
  }

  Widget _section(BuildContext context, String title) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(title, style: Theme.of(context).textTheme.titleMedium),
      );

  Widget _sectionWithAction(
    BuildContext context,
    String title, {
    required VoidCallback onTap,
  }) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            TextButton(onPressed: onTap, child: const Text('See all')),
          ],
        ),
      );

  String _weatherLabel(int index, int total) {
    if (index == 0) return 'Start';
    if (index == total - 1) return 'Destination';
    return 'Stop ${index + 1}';
  }
}

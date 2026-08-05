import 'package:equatable/equatable.dart';

import '../core/constants.dart';

/// User feedback on a recommendation, used to close the loop and (later) tune
/// the engine weights. Persisted in the `feedback` collection.
class JourneyFeedback extends Equatable {
  const JourneyFeedback({
    required this.id,
    required this.userId,
    required this.journeyId,
    required this.wasHelpful,
    required this.actualSide,
    required this.createdAt,
    this.rating = 0,
    this.comment = '',
  });

  final String id;
  final String userId;
  final String journeyId;

  /// Did the recommendation match the user's real-world experience?
  final bool wasHelpful;

  /// Which side the user actually found best.
  final SeatSide actualSide;

  /// 1..5 star rating (0 = not provided).
  final int rating;
  final String comment;
  final DateTime createdAt;

  Map<String, dynamic> toJson() => {
        'userId': userId,
        'journeyId': journeyId,
        'wasHelpful': wasHelpful,
        'actualSide': actualSide.name,
        'rating': rating,
        'comment': comment,
        'createdAt': createdAt.toUtc().toIso8601String(),
      };

  factory JourneyFeedback.fromJson(String id, Map<String, dynamic> json) =>
      JourneyFeedback(
        id: id,
        userId: json['userId'] as String,
        journeyId: json['journeyId'] as String? ?? '',
        wasHelpful: json['wasHelpful'] as bool? ?? false,
        actualSide: SeatSide.values.firstWhere(
          (s) => s.name == json['actualSide'],
          orElse: () => SeatSide.either,
        ),
        rating: (json['rating'] as num?)?.toInt() ?? 0,
        comment: json['comment'] as String? ?? '',
        createdAt:
            DateTime.tryParse(json['createdAt'].toString())?.toLocal() ??
                DateTime.now(),
      );

  @override
  List<Object?> get props =>
      [id, userId, journeyId, wasHelpful, actualSide, rating];
}

/// Application-wide constants: API endpoints, Firestore collection names and
/// the tunable weights that drive the recommendation engine.
class AppConstants {
  AppConstants._();

  static const String appName = 'SeatWise';

  // --- Firestore collections -------------------------------------------------
  static const String usersCollection = 'users';
  static const String journeysCollection = 'journeys';
  static const String feedbackCollection = 'feedback';

  // --- Cloud Function --------------------------------------------------------
  static const String recommendFunction = 'recommendSeat';

  // --- Free API base URLs ----------------------------------------------------
  static const String orsBaseUrl = 'https://api.openrouteservice.org';
  static const String openWeatherBaseUrl =
      'https://api.openweathermap.org/data/2.5';
  static const String nominatimBaseUrl =
      'https://nominatim.openstreetmap.org';
  static const String overpassBaseUrl =
      'https://overpass-api.de/api/interpreter';

  /// Nominatim and Overpass require a descriptive User-Agent / Referer.
  static const String httpUserAgent =
      'SeatWise/1.0 (https://github.com/seatwise/seatwise)';

  // --- Engine tuning ---------------------------------------------------------

  /// How far (metres) off the route an OSM attraction may be to still count.
  static const double attractionSearchRadiusMeters = 1500;

  /// Maximum number of attractions to keep per side for scenic scoring.
  static const int maxAttractionsPerSide = 25;

  /// Segment sampling: target distance between analysed points (metres).
  static const double segmentSampleMeters = 2000;

  /// Weights used to combine the per-side sub-scores into a final score.
  /// They must sum to 1.0.
  static const double weightComfort = 0.45; // shade / sun avoidance
  static const double weightScenic = 0.35; // attractions + view
  static const double weightWeather = 0.20; // weather-driven comfort

  /// Minimum score gap (0..100) below which the two sides are called a tie.
  static const double tieThreshold = 4.0;
}

/// Which side of the vehicle a seat is on.
enum SeatSide {
  left,
  right,
  either;

  String get label => switch (this) {
        SeatSide.left => 'Left',
        SeatSide.right => 'Right',
        SeatSide.either => 'Either side',
      };
}

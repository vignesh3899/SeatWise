import 'package:equatable/equatable.dart';

/// Weather sampled at a point along the route.
class WeatherPoint extends Equatable {
  const WeatherPoint({
    required this.temperatureC,
    required this.cloudPercent,
    required this.condition,
    required this.description,
    required this.icon,
    this.rainMmPerHour = 0,
  });

  final double temperatureC;

  /// Cloud cover 0..100. Higher cloud => weaker sun => sun side matters less.
  final double cloudPercent;

  /// Short OpenWeather group, e.g. `Clear`, `Clouds`, `Rain`.
  final String condition;
  final String description;
  final String icon;
  final double rainMmPerHour;

  /// 0..1 sky clearness; drives how strongly the sun-side scoring applies.
  double get clearness => (1.0 - (cloudPercent / 100.0)).clamp(0.0, 1.0);

  bool get isRaining => condition.toLowerCase().contains('rain') || rainMmPerHour > 0;

  factory WeatherPoint.fromOpenWeatherJson(Map<String, dynamic> json) {
    final weatherList = json['weather'] as List<dynamic>?;
    final weather = (weatherList != null && weatherList.isNotEmpty)
        ? weatherList.first as Map<String, dynamic>
        : const <String, dynamic>{};
    final main = json['main'] as Map<String, dynamic>? ?? const {};
    final clouds = json['clouds'] as Map<String, dynamic>? ?? const {};
    final rain = json['rain'] as Map<String, dynamic>?;

    return WeatherPoint(
      temperatureC: (main['temp'] as num?)?.toDouble() ?? 0,
      cloudPercent: (clouds['all'] as num?)?.toDouble() ?? 0,
      condition: weather['main'] as String? ?? 'Unknown',
      description: weather['description'] as String? ?? '',
      icon: weather['icon'] as String? ?? '01d',
      rainMmPerHour: (rain?['1h'] as num?)?.toDouble() ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {
        'temperatureC': temperatureC,
        'cloudPercent': cloudPercent,
        'condition': condition,
        'description': description,
        'icon': icon,
        'rainMmPerHour': rainMmPerHour,
      };

  factory WeatherPoint.fromJson(Map<String, dynamic> json) => WeatherPoint(
        temperatureC: (json['temperatureC'] as num).toDouble(),
        cloudPercent: (json['cloudPercent'] as num).toDouble(),
        condition: json['condition'] as String,
        description: json['description'] as String? ?? '',
        icon: json['icon'] as String? ?? '01d',
        rainMmPerHour: (json['rainMmPerHour'] as num?)?.toDouble() ?? 0,
      );

  @override
  List<Object?> get props =>
      [temperatureC, cloudPercent, condition, description, icon, rainMmPerHour];
}

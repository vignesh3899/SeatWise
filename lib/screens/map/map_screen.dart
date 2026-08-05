import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' as ll;

import '../../config/theme.dart';
import '../../core/constants.dart';
import '../../models/attraction.dart';
import '../../models/geo_coord.dart';

/// Renders the route polyline over OpenStreetMap tiles with the origin,
/// destination and scenic attractions (colour-coded by side) as markers.
class MapScreen extends StatelessWidget {
  const MapScreen({
    super.key,
    required this.polyline,
    required this.attractions,
    required this.side,
    required this.origin,
    required this.destination,
  });

  final List<GeoCoord> polyline;
  final List<Attraction> attractions;
  final SeatSide side;
  final GeoCoord origin;
  final GeoCoord destination;

  ll.LatLng _toLatLng(GeoCoord c) => ll.LatLng(c.lat, c.lng);

  @override
  Widget build(BuildContext context) {
    final points = polyline.map(_toLatLng).toList();
    final bounds = LatLngBounds.fromPoints(
      points.isNotEmpty ? points : [_toLatLng(origin), _toLatLng(destination)],
    );

    return Scaffold(
      appBar: AppBar(title: const Text('Route map')),
      body: FlutterMap(
        options: MapOptions(
          initialCameraFit: CameraFit.bounds(
            bounds: bounds,
            padding: const EdgeInsets.all(48),
          ),
          interactionOptions: const InteractionOptions(
            flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
          ),
        ),
        children: [
          TileLayer(
            urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
            userAgentPackageName: 'org.seatwise.seatwise',
          ),
          if (points.length >= 2)
            PolylineLayer(
              polylines: [
                Polyline(
                  points: points,
                  strokeWidth: 5,
                  color: AppTheme.sideColor(side).withValues(alpha: 0.85),
                ),
              ],
            ),
          MarkerLayer(
            markers: [
              _pin(origin, Icons.trip_origin, Colors.green),
              _pin(destination, Icons.location_on, Colors.red),
              for (final a in attractions.take(40))
                _pin(
                  a.location,
                  Icons.circle,
                  AppTheme.sideColor(a.side),
                  size: 14,
                ),
            ],
          ),
          const RichAttributionWidget(
            attributions: [
              TextSourceAttribution('© OpenStreetMap contributors'),
            ],
          ),
        ],
      ),
      bottomNavigationBar: _Legend(side: side),
    );
  }

  Marker _pin(GeoCoord c, IconData icon, Color color, {double size = 30}) {
    return Marker(
      point: _toLatLng(c),
      width: size + 8,
      height: size + 8,
      child: Icon(icon, color: color, size: size),
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend({required this.side});

  final SeatSide side;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Wrap(
          alignment: WrapAlignment.center,
          spacing: 16,
          children: [
            _item(AppTheme.leftColor, 'Left-side sights'),
            _item(AppTheme.rightColor, 'Right-side sights'),
            _item(AppTheme.sideColor(side), 'Recommended: ${side.label}'),
          ],
        ),
      ),
    );
  }

  Widget _item(Color color, String label) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(width: 12, height: 12, decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(3),
          )),
          const SizedBox(width: 6),
          Text(label),
        ],
      );
}

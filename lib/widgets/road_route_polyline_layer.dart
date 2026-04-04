import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:milleservices/services/osrm_route_service.dart';

/// Couche [PolylineLayer] qui suit les routes OSM (OSRM), avec repli sur une ligne droite.
class RoadRoutePolylineLayer extends StatefulWidget {
  const RoadRoutePolylineLayer({
    super.key,
    required this.from,
    required this.to,
    this.color = Colors.red,
    this.strokeWidth = 4,
  });

  final LatLng from;
  final LatLng to;
  final Color color;
  final double strokeWidth;

  @override
  State<RoadRoutePolylineLayer> createState() => _RoadRoutePolylineLayerState();
}

class _RoadRoutePolylineLayerState extends State<RoadRoutePolylineLayer> {
  List<LatLng>? _roadPoints;
  String? _fetchKey;

  static bool _sameLatLng(LatLng a, LatLng b) =>
      a.latitude == b.latitude && a.longitude == b.longitude;

  static String _key(LatLng a, LatLng b) =>
      '${a.latitude.toStringAsFixed(6)},${a.longitude.toStringAsFixed(6)};'
      '${b.latitude.toStringAsFixed(6)},${b.longitude.toStringAsFixed(6)}';

  @override
  void initState() {
    super.initState();
    _requestRoute();
  }

  @override
  void didUpdateWidget(covariant RoadRoutePolylineLayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_sameLatLng(oldWidget.from, widget.from) ||
        !_sameLatLng(oldWidget.to, widget.to)) {
      _requestRoute();
    }
  }

  void _requestRoute() {
    final key = _key(widget.from, widget.to);
    if (_fetchKey == key && _roadPoints != null) return;
    _fetchKey = key;

    OsrmRouteService.fetchDrivingRoute(widget.from, widget.to).then((pts) {
      if (!mounted) return;
      if (_key(widget.from, widget.to) != key) return;
      setState(() {
        _roadPoints = pts != null && pts.length >= 2 ? pts : null;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final points = _roadPoints ?? [widget.from, widget.to];
    return PolylineLayer(
      polylines: [
        Polyline(
          points: points,
          color: widget.color,
          strokeWidth: widget.strokeWidth,
        ),
      ],
    );
  }
}

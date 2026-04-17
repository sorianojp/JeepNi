import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

class MapCameraAnimator {
  MapCameraAnimator({required this.mapController, required this.vsync});

  static const Duration defaultDuration = Duration(milliseconds: 850);

  final MapController mapController;
  final TickerProvider vsync;

  AnimationController? _controller;

  void jumpTo(LatLng location, double zoom) {
    _stopCurrentAnimation();
    mapController.move(location, zoom);
  }

  void animateTo(
    LatLng location,
    double zoom, {
    Duration duration = defaultDuration,
    Curve curve = Curves.easeOutCubic,
  }) {
    _stopCurrentAnimation();

    final camera = mapController.camera;
    final latTween = Tween<double>(
      begin: camera.center.latitude,
      end: location.latitude,
    );
    final lngTween = Tween<double>(
      begin: camera.center.longitude,
      end: location.longitude,
    );
    final zoomTween = Tween<double>(begin: camera.zoom, end: zoom);

    final controller = AnimationController(duration: duration, vsync: vsync);
    _controller = controller;
    final animation = CurvedAnimation(parent: controller, curve: curve);

    controller.addListener(() {
      if (_controller != controller) return;
      mapController.move(
        LatLng(latTween.evaluate(animation), lngTween.evaluate(animation)),
        zoomTween.evaluate(animation),
      );
    });

    controller.addStatusListener((status) {
      if (status != AnimationStatus.completed &&
          status != AnimationStatus.dismissed) {
        return;
      }

      if (_controller == controller) {
        _controller = null;
      }
      controller.dispose();
    });

    controller.forward();
  }

  void dispose() {
    _stopCurrentAnimation();
  }

  void _stopCurrentAnimation() {
    final controller = _controller;
    if (controller == null) return;
    _controller = null;
    controller.dispose();
  }
}

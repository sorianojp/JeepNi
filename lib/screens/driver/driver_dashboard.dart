import 'package:geolocator/geolocator.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/firebase_auth_service.dart';
import '../../services/firebase_tracking_service.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';
import '../../core/map_camera_animator.dart';
import '../../widgets/app_map_tile_layer.dart';

const double _driverOverlayRadius = 18;

class _StudentCluster {
  _StudentCluster(this.center, this.count);

  LatLng center;
  int count;

  void add(LatLng point) {
    center = LatLng(
      ((center.latitude * count) + point.latitude) / (count + 1),
      ((center.longitude * count) + point.longitude) / (count + 1),
    );
    count += 1;
  }
}

class DriverDashboard extends StatefulWidget {
  const DriverDashboard({super.key});

  @override
  State<DriverDashboard> createState() => _DriverDashboardState();
}

class _DriverDashboardState extends State<DriverDashboard>
    with TickerProviderStateMixin {
  static const double _studentClusterRadiusMeters = 30;
  static const double _cameraMoveThresholdMeters = 2;
  static const double _offscreenIndicatorPadding = 18;

  final MapController _mapController = MapController();
  late final MapCameraAnimator _cameraAnimator;
  bool _hasCenteredMap = false;
  LatLng? _lastFollowedLocation;

  @override
  void initState() {
    super.initState();
    _cameraAnimator = MapCameraAnimator(
      mapController: _mapController,
      vsync: this,
    );
  }

  @override
  void dispose() {
    _cameraAnimator.dispose();
    super.dispose();
  }

  String _speedLabel(double? speedKmh) {
    if (speedKmh == null) return '-- km/h';
    return '${speedKmh.round()} km/h';
  }

  String _distanceLabel(LatLng? from, LatLng to) {
    if (from == null) return 'Waiting for your location';

    final meters = Geolocator.distanceBetween(
      from.latitude,
      from.longitude,
      to.latitude,
      to.longitude,
    );

    if (meters < 1000) {
      return '${meters.round()} m away';
    }

    return '${(meters / 1000).toStringAsFixed(1)} km away';
  }

  List<_StudentCluster> _clusterStudents(Iterable<LatLng> points) {
    final clusters = <_StudentCluster>[];

    for (final point in points) {
      _StudentCluster? nearestCluster;
      double? nearestDistance;

      for (final cluster in clusters) {
        final distance = Geolocator.distanceBetween(
          point.latitude,
          point.longitude,
          cluster.center.latitude,
          cluster.center.longitude,
        );

        if (distance <= _studentClusterRadiusMeters &&
            (nearestDistance == null || distance < nearestDistance)) {
          nearestCluster = cluster;
          nearestDistance = distance;
        }
      }

      if (nearestCluster == null) {
        clusters.add(_StudentCluster(point, 1));
      } else {
        nearestCluster.add(point);
      }
    }

    return clusters;
  }

  void _syncDriverCamera(LatLng? driverLocation) {
    if (driverLocation == null) return;
    final lastLocation = _lastFollowedLocation;
    if (lastLocation != null) {
      final distance = Geolocator.distanceBetween(
        lastLocation.latitude,
        lastLocation.longitude,
        driverLocation.latitude,
        driverLocation.longitude,
      );
      if (distance < _cameraMoveThresholdMeters) return;
    }

    _lastFollowedLocation = driverLocation;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _cameraAnimator.animateTo(driverLocation, 16.0);
    });
  }

  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<FirebaseAuthService>(context);
    final trackingService = Provider.of<FirebaseTrackingService>(context);

    final user = authService.currentUser;
    if (user == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    trackingService.startSharingLocation(user.id);

    final myLocation = trackingService.getLocation(user.id);
    final speedKmh = trackingService.getSpeedKmh(user.id);
    final allLocations = trackingService.getAllLocations();

    final studentsLocations = allLocations.entries
        .where((entry) => trackingService.isStudent(entry.key))
        .toList();
    final studentClusters = _clusterStudents(
      studentsLocations.map((student) => student.value),
    );
    final mapCenter =
        myLocation ??
        (studentsLocations.isEmpty ? null : studentsLocations.first.value);
    if (!_hasCenteredMap && mapCenter != null) {
      _hasCenteredMap = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _cameraAnimator.jumpTo(mapCenter, 14.0);
      });
    }
    _syncDriverCamera(myLocation);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Driver Dashboard'),
        backgroundColor: Colors.green,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await trackingService.stopSharingLocation(user.id);
              authService.logout();
              if (!context.mounted) return;
              context.go('/login');
            },
          ),
        ],
      ),
      body: mapCenter == null
          ? const Center(child: Text('Waiting for live location...'))
          : Stack(
              children: [
                FlutterMap(
                  mapController: _mapController,
                  options: MapOptions(
                    initialCenter: mapCenter,
                    initialZoom: 14.0,
                    onPositionChanged: (camera, hasGesture) {
                      if (mounted) {
                        setState(() {});
                      }
                    },
                  ),
                  children: [
                    ColoredBox(color: Colors.grey.shade200),
                    const AppMapTileLayer(),
                    MarkerLayer(
                      markers: [
                        if (myLocation != null)
                          Marker(
                            point: myLocation,
                            width: 92,
                            height: 92,
                            child: _DriverMarker(
                              speedLabel: _speedLabel(speedKmh),
                            ),
                          ),
                        ...studentClusters.map(
                          (cluster) => Marker(
                            point: cluster.center,
                            width: 80,
                            height: 80,
                            child: _StudentClusterMarker(count: cluster.count),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                _OffscreenStudentIndicators(
                  clusters: studentClusters,
                  mapController: _mapController,
                  padding: _offscreenIndicatorPadding,
                  onTapCluster: (cluster) {
                    _cameraAnimator.animateTo(cluster.center, 16.0);
                  },
                ),
                Positioned(
                  left: 12,
                  right: 12,
                  top: 12,
                  child: _DriverMapControls(
                    driverName: user.name,
                    speedLabel: _speedLabel(speedKmh),
                  ),
                ),
                if (trackingService.locationError != null)
                  Positioned(
                    left: 12,
                    right: 12,
                    top: 86,
                    child: _DriverMapErrorBanner(
                      message: trackingService.locationError!,
                    ),
                  ),
                _StudentClustersBottomSheet(
                  clusters: studentClusters,
                  driverLocation: myLocation,
                  distanceLabel: _distanceLabel,
                  onTapCluster: (cluster) {
                    _cameraAnimator.animateTo(cluster.center, 16.0);
                  },
                ),
              ],
            ),
    );
  }
}

class _DriverMapControls extends StatelessWidget {
  const _DriverMapControls({
    required this.driverName,
    required this.speedLabel,
  });

  final String driverName;
  final String speedLabel;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.94),
        borderRadius: BorderRadius.circular(_driverOverlayRadius),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            const Icon(Icons.directions_bus, color: Colors.green),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                driverName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            DecoratedBox(
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: Colors.green.shade200),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.speed, size: 18, color: Colors.green),
                    const SizedBox(width: 4),
                    Text(
                      speedLabel,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DriverMapErrorBanner extends StatelessWidget {
  const _DriverMapErrorBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.red.shade50.withValues(alpha: 0.96),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.red.shade100),
      ),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Text(
          message,
          style: TextStyle(color: Colors.red.shade800),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}

class _StudentClustersBottomSheet extends StatelessWidget {
  const _StudentClustersBottomSheet({
    required this.clusters,
    required this.driverLocation,
    required this.distanceLabel,
    required this.onTapCluster,
  });

  final List<_StudentCluster> clusters;
  final LatLng? driverLocation;
  final String Function(LatLng? from, LatLng to) distanceLabel;
  final ValueChanged<_StudentCluster> onTapCluster;

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.22,
      minChildSize: 0.12,
      maxChildSize: 0.48,
      snap: true,
      snapSizes: const [0.12, 0.22, 0.48],
      builder: (context, scrollController) {
        return DecoratedBox(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.18),
                blurRadius: 20,
                offset: const Offset(0, -6),
              ),
            ],
          ),
          child: Column(
            children: [
              const SizedBox(height: 8),
              Container(
                width: 44,
                height: 5,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
                child: Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Students Waiting',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    Text(
                      '${clusters.fold<int>(0, (total, cluster) => total + cluster.count)}',
                      style: TextStyle(
                        color: Colors.grey.shade700,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: clusters.isEmpty
                    ? ListView(
                        controller: scrollController,
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                        children: const [
                          Center(child: Text('No students sharing location.')),
                        ],
                      )
                    : ListView.separated(
                        controller: scrollController,
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                        itemCount: clusters.length,
                        separatorBuilder: (context, index) =>
                            const Divider(height: 1),
                        itemBuilder: (context, index) {
                          final cluster = clusters[index];
                          final title = cluster.count == 1
                              ? '1 student Waiting'
                              : '${cluster.count} students Waiting';

                          return ListTile(
                            dense: true,
                            contentPadding: EdgeInsets.zero,
                            onTap: () => onTapCluster(cluster),
                            leading: const Icon(
                              Icons.person_pin_circle,
                              color: Colors.blue,
                            ),
                            title: Text(title),
                            subtitle: Text(
                              distanceLabel(driverLocation, cluster.center),
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _OffscreenStudentIndicators extends StatelessWidget {
  const _OffscreenStudentIndicators({
    required this.clusters,
    required this.mapController,
    required this.padding,
    required this.onTapCluster,
  });

  final List<_StudentCluster> clusters;
  final MapController mapController;
  final double padding;
  final ValueChanged<_StudentCluster> onTapCluster;

  @override
  Widget build(BuildContext context) {
    if (clusters.isEmpty) {
      return const SizedBox.shrink();
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        if (!constraints.hasBoundedWidth || !constraints.hasBoundedHeight) {
          return const SizedBox.shrink();
        }

        final camera = mapController.camera;
        final bounds = camera.visibleBounds;
        final width = constraints.maxWidth;
        final height = constraints.maxHeight;
        final indicators = <Widget>[];

        for (final cluster in clusters) {
          if (bounds.contains(cluster.center)) {
            continue;
          }

          final screenOffset = camera.latLngToScreenOffset(cluster.center);
          final x = screenOffset.dx.clamp(padding, width - padding);
          final y = screenOffset.dy.clamp(padding, height - padding);

          indicators.add(
            Positioned(
              left: x - 22,
              top: y - 22,
              child: _OffscreenStudentIndicator(
                count: cluster.count,
                onTap: () => onTapCluster(cluster),
              ),
            ),
          );
        }

        if (indicators.isEmpty) {
          return const SizedBox.shrink();
        }

        return IgnorePointer(
          ignoring: false,
          child: Stack(children: indicators),
        );
      },
    );
  }
}

class _OffscreenStudentIndicator extends StatelessWidget {
  const _OffscreenStudentIndicator({required this.count, required this.onTap});

  final int count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onTap,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.94),
            shape: BoxShape.circle,
            border: Border.all(color: Colors.blue, width: 2),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.18),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: SizedBox(
            width: 44,
            height: 44,
            child: Stack(
              alignment: Alignment.center,
              clipBehavior: Clip.none,
              children: [
                const Icon(
                  Icons.person_pin_circle,
                  color: Colors.blue,
                  size: 28,
                ),
                if (count > 1)
                  Positioned(
                    top: -7,
                    right: -7,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: Colors.blue,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(5),
                        child: Text(
                          count.toString(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DriverMarker extends StatelessWidget {
  const _DriverMarker({required this.speedLabel});

  final String speedLabel;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.directions_bus, color: Colors.green, size: 44),
        DecoratedBox(
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.92),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: Colors.green.shade200),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
            child: Text(
              speedLabel,
              style: const TextStyle(
                color: Colors.green,
                fontSize: 11,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _StudentClusterMarker extends StatelessWidget {
  const _StudentClusterMarker({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    if (count == 1) {
      return const Icon(Icons.person_pin_circle, color: Colors.blue, size: 30);
    }

    return Stack(
      alignment: Alignment.center,
      clipBehavior: Clip.none,
      children: [
        const Icon(Icons.person_pin_circle, color: Colors.blue, size: 42),
        Positioned(
          top: -10,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.blue, width: 2),
            ),
            child: Padding(
              padding: const EdgeInsets.all(6),
              child: Text(
                count.toString(),
                style: const TextStyle(
                  color: Colors.blue,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

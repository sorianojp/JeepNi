import 'package:geolocator/geolocator.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/firebase_auth_service.dart';
import '../../services/firebase_tracking_service.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';
import '../../widgets/app_map_tile_layer.dart';

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

class DriverDashboard extends StatelessWidget {
  const DriverDashboard({super.key});

  static const double _studentClusterRadiusMeters = 30;

  String _speedLabel(double? speedKmh) {
    if (speedKmh == null) return '-- km/h';
    return '${speedKmh.round()} km/h';
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

    return Scaffold(
      appBar: AppBar(
        title: const Text('Driver Dashboard'),
        backgroundColor: Colors.green,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () {
              authService.logout();
              context.go('/login');
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.green.shade50,
            child: Row(
              children: [
                const Icon(Icons.directions_bus),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Welcome, Driver ${user.name}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: Colors.green.shade200),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.speed, size: 18, color: Colors.green),
                      const SizedBox(width: 4),
                      Text(
                        _speedLabel(speedKmh),
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: mapCenter == null
                ? const Center(child: Text('Waiting for live location...'))
                : FlutterMap(
                    key: ValueKey(
                      '${mapCenter.latitude},${mapCenter.longitude}',
                    ),
                    options: MapOptions(
                      initialCenter: mapCenter,
                      initialZoom: 14.0,
                    ),
                    children: [
                      ColoredBox(color: Colors.grey.shade200),
                      const AppMapTileLayer(),
                      MarkerLayer(
                        markers: [
                          if (myLocation != null)
                            Marker(
                              point: myLocation,
                              width: 80,
                              height: 80,
                              child: const Icon(
                                Icons.directions_bus,
                                color: Colors.green,
                                size: 40,
                              ),
                            ),
                          ...studentClusters.map(
                            (cluster) => Marker(
                              point: cluster.center,
                              width: 80,
                              height: 80,
                              child: _StudentClusterMarker(
                                count: cluster.count,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
          ),
          if (trackingService.locationError != null)
            Padding(
              padding: const EdgeInsets.all(8),
              child: Text(
                trackingService.locationError!,
                style: const TextStyle(color: Colors.red),
                textAlign: TextAlign.center,
              ),
            ),
        ],
      ),
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

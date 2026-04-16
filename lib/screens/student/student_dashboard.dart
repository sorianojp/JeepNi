import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/firebase_auth_service.dart';
import '../../services/firebase_tracking_service.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:go_router/go_router.dart';
import '../../widgets/app_map_tile_layer.dart';

class StudentDashboard extends StatelessWidget {
  const StudentDashboard({super.key});

  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<FirebaseAuthService>(context);
    final trackingService = Provider.of<FirebaseTrackingService>(context);

    final user = authService.currentUser;
    if (user == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    trackingService.startSharingLocation(user.id);

    final allLocations = trackingService.getAllLocations();
    final driverLocations = allLocations.entries
        .where((entry) => trackingService.isDriver(entry.key))
        .toList();
    final myLocation =
        trackingService.getLocation(user.id) ??
        user.location ??
        const LatLng(14.5995, 120.9842);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Student Dashboard'),
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
            color: Colors.blue.shade50,
            child: Row(
              children: [
                const Icon(Icons.person),
                const SizedBox(width: 8),
                Text(
                  'Welcome, ${user.name}',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: FlutterMap(
              key: ValueKey('${myLocation.latitude},${myLocation.longitude}'),
              options: MapOptions(initialCenter: myLocation, initialZoom: 15.0),
              children: [
                ColoredBox(color: Colors.grey.shade200),
                const AppMapTileLayer(),
                MarkerLayer(
                  markers: [
                    // My location marker
                    Marker(
                      point: myLocation,
                      width: 80,
                      height: 80,
                      child: const Icon(
                        Icons.person_pin_circle,
                        color: Colors.blue,
                        size: 40,
                      ),
                    ),
                    // Driver location markers
                    ...driverLocations.map(
                      (driver) => Marker(
                        point: driver.value,
                        width: 80,
                        height: 80,
                        child: const Icon(
                          Icons.directions_bus,
                          color: Colors.green,
                          size: 40,
                        ),
                      ),
                    ),
                  ],
                ),
                const SimpleAttributionWidget(
                  source: Text('OpenStreetMap, CARTO'),
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

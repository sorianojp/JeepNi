import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/firebase_auth_service.dart';
import '../../services/firebase_tracking_service.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:go_router/go_router.dart';
import '../../widgets/app_map_tile_layer.dart';

class DriverDashboard extends StatelessWidget {
  const DriverDashboard({super.key});

  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<FirebaseAuthService>(context);
    final trackingService = Provider.of<FirebaseTrackingService>(context);

    final user = authService.currentUser;
    if (user == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    trackingService.startSharingLocation(user.id);

    final myLocation =
        trackingService.getLocation(user.id) ??
        user.location ??
        const LatLng(14.590, 120.975);
    final allLocations = trackingService.getAllLocations();

    final studentsLocations = allLocations.entries
        .where((entry) => trackingService.isStudent(entry.key))
        .toList();

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
                Text(
                  'Welcome, Driver ${user.name}',
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
              options: MapOptions(initialCenter: myLocation, initialZoom: 14.0),
              children: [
                ColoredBox(color: Colors.grey.shade200),
                const AppMapTileLayer(),
                MarkerLayer(
                  markers: [
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
                    ...studentsLocations.map(
                      (student) => Marker(
                        point: student.value,
                        width: 80,
                        height: 80,
                        child: const Icon(
                          Icons.person_pin_circle,
                          color: Colors.blue,
                          size: 30,
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

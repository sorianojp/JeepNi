import 'package:geolocator/geolocator.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/firebase_auth_service.dart';
import '../../services/firebase_tracking_service.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';
import '../../widgets/app_map_tile_layer.dart';

class StudentDashboard extends StatefulWidget {
  const StudentDashboard({super.key});

  @override
  State<StudentDashboard> createState() => _StudentDashboardState();
}

class _StudentDashboardState extends State<StudentDashboard> {
  static const double _driverListHeight = 230;

  final MapController _mapController = MapController();
  bool _hasCenteredMap = false;

  String _distanceLabel(LatLng? from, LatLng? to) {
    if (from == null) return 'Start sharing to calculate distance';
    if (to == null) return 'Location unavailable';

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

  String _speedLabel(double? speedKmh) {
    if (speedKmh == null) return 'Speed unavailable';
    return '${speedKmh.round()} km/h';
  }

  void _focusDriver(LatLng? driverLocation) {
    if (driverLocation == null) return;
    _mapController.move(driverLocation, 16.0);
  }

  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<FirebaseAuthService>(context);
    final trackingService = Provider.of<FirebaseTrackingService>(context);

    final user = authService.currentUser;
    if (user == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final allLocations = trackingService.getAllLocations();
    final driverIds = trackingService.getDriverIds();
    final driverLocations = allLocations.entries
        .where((entry) => trackingService.isDriver(entry.key))
        .toList();
    final myLocation = trackingService.getLocation(user.id);
    final isSharing = trackingService.isSharingLocation(user.id);
    final isStarting = trackingService.isStartingLocationStream;
    final mapCenter =
        myLocation ??
        (driverLocations.isEmpty ? null : driverLocations.first.value);
    if (!_hasCenteredMap && mapCenter != null) {
      _hasCenteredMap = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _mapController.move(mapCenter, 15.0);
      });
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Student Dashboard'),
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
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: isStarting
                    ? null
                    : () {
                        if (isSharing) {
                          trackingService.stopSharingLocation(user.id);
                        } else {
                          trackingService.startSharingLocation(user.id);
                        }
                      },
                icon: isStarting
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Icon(
                        isSharing ? Icons.location_disabled : Icons.my_location,
                      ),
                label: Text(
                  isStarting
                      ? 'Starting location sharing...'
                      : isSharing
                      ? 'Stop sharing location'
                      : 'Start sharing location',
                ),
              ),
            ),
          ),
          Expanded(
            child: mapCenter == null
                ? const Center(child: Text('Waiting for live location...'))
                : FlutterMap(
                    mapController: _mapController,
                    options: MapOptions(
                      initialCenter: mapCenter,
                      initialZoom: 15.0,
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
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(
                                    Icons.person_pin_circle,
                                    color: Colors.blue,
                                    size: 40,
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withValues(
                                        alpha: 0.9,
                                      ),
                                      borderRadius: BorderRadius.circular(999),
                                    ),
                                    child: const Text(
                                      'Me',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
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
          SizedBox(
            height: _driverListHeight,
            child: Card(
              margin: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(color: Colors.blue.shade100),
              ),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Drivers nearby',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Expanded(
                      child: driverIds.isEmpty
                          ? const Center(
                              child: Text('No drivers available yet.'),
                            )
                          : ListView.separated(
                              itemCount: driverIds.length,
                              separatorBuilder: (context, index) =>
                                  const Divider(height: 1),
                              itemBuilder: (context, index) {
                                final driverId = driverIds[index];
                                final driverLocation = trackingService
                                    .getLocation(driverId);
                                final driverSpeedKmh = trackingService
                                    .getSpeedKmh(driverId);

                                return ListTile(
                                  dense: true,
                                  contentPadding: EdgeInsets.zero,
                                  enabled: driverLocation != null,
                                  onTap: driverLocation == null
                                      ? null
                                      : () => _focusDriver(driverLocation),
                                  leading: const Icon(
                                    Icons.directions_bus,
                                    color: Colors.green,
                                  ),
                                  title: Text(
                                    trackingService.displayNameFor(driverId),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  subtitle: Text(
                                    '${_distanceLabel(myLocation, driverLocation)} • ${_speedLabel(driverSpeedKmh)}',
                                  ),
                                );
                              },
                            ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

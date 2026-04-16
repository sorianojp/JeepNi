import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';

import '../../services/firebase_tracking_service.dart';
import '../../widgets/app_map_tile_layer.dart';

class AdminMapScreen extends StatelessWidget {
  const AdminMapScreen({super.key});

  static const LatLng _defaultMapCenter = LatLng(15.9574705, 120.4419412);

  @override
  Widget build(BuildContext context) {
    final trackingService = Provider.of<FirebaseTrackingService>(context);
    final allLocations = trackingService.getAllLocations();
    final driverCount = allLocations.keys
        .where((userId) => trackingService.isDriver(userId))
        .length;
    final studentCount = allLocations.keys
        .where((userId) => trackingService.isStudent(userId))
        .length;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Live Map'),
        backgroundColor: Colors.purple,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/admin'),
        ),
      ),
      body: Stack(
        children: [
          FlutterMap(
            options: const MapOptions(
              initialCenter: _defaultMapCenter,
              initialZoom: 10.5,
            ),
            children: [
              ColoredBox(color: Colors.grey.shade200),
              const AppMapTileLayer(),
              MarkerLayer(
                markers: allLocations.entries.map((entry) {
                  final isDriver = trackingService.isDriver(entry.key);
                  final displayName = trackingService.displayNameFor(entry.key);

                  return Marker(
                    point: entry.value,
                    width: 90,
                    height: 84,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          isDriver
                              ? Icons.directions_bus
                              : Icons.person_pin_circle,
                          color: isDriver ? Colors.green : Colors.blue,
                          size: isDriver ? 40 : 30,
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.85),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            displayName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
              const SimpleAttributionWidget(
                source: Text('OpenStreetMap, CARTO'),
              ),
            ],
          ),
          Positioned(
            left: 12,
            right: 12,
            top: 12,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.92),
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.12),
                    blurRadius: 12,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    const Icon(Icons.location_on, color: Colors.purple),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '$studentCount students • $driverCount drivers live',
                        style: const TextStyle(fontWeight: FontWeight.bold),
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

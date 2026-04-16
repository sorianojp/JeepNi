import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/firebase_auth_service.dart';
import '../../services/firebase_tracking_service.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:go_router/go_router.dart';
import '../../widgets/app_map_tile_layer.dart';

class AdminDashboard extends StatefulWidget {
  const AdminDashboard({super.key});

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  final TextEditingController _driverNameController = TextEditingController();
  final TextEditingController _driverEmailController = TextEditingController();
  final TextEditingController _driverPasswordController =
      TextEditingController();
  bool _isCreatingDriver = false;
  String? _driverFormMessage;

  @override
  void dispose() {
    _driverNameController.dispose();
    _driverEmailController.dispose();
    _driverPasswordController.dispose();
    super.dispose();
  }

  Future<void> _createDriver(FirebaseAuthService authService) async {
    final name = _driverNameController.text.trim();
    final email = _driverEmailController.text.trim();
    final password = _driverPasswordController.text;

    if (name.isEmpty || email.isEmpty || password.isEmpty) {
      setState(() {
        _driverFormMessage = 'Driver name, email, and password are required.';
      });
      return;
    }

    setState(() {
      _isCreatingDriver = true;
      _driverFormMessage = null;
    });

    final success = await authService.createDriverAccount(
      email: email,
      password: password,
      name: name,
    );

    if (!mounted) return;

    setState(() {
      _isCreatingDriver = false;
      _driverFormMessage = success
          ? 'Driver account created.'
          : authService.lastError ?? 'Could not create driver account.';
    });

    if (success) {
      _driverNameController.clear();
      _driverEmailController.clear();
      _driverPasswordController.clear();
    }
  }

  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<FirebaseAuthService>(context);
    final trackingService = Provider.of<FirebaseTrackingService>(context);

    final allLocations = trackingService.getAllLocations();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Dashboard'),
        backgroundColor: Colors.purple,
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
            color: Colors.purple.shade50,
            child: const Row(
              children: [
                Icon(Icons.admin_panel_settings),
                SizedBox(width: 8),
                Text(
                  'System Overview',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(color: Colors.purple.shade100),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Create Driver Account',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _driverNameController,
                      decoration: const InputDecoration(
                        labelText: 'Driver full name',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _driverEmailController,
                      keyboardType: TextInputType.emailAddress,
                      decoration: const InputDecoration(
                        labelText: 'Driver email',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _driverPasswordController,
                      obscureText: true,
                      decoration: const InputDecoration(
                        labelText: 'Temporary password',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    if (_driverFormMessage != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Text(
                          _driverFormMessage!,
                          style: TextStyle(
                            color:
                                _driverFormMessage == 'Driver account created.'
                                ? Colors.green
                                : Colors.red,
                          ),
                        ),
                      ),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _isCreatingDriver
                            ? null
                            : () => _createDriver(authService),
                        icon: _isCreatingDriver
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.person_add),
                        label: Text(
                          _isCreatingDriver ? 'Creating...' : 'Create driver',
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Expanded(
            child: FlutterMap(
              options: const MapOptions(
                initialCenter: LatLng(14.595, 120.980),
                initialZoom: 13.5,
              ),
              children: [
                ColoredBox(color: Colors.grey.shade200),
                const AppMapTileLayer(),
                MarkerLayer(
                  markers: allLocations.entries.map((entry) {
                    final isDriver = trackingService.isDriver(entry.key);
                    final displayName = trackingService.displayNameFor(
                      entry.key,
                    );
                    return Marker(
                      point: entry.value,
                      width: 80,
                      height: 80,
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
                            padding: const EdgeInsets.all(2),
                            color: Colors.white70,
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
          ),
        ],
      ),
    );
  }
}

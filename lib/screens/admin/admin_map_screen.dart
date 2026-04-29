import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';

import '../../core/map_camera_animator.dart';
import '../../services/firebase_auth_service.dart';
import '../../services/firebase_tracking_service.dart';
import '../../widgets/app_map_tile_layer.dart';
import '../../widgets/map_recenter_button.dart';
import '../../widgets/tracking_diagnostics_sheet.dart';

const Color _adminThemeColor = Color(0xFF1A237E);
const Color _driverThemeColor = Color(0xFF0D47A1);
const Color _studentThemeColor = Color(0xFF212121);

class AdminMapScreen extends StatefulWidget {
  const AdminMapScreen({super.key});

  @override
  State<AdminMapScreen> createState() => _AdminMapScreenState();
}

class _AdminMapScreenState extends State<AdminMapScreen>
    with TickerProviderStateMixin {
  static const LatLng _dagupanCenter = LatLng(16.0433, 120.3333);
  static const double _dagupanZoom = 12.5;

  final MapController _mapController = MapController();
  late final MapCameraAnimator _cameraAnimator;

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

  void _recenterToDagupan() {
    _cameraAnimator.animateTo(_dagupanCenter, _dagupanZoom);
  }

  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<FirebaseAuthService>(context);
    final trackingService = Provider.of<FirebaseTrackingService>(context);
    final adminUser = authService.currentUser;
    final allLocations = trackingService.getAllLocations();
    final liveUsers = allLocations.entries.toList()
      ..sort((a, b) {
        final aIsDriver = trackingService.isDriver(a.key);
        final bIsDriver = trackingService.isDriver(b.key);
        if (aIsDriver != bIsDriver) return aIsDriver ? -1 : 1;
        return trackingService
            .displayNameFor(a.key)
            .compareTo(trackingService.displayNameFor(b.key));
      });
    final driverCount = liveUsers
        .where((entry) => trackingService.isDriver(entry.key))
        .length;
    final studentCount = liveUsers
        .where((entry) => trackingService.isStudent(entry.key))
        .length;
    final liveDataStatusMessage = trackingService.liveDataStatusMessage;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Live Map'),
        backgroundColor: _adminThemeColor,
        foregroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/admin'),
        ),
        actions: [
          if (kDebugMode && adminUser != null)
            IconButton(
              icon: const Icon(Icons.bug_report),
              tooltip: 'Tracking diagnostics',
              onPressed: () => showTrackingDiagnosticsSheet(
                context: context,
                trackingService: trackingService,
                userId: adminUser.id,
                roleLabel: 'Admin',
              ),
            ),
        ],
      ),
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: const MapOptions(
              initialCenter: _dagupanCenter,
              initialZoom: _dagupanZoom,
            ),
            children: [
              ColoredBox(color: Colors.grey.shade200),
              const AppMapTileLayer(),
              MarkerLayer(
                markers: liveUsers.map((entry) {
                  final isDriver = trackingService.isDriver(entry.key);
                  final displayName = trackingService.displayNameFor(entry.key);
                  final isFresh = trackingService.isLocationFresh(entry.key);
                  final freshnessLabel = trackingService
                      .locationFreshnessLabel(entry.key)
                      .replaceFirst('Updated ', '');

                  return Marker(
                    point: entry.value,
                    width: 112,
                    height: 104,
                    child: _AdminUserMarker(
                      displayName: displayName,
                      freshnessLabel: freshnessLabel,
                      isDriver: isDriver,
                      isFresh: isFresh,
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
          Positioned(
            left: 12,
            right: 12,
            top: 12,
            child: _AdminMapSummaryCard(
              studentCount: studentCount,
              driverCount: driverCount,
              statusMessage: liveDataStatusMessage,
            ),
          ),
          MapRecenterButton(
            enabled: true,
            color: _adminThemeColor,
            heroTag: 'admin-recenter-dagupan',
            alignment: Alignment.topRight,
            padding: const EdgeInsets.only(top: 88, right: 16),
            onPressed: _recenterToDagupan,
          ),
          _AdminLiveUsersBottomSheet(
            liveUsers: liveUsers,
            trackingService: trackingService,
            statusMessage: liveDataStatusMessage,
            onTapUser: (location) => _cameraAnimator.animateTo(location, 16.0),
          ),
        ],
      ),
    );
  }
}

class _AdminMapSummaryCard extends StatelessWidget {
  const _AdminMapSummaryCard({
    required this.studentCount,
    required this.driverCount,
    required this.statusMessage,
  });

  final int studentCount;
  final int driverCount;
  final String? statusMessage;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.94),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            const Icon(Icons.admin_panel_settings, color: _adminThemeColor),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '$studentCount students • $driverCount drivers live',
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                  if (statusMessage != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      statusMessage!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.grey.shade700,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AdminUserMarker extends StatelessWidget {
  const _AdminUserMarker({
    required this.displayName,
    required this.freshnessLabel,
    required this.isDriver,
    required this.isFresh,
  });

  final String displayName;
  final String freshnessLabel;
  final bool isDriver;
  final bool isFresh;

  @override
  Widget build(BuildContext context) {
    final color = isDriver ? _driverThemeColor : _studentThemeColor;

    return Opacity(
      opacity: isFresh ? 1 : 0.58,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isDriver ? Icons.directions_bus : Icons.person_pin_circle,
            color: color,
            size: 42,
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.9),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: color.withValues(alpha: 0.18)),
            ),
            child: Text(
              displayName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
            ),
          ),
          Text(
            freshnessLabel,
            style: const TextStyle(
              color: Colors.black87,
              fontSize: 10,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _AdminLiveUsersBottomSheet extends StatefulWidget {
  const _AdminLiveUsersBottomSheet({
    required this.liveUsers,
    required this.trackingService,
    required this.statusMessage,
    required this.onTapUser,
  });

  final List<MapEntry<String, LatLng>> liveUsers;
  final FirebaseTrackingService trackingService;
  final String? statusMessage;
  final ValueChanged<LatLng> onTapUser;

  @override
  State<_AdminLiveUsersBottomSheet> createState() =>
      _AdminLiveUsersBottomSheetState();
}

class _AdminLiveUsersBottomSheetState
    extends State<_AdminLiveUsersBottomSheet> {
  static const double _collapsedSize = 0.12;
  static const double _defaultSize = 0.24;
  static const double _expandedSize = 0.55;

  final DraggableScrollableController _sheetController =
      DraggableScrollableController();
  bool _isExpanded = false;

  @override
  void initState() {
    super.initState();
    _sheetController.addListener(_syncExpandedState);
  }

  @override
  void dispose() {
    _sheetController.removeListener(_syncExpandedState);
    _sheetController.dispose();
    super.dispose();
  }

  void _syncExpandedState() {
    if (!_sheetController.isAttached) return;
    final nextIsExpanded = _sheetController.size > 0.36;
    if (nextIsExpanded == _isExpanded) return;
    setState(() {
      _isExpanded = nextIsExpanded;
    });
  }

  void _toggleSheet() {
    if (!_sheetController.isAttached) return;
    _sheetController.animateTo(
      _isExpanded ? _collapsedSize : _expandedSize,
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      controller: _sheetController,
      initialChildSize: _defaultSize,
      minChildSize: _collapsedSize,
      maxChildSize: _expandedSize,
      snap: true,
      snapSizes: const [_collapsedSize, _defaultSize, _expandedSize],
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
              Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: _toggleSheet,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 10, 12, 8),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Live Users',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                widget.statusMessage ??
                                    (_isExpanded
                                        ? 'Tap to collapse'
                                        : 'Tap to expand'),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: Colors.grey.shade600,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Text(
                          '${widget.liveUsers.length}',
                          style: TextStyle(
                            color: Colors.grey.shade700,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Icon(
                          _isExpanded
                              ? Icons.keyboard_arrow_down
                              : Icons.keyboard_arrow_up,
                          color: Colors.grey.shade700,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              Expanded(
                child: widget.liveUsers.isEmpty
                    ? ListView(
                        controller: scrollController,
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                        children: [
                          Center(
                            child: Text(
                              widget.statusMessage ??
                                  'No users sharing location.',
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ],
                      )
                    : ListView.separated(
                        controller: scrollController,
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                        itemCount: widget.liveUsers.length,
                        separatorBuilder: (context, index) =>
                            const Divider(height: 1),
                        itemBuilder: (context, index) {
                          final entry = widget.liveUsers[index];
                          final isDriver = widget.trackingService.isDriver(
                            entry.key,
                          );
                          final color = isDriver
                              ? _driverThemeColor
                              : _studentThemeColor;
                          final accuracy = widget.trackingService
                              .getAccuracyMeters(entry.key);
                          final accuracyLabel = accuracy == null
                              ? 'Accuracy unavailable'
                              : '${accuracy.round()} m accuracy';

                          return ListTile(
                            dense: true,
                            contentPadding: EdgeInsets.zero,
                            onTap: () => widget.onTapUser(entry.value),
                            leading: Icon(
                              isDriver
                                  ? Icons.directions_bus
                                  : Icons.person_pin_circle,
                              color: color,
                            ),
                            title: Text(
                              widget.trackingService.displayNameFor(entry.key),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            subtitle: Text(
                              '${isDriver ? 'Driver' : 'Student'} • $accuracyLabel • ${widget.trackingService.locationFreshnessLabel(entry.key)}',
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

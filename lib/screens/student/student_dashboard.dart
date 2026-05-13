import 'dart:async';

import 'package:geolocator/geolocator.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';
import '../../core/app_routes.dart';
import '../../core/map_camera_animator.dart';
import '../../services/firebase_auth_service.dart';
import '../../services/firebase_tracking_service.dart';
import '../../widgets/app_map_tile_layer.dart';
import '../../widgets/map_recenter_button.dart';
import '../../widgets/tracking_diagnostics_sheet.dart';
import '../../widgets/tracking_status_widgets.dart';

const double _studentOverlayRadius = 18;
const Color _studentThemeColor = Color(0xFF212121);
const Color _driverThemeColor = Color(0xFF05056A);

class StudentDashboard extends StatefulWidget {
  const StudentDashboard({super.key});

  @override
  State<StudentDashboard> createState() => _StudentDashboardState();
}

class _StudentDashboardState extends State<StudentDashboard>
    with TickerProviderStateMixin {
  static const double _cameraMoveThresholdMeters = 2;
  static const double _offscreenIndicatorPadding = 18;
  static const double _offscreenIndicatorBottomInsetFraction = 0.14;

  final MapController _mapController = MapController();
  final ValueNotifier<int> _mapCameraTick = ValueNotifier<int>(0);
  late final MapCameraAnimator _cameraAnimator;
  Timer? _mapCameraThrottle;
  bool _hasCenteredMap = false;
  String? _followedDriverId;
  LatLng? _lastFollowedDriverLocation;

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
    _mapCameraThrottle?.cancel();
    _mapCameraTick.dispose();
    _cameraAnimator.dispose();
    super.dispose();
  }

  void _scheduleMapCameraTick() {
    if (_mapCameraThrottle?.isActive == true) {
      return;
    }

    _mapCameraTick.value++;
    _mapCameraThrottle = Timer(const Duration(milliseconds: 100), () {});
  }

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

  String _trackingStatusLabel({
    required bool isSharing,
    required bool isStarting,
    required LatLng? myLocation,
    required String? error,
  }) {
    if (error != null) return 'Location needs attention';
    if (isStarting) return 'Starting location...';
    if (isSharing && myLocation != null) return 'Sharing live';
    if (isSharing) return 'Waiting for GPS fix';
    return 'Not sharing';
  }

  IconData _trackingStatusIcon({
    required bool isSharing,
    required bool isStarting,
    required LatLng? myLocation,
    required String? error,
  }) {
    if (error != null) return Icons.error_outline;
    if (isStarting) return Icons.sync;
    if (isSharing && myLocation != null) return Icons.radio_button_checked;
    if (isSharing) return Icons.gps_fixed;
    return Icons.location_disabled;
  }

  Color _trackingStatusColor({
    required bool isSharing,
    required bool isStarting,
    required LatLng? myLocation,
    required String? error,
  }) {
    if (error != null) return Colors.red;
    if (isStarting || (isSharing && myLocation == null)) return Colors.orange;
    if (isSharing && myLocation != null) return Colors.green;
    return Colors.grey;
  }

  void _followDriver(String driverId, LatLng driverLocation) {
    setState(() {
      _followedDriverId = driverId;
      _lastFollowedDriverLocation = null;
    });
    _cameraAnimator.animateTo(driverLocation, 16.0);
  }

  void _stopFollowingDriver() {
    setState(() {
      _followedDriverId = null;
      _lastFollowedDriverLocation = null;
    });
  }

  void _recenterToStudentLocation(LatLng? studentLocation) {
    if (studentLocation == null) return;

    if (_followedDriverId != null || _lastFollowedDriverLocation != null) {
      setState(() {
        _followedDriverId = null;
        _lastFollowedDriverLocation = null;
      });
    }

    _cameraAnimator.animateTo(studentLocation, 16.0);
  }

  void _syncFollowedDriverCamera(LatLng? driverLocation) {
    if (driverLocation == null) return;
    final lastLocation = _lastFollowedDriverLocation;
    if (lastLocation != null) {
      final distance = Geolocator.distanceBetween(
        lastLocation.latitude,
        lastLocation.longitude,
        driverLocation.latitude,
        driverLocation.longitude,
      );
      if (distance < _cameraMoveThresholdMeters) return;
    }

    _lastFollowedDriverLocation = driverLocation;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _followedDriverId == null) return;
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

    final allLocations = trackingService.getAllLocations();
    final driverIds = trackingService.getDriverIds();
    final driverLocations = allLocations.entries
        .where((entry) => trackingService.isDriver(entry.key))
        .toList();
    final myLocation = trackingService.getLocation(user.id);
    final isSharing = trackingService.isSharingLocation(user.id);
    final isStarting = trackingService.isStartingLocationStream;
    final locationError = trackingService.locationError;
    final liveDataStatusMessage = trackingService.liveDataStatusMessage;
    final statusLabel = _trackingStatusLabel(
      isSharing: isSharing,
      isStarting: isStarting,
      myLocation: myLocation,
      error: locationError,
    );
    final statusIcon = _trackingStatusIcon(
      isSharing: isSharing,
      isStarting: isStarting,
      myLocation: myLocation,
      error: locationError,
    );
    final statusColor = _trackingStatusColor(
      isSharing: isSharing,
      isStarting: isStarting,
      myLocation: myLocation,
      error: locationError,
    );
    final followedDriverLocation = _followedDriverId == null
        ? null
        : trackingService.getLocation(_followedDriverId!);
    final followedDriverName = _followedDriverId == null
        ? null
        : trackingService.displayNameFor(_followedDriverId!);
    final mapCenter =
        myLocation ??
        (driverLocations.isEmpty ? null : driverLocations.first.value);
    if (!_hasCenteredMap && mapCenter != null) {
      _hasCenteredMap = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _cameraAnimator.jumpTo(mapCenter, 15.0);
      });
    }
    _syncFollowedDriverCamera(followedDriverLocation);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Student Dashboard'),
        actions: [
          if (kDebugMode)
            IconButton(
              icon: const Icon(Icons.bug_report),
              tooltip: 'Tracking diagnostics',
              onPressed: () => showTrackingDiagnosticsSheet(
                context: context,
                trackingService: trackingService,
                userId: user.id,
                roleLabel: 'Student',
              ),
            ),
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            tooltip: 'Account settings',
            onPressed: () => context.push(AppRoutes.accountSettings),
          ),
        ],
      ),
      body: mapCenter == null
          ? Stack(
              children: [
                Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 28),
                    child: Text(
                      isSharing || isStarting
                          ? 'Waiting for your GPS location...'
                          : 'Start sharing to show your location and nearby drivers.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey.shade700),
                    ),
                  ),
                ),
                Positioned(
                  left: 12,
                  right: 12,
                  top: 12,
                  child: _StudentMapControls(
                    studentName: user.name,
                    statusLabel: statusLabel,
                    statusIcon: statusIcon,
                    statusColor: statusColor,
                    isSharing: isSharing,
                    isStarting: isStarting,
                    onToggleSharing: () {
                      if (isSharing) {
                        trackingService.stopSharingLocation(user.id);
                      } else {
                        trackingService.startSharingLocation(user.id);
                      }
                    },
                  ),
                ),
                if (locationError != null)
                  Positioned(
                    left: 12,
                    right: 12,
                    top: 100,
                    child: TrackingErrorBanner(
                      message: locationError,
                      onRetry: () =>
                          trackingService.startSharingLocation(user.id),
                      onOpenAppSettings: trackingService.openAppSettings,
                      onOpenLocationSettings:
                          trackingService.openLocationSettings,
                    ),
                  ),
              ],
            )
          : Stack(
              children: [
                FlutterMap(
                  mapController: _mapController,
                  options: MapOptions(
                    initialCenter: mapCenter,
                    initialZoom: 15.0,
                    onPositionChanged: (camera, hasGesture) =>
                        _scheduleMapCameraTick(),
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
                                  color: _studentThemeColor,
                                  size: 40,
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.9),
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
                            width: 96,
                            height: 96,
                            child: _DriverMapMarker(
                              speedLabel: _speedLabel(
                                trackingService.getSpeedKmh(driver.key),
                              ),
                              freshnessLabel: trackingService
                                  .locationFreshnessLabel(driver.key),
                              isFollowed: driver.key == _followedDriverId,
                              isFresh: trackingService.isLocationFresh(
                                driver.key,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                _OffscreenDriverIndicators(
                  drivers: driverLocations,
                  followedDriverId: _followedDriverId,
                  mapController: _mapController,
                  cameraListenable: _mapCameraTick,
                  padding: _offscreenIndicatorPadding,
                  bottomInsetFraction: _offscreenIndicatorBottomInsetFraction,
                  onTapDriver: _followDriver,
                ),
                MapRecenterButton(
                  enabled: myLocation != null,
                  color: _studentThemeColor,
                  heroTag: 'student-recenter-location',
                  alignment: Alignment.topRight,
                  padding: EdgeInsets.only(
                    top: _followedDriverId == null ? 88 : 144,
                    right: 16,
                  ),
                  onPressed: () => _recenterToStudentLocation(myLocation),
                ),
                Positioned(
                  left: 12,
                  right: 12,
                  top: 12,
                  child: _StudentMapControls(
                    studentName: user.name,
                    statusLabel: statusLabel,
                    statusIcon: statusIcon,
                    statusColor: statusColor,
                    isSharing: isSharing,
                    isStarting: isStarting,
                    onToggleSharing: () {
                      if (isSharing) {
                        trackingService.stopSharingLocation(user.id);
                      } else {
                        trackingService.startSharingLocation(user.id);
                      }
                    },
                  ),
                ),
                if (_followedDriverId != null)
                  Positioned(
                    left: 12,
                    right: 12,
                    top: 86,
                    child: _FollowingDriverBanner(
                      driverName: followedDriverName ?? 'Driver',
                      hasLiveLocation: followedDriverLocation != null,
                      onStop: _stopFollowingDriver,
                    ),
                  ),
                if (trackingService.locationError != null)
                  Positioned(
                    left: 12,
                    right: 12,
                    top: _followedDriverId == null ? 86 : 142,
                    child: TrackingErrorBanner(
                      message: trackingService.locationError!,
                      onRetry: () =>
                          trackingService.startSharingLocation(user.id),
                      onOpenAppSettings: trackingService.openAppSettings,
                      onOpenLocationSettings:
                          trackingService.openLocationSettings,
                    ),
                  ),
                _DriversBottomSheet(
                  driverIds: driverIds,
                  myLocation: myLocation,
                  followedDriverId: _followedDriverId,
                  trackingService: trackingService,
                  liveDataStatusMessage: liveDataStatusMessage,
                  distanceLabel: _distanceLabel,
                  speedLabel: _speedLabel,
                  onFollowDriver: _followDriver,
                ),
              ],
            ),
    );
  }
}

class _DriverMapMarker extends StatelessWidget {
  const _DriverMapMarker({
    required this.speedLabel,
    required this.freshnessLabel,
    required this.isFollowed,
    required this.isFresh,
  });

  final String speedLabel;
  final String freshnessLabel;
  final bool isFollowed;
  final bool isFresh;

  @override
  Widget build(BuildContext context) {
    final color = isFollowed ? Colors.orange : _driverThemeColor;

    return Opacity(
      opacity: isFresh ? 1 : 0.58,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.directions_bus, color: color, size: isFollowed ? 46 : 40),
          DecoratedBox(
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.92),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: color.withValues(alpha: 0.35)),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
              child: Text(
                speedLabel,
                style: TextStyle(
                  color: color,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          Text(
            freshnessLabel.replaceFirst('Updated ', ''),
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

class _OffscreenDriverIndicators extends StatelessWidget {
  const _OffscreenDriverIndicators({
    required this.drivers,
    required this.followedDriverId,
    required this.mapController,
    required this.cameraListenable,
    required this.padding,
    required this.bottomInsetFraction,
    required this.onTapDriver,
  });

  final List<MapEntry<String, LatLng>> drivers;
  final String? followedDriverId;
  final MapController mapController;
  final Listenable cameraListenable;
  final double padding;
  final double bottomInsetFraction;
  final void Function(String driverId, LatLng driverLocation) onTapDriver;

  @override
  Widget build(BuildContext context) {
    if (drivers.isEmpty) {
      return const SizedBox.shrink();
    }

    return AnimatedBuilder(
      animation: cameraListenable,
      builder: (context, child) {
        return LayoutBuilder(
          builder: (context, constraints) {
            if (!constraints.hasBoundedWidth || !constraints.hasBoundedHeight) {
              return const SizedBox.shrink();
            }

            final camera = mapController.camera;
            final bounds = camera.visibleBounds;
            final width = constraints.maxWidth;
            final height = constraints.maxHeight;
            final bottomLimit =
                height - (height * bottomInsetFraction) - padding;
            final indicators = <Widget>[];

            for (final driver in drivers) {
              if (bounds.contains(driver.value)) {
                continue;
              }

              final screenOffset = camera.latLngToScreenOffset(driver.value);
              final x = screenOffset.dx.clamp(padding, width - padding);
              final y = screenOffset.dy.clamp(padding, bottomLimit);
              final isFollowed = driver.key == followedDriverId;

              indicators.add(
                Positioned(
                  left: x - 22,
                  top: y - 22,
                  child: _OffscreenDriverIndicator(
                    isFollowed: isFollowed,
                    onTap: () => onTapDriver(driver.key, driver.value),
                  ),
                ),
              );
            }

            if (indicators.isEmpty) {
              return const SizedBox.shrink();
            }

            return Stack(children: indicators);
          },
        );
      },
    );
  }
}

class _OffscreenDriverIndicator extends StatelessWidget {
  const _OffscreenDriverIndicator({
    required this.isFollowed,
    required this.onTap,
  });

  final bool isFollowed;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = isFollowed ? Colors.orange : _driverThemeColor;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onTap,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.94),
            shape: BoxShape.circle,
            border: Border.all(color: color, width: 2),
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
            child: Icon(Icons.directions_bus, color: color, size: 28),
          ),
        ),
      ),
    );
  }
}

class _StudentMapControls extends StatelessWidget {
  const _StudentMapControls({
    required this.studentName,
    required this.statusLabel,
    required this.statusIcon,
    required this.statusColor,
    required this.isSharing,
    required this.isStarting,
    required this.onToggleSharing,
  });

  final String studentName;
  final String statusLabel;
  final IconData statusIcon;
  final Color statusColor;
  final bool isSharing;
  final bool isStarting;
  final VoidCallback onToggleSharing;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.94),
        borderRadius: BorderRadius.circular(_studentOverlayRadius),
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
            const Icon(Icons.person, color: _studentThemeColor),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    studentName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 5),
                  TrackingStatusPill(
                    label: statusLabel,
                    icon: statusIcon,
                    color: statusColor,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            FilledButton.icon(
              style: isSharing
                  ? FilledButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                    )
                  : null,
              onPressed: isStarting ? null : onToggleSharing,
              icon: isStarting
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Icon(
                      isSharing ? Icons.location_disabled : Icons.my_location,
                      size: 18,
                    ),
              label: Text(isSharing ? 'Stop' : 'Share'),
            ),
          ],
        ),
      ),
    );
  }
}

class _DriversBottomSheet extends StatefulWidget {
  const _DriversBottomSheet({
    required this.driverIds,
    required this.myLocation,
    required this.followedDriverId,
    required this.trackingService,
    required this.liveDataStatusMessage,
    required this.distanceLabel,
    required this.speedLabel,
    required this.onFollowDriver,
  });

  final List<String> driverIds;
  final LatLng? myLocation;
  final String? followedDriverId;
  final FirebaseTrackingService trackingService;
  final String? liveDataStatusMessage;
  final String Function(LatLng? from, LatLng? to) distanceLabel;
  final String Function(double? speedKmh) speedLabel;
  final void Function(String driverId, LatLng driverLocation) onFollowDriver;

  @override
  State<_DriversBottomSheet> createState() => _DriversBottomSheetState();
}

class _DriversBottomSheetState extends State<_DriversBottomSheet> {
  static const double _collapsedSize = 0.12;
  static const double _defaultSize = 0.22;
  static const double _expandedSize = 0.48;

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
    final nextIsExpanded = _sheetController.size > 0.34;
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
                                'Drivers Online',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                widget.liveDataStatusMessage ??
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
                          '${widget.driverIds.length}',
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
                child: widget.driverIds.isEmpty
                    ? ListView(
                        controller: scrollController,
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                        children: [
                          Center(
                            child: Text(
                              widget.liveDataStatusMessage ??
                                  'No drivers available yet.',
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ],
                      )
                    : ListView.separated(
                        controller: scrollController,
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                        itemCount: widget.driverIds.length,
                        separatorBuilder: (context, index) =>
                            const Divider(height: 1),
                        itemBuilder: (context, index) {
                          final driverId = widget.driverIds[index];
                          final driverLocation = widget.trackingService
                              .getLocation(driverId);
                          final driverSpeedKmh = widget.trackingService
                              .getSpeedKmh(driverId);
                          final freshnessLabel = widget.trackingService
                              .locationFreshnessLabel(driverId);
                          final isFresh = widget.trackingService
                              .isLocationFresh(driverId);

                          return ListTile(
                            dense: true,
                            contentPadding: EdgeInsets.zero,
                            enabled: driverLocation != null,
                            onTap: driverLocation == null
                                ? null
                                : () => widget.onFollowDriver(
                                    driverId,
                                    driverLocation,
                                  ),
                            leading: Icon(
                              Icons.directions_bus,
                              color: driverId == widget.followedDriverId
                                  ? Colors.orange
                                  : isFresh
                                  ? _driverThemeColor
                                  : Colors.grey,
                            ),
                            title: Text(
                              widget.trackingService.displayNameFor(driverId),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            subtitle: Text(
                              '${widget.distanceLabel(widget.myLocation, driverLocation)} • ${widget.speedLabel(driverSpeedKmh)} • $freshnessLabel',
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

class _FollowingDriverBanner extends StatelessWidget {
  const _FollowingDriverBanner({
    required this.driverName,
    required this.hasLiveLocation,
    required this.onStop,
  });

  final String driverName;
  final bool hasLiveLocation;
  final VoidCallback onStop;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.94),
        borderRadius: BorderRadius.circular(_studentOverlayRadius),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.14),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
        child: Row(
          children: [
            Icon(
              hasLiveLocation ? Icons.navigation : Icons.location_off,
              color: hasLiveLocation ? Colors.orange : Colors.grey,
              size: 20,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                hasLiveLocation
                    ? 'Following $driverName'
                    : 'Waiting for $driverName location',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            TextButton(onPressed: onStop, child: const Text('Stop')),
          ],
        ),
      ),
    );
  }
}

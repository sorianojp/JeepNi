import 'dart:async';

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
import '../../widgets/map_recenter_button.dart';
import '../../widgets/tracking_status_widgets.dart';

const double _driverOverlayRadius = 18;

class _StudentCluster {
  _StudentCluster(this.center, this.count, this.updatedAt);

  LatLng center;
  int count;
  DateTime? updatedAt;

  void add(LatLng point, DateTime? pointUpdatedAt) {
    center = LatLng(
      ((center.latitude * count) + point.latitude) / (count + 1),
      ((center.longitude * count) + point.longitude) / (count + 1),
    );
    count += 1;
    if (updatedAt == null ||
        (pointUpdatedAt != null && pointUpdatedAt.isAfter(updatedAt!))) {
      updatedAt = pointUpdatedAt;
    }
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
  static const double _offscreenIndicatorBottomInsetFraction = 0.14;

  final MapController _mapController = MapController();
  final ValueNotifier<int> _mapCameraTick = ValueNotifier<int>(0);
  late final MapCameraAnimator _cameraAnimator;
  Timer? _mapCameraThrottle;
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

  String _trackingStatusLabel({
    required bool isSharing,
    required bool isStarting,
    required LatLng? myLocation,
    required String? error,
  }) {
    if (error != null) return 'Location needs attention';
    if (isStarting) return 'Starting tracking...';
    if (isSharing && myLocation != null) return 'Sharing live';
    if (isSharing) return 'Waiting for GPS fix';
    return 'Starting tracking...';
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
    return Icons.sync;
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
    return Colors.orange;
  }

  List<_StudentCluster> _clusterStudents(
    Iterable<MapEntry<String, LatLng>> students,
    FirebaseTrackingService trackingService,
  ) {
    final clusters = <_StudentCluster>[];

    for (final student in students) {
      final point = student.value;
      final updatedAt = trackingService.getLocationUpdatedAt(student.key);
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
        clusters.add(_StudentCluster(point, 1, updatedAt));
      } else {
        nearestCluster.add(point, updatedAt);
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

  void _recenterToDriverLocation(LatLng? driverLocation) {
    if (driverLocation == null) return;
    _lastFollowedLocation = driverLocation;
    _cameraAnimator.animateTo(driverLocation, 16.0);
  }

  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<FirebaseAuthService>(context);
    final trackingService = Provider.of<FirebaseTrackingService>(context);

    final user = authService.currentUser;
    if (user == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (trackingService.locationError == null ||
        trackingService.isSharingLocation(user.id) ||
        trackingService.isStartingLocationStream) {
      trackingService.startSharingLocation(user.id);
    }

    final myLocation = trackingService.getLocation(user.id);
    final speedKmh = trackingService.getSpeedKmh(user.id);
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
    final allLocations = trackingService.getAllLocations();

    final studentsLocations = allLocations.entries
        .where((entry) => trackingService.isStudent(entry.key))
        .toList();
    final studentClusters = _clusterStudents(
      studentsLocations,
      trackingService,
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
          ? Stack(
              children: [
                Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 28),
                    child: Text(
                      locationError == null
                          ? 'Waiting for your GPS location...'
                          : 'Location access needs attention before live tracking can start.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey.shade700),
                    ),
                  ),
                ),
                Positioned(
                  left: 12,
                  right: 12,
                  top: 12,
                  child: _DriverMapControls(
                    driverName: user.name,
                    speedLabel: _speedLabel(speedKmh),
                    statusLabel: statusLabel,
                    statusIcon: statusIcon,
                    statusColor: statusColor,
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
                    initialZoom: 14.0,
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
                            height: 92,
                            child: _StudentClusterMarker(
                              count: cluster.count,
                              isFresh: trackingService.isFreshUpdatedAt(
                                cluster.updatedAt,
                              ),
                              freshnessLabel: trackingService.freshnessLabelFor(
                                cluster.updatedAt,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                _OffscreenStudentIndicators(
                  clusters: studentClusters,
                  mapController: _mapController,
                  cameraListenable: _mapCameraTick,
                  padding: _offscreenIndicatorPadding,
                  bottomInsetFraction: _offscreenIndicatorBottomInsetFraction,
                  onTapCluster: (cluster) {
                    _cameraAnimator.animateTo(cluster.center, 16.0);
                  },
                ),
                MapRecenterButton(
                  enabled: myLocation != null,
                  color: Colors.green,
                  heroTag: 'driver-recenter-location',
                  onPressed: () => _recenterToDriverLocation(myLocation),
                ),
                Positioned(
                  left: 12,
                  right: 12,
                  top: 12,
                  child: _DriverMapControls(
                    driverName: user.name,
                    speedLabel: _speedLabel(speedKmh),
                    statusLabel: statusLabel,
                    statusIcon: statusIcon,
                    statusColor: statusColor,
                  ),
                ),
                if (trackingService.locationError != null)
                  Positioned(
                    left: 12,
                    right: 12,
                    top: 86,
                    child: TrackingErrorBanner(
                      message: trackingService.locationError!,
                      onRetry: () =>
                          trackingService.startSharingLocation(user.id),
                      onOpenAppSettings: trackingService.openAppSettings,
                      onOpenLocationSettings:
                          trackingService.openLocationSettings,
                    ),
                  ),
                _StudentClustersBottomSheet(
                  clusters: studentClusters,
                  driverLocation: myLocation,
                  trackingService: trackingService,
                  liveDataStatusMessage: liveDataStatusMessage,
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
    required this.statusLabel,
    required this.statusIcon,
    required this.statusColor,
  });

  final String driverName;
  final String speedLabel;
  final String statusLabel;
  final IconData statusIcon;
  final Color statusColor;

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
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    driverName,
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

class _StudentClustersBottomSheet extends StatefulWidget {
  const _StudentClustersBottomSheet({
    required this.clusters,
    required this.driverLocation,
    required this.trackingService,
    required this.liveDataStatusMessage,
    required this.distanceLabel,
    required this.onTapCluster,
  });

  final List<_StudentCluster> clusters;
  final LatLng? driverLocation;
  final FirebaseTrackingService trackingService;
  final String? liveDataStatusMessage;
  final String Function(LatLng? from, LatLng to) distanceLabel;
  final ValueChanged<_StudentCluster> onTapCluster;

  @override
  State<_StudentClustersBottomSheet> createState() =>
      _StudentClustersBottomSheetState();
}

class _StudentClustersBottomSheetState
    extends State<_StudentClustersBottomSheet> {
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
                                'Students Waiting',
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
                          '${widget.clusters.fold<int>(0, (total, cluster) => total + cluster.count)}',
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
                child: widget.clusters.isEmpty
                    ? ListView(
                        controller: scrollController,
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                        children: [
                          Center(
                            child: Text(
                              widget.liveDataStatusMessage ??
                                  'No students sharing location.',
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ],
                      )
                    : ListView.separated(
                        controller: scrollController,
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                        itemCount: widget.clusters.length,
                        separatorBuilder: (context, index) =>
                            const Divider(height: 1),
                        itemBuilder: (context, index) {
                          final cluster = widget.clusters[index];
                          final title = cluster.count == 1
                              ? '1 student Waiting'
                              : '${cluster.count} students Waiting';
                          final isFresh = widget.trackingService
                              .isFreshUpdatedAt(cluster.updatedAt);

                          return ListTile(
                            dense: true,
                            contentPadding: EdgeInsets.zero,
                            onTap: () => widget.onTapCluster(cluster),
                            leading: Icon(
                              Icons.person_pin_circle,
                              color: isFresh ? Colors.blue : Colors.grey,
                            ),
                            title: Text(title),
                            subtitle: Text(
                              '${widget.distanceLabel(widget.driverLocation, cluster.center)} • ${widget.trackingService.freshnessLabelFor(cluster.updatedAt)}',
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
    required this.cameraListenable,
    required this.padding,
    required this.bottomInsetFraction,
    required this.onTapCluster,
  });

  final List<_StudentCluster> clusters;
  final MapController mapController;
  final Listenable cameraListenable;
  final double padding;
  final double bottomInsetFraction;
  final ValueChanged<_StudentCluster> onTapCluster;

  @override
  Widget build(BuildContext context) {
    if (clusters.isEmpty) {
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

            for (final cluster in clusters) {
              if (bounds.contains(cluster.center)) {
                continue;
              }

              final screenOffset = camera.latLngToScreenOffset(cluster.center);
              final x = screenOffset.dx.clamp(padding, width - padding);
              final y = screenOffset.dy.clamp(padding, bottomLimit);

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
  const _StudentClusterMarker({
    required this.count,
    required this.isFresh,
    required this.freshnessLabel,
  });

  final int count;
  final bool isFresh;
  final String freshnessLabel;

  @override
  Widget build(BuildContext context) {
    if (count == 1) {
      return Opacity(
        opacity: isFresh ? 1 : 0.58,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.person_pin_circle, color: Colors.blue, size: 30),
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

    return Opacity(
      opacity: isFresh ? 1 : 0.58,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Stack(
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

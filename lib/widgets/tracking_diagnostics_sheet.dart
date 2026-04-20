import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';

import '../services/firebase_tracking_service.dart';

void showTrackingDiagnosticsSheet({
  required BuildContext context,
  required FirebaseTrackingService trackingService,
  required String userId,
  required String roleLabel,
}) {
  showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (context) {
      return AnimatedBuilder(
        animation: trackingService,
        builder: (context, child) {
          final location = trackingService.getLocation(userId);
          final accuracyMeters = trackingService.getAccuracyMeters(userId);
          final speedKmh = trackingService.getSpeedKmh(userId);
          final updatedAt = trackingService.getLocationUpdatedAt(userId);
          final liveDataStatus =
              trackingService.liveDataStatusMessage ?? 'Live data connected';

          return SafeArea(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(18, 0, 18, 24),
              shrinkWrap: true,
              children: [
                const Text(
                  'Tracking diagnostics',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 4),
                Text(
                  'Debug-only info for road testing.',
                  style: TextStyle(color: Colors.grey.shade600),
                ),
                const SizedBox(height: 16),
                _DiagnosticsRow(label: 'Role', value: roleLabel),
                _DiagnosticsRow(
                  label: 'Sharing',
                  value: trackingService.isSharingLocation(userId)
                      ? 'Yes'
                      : 'No',
                ),
                _DiagnosticsRow(
                  label: 'Starting stream',
                  value: trackingService.isStartingLocationStream
                      ? 'Yes'
                      : 'No',
                ),
                _DiagnosticsRow(label: 'Live data', value: liveDataStatus),
                _DiagnosticsRow(
                  label: 'Cached data',
                  value: trackingService.isUsingCachedData ? 'Yes' : 'No',
                ),
                _DiagnosticsRow(
                  label: 'Location error',
                  value: trackingService.locationError ?? 'None',
                ),
                _DiagnosticsRow(
                  label: 'Data error',
                  value: trackingService.dataConnectionError ?? 'None',
                ),
                const Divider(height: 28),
                _DiagnosticsRow(
                  label: 'Coordinates',
                  value: _locationLabel(location),
                ),
                _DiagnosticsRow(
                  label: 'Accuracy',
                  value: accuracyMeters == null
                      ? 'Unavailable'
                      : '${accuracyMeters.round()} m',
                ),
                _DiagnosticsRow(
                  label: 'Speed',
                  value: speedKmh == null
                      ? 'Unavailable'
                      : '${speedKmh.toStringAsFixed(1)} km/h',
                ),
                _DiagnosticsRow(
                  label: 'Last update',
                  value: trackingService.freshnessLabelFor(updatedAt),
                ),
              ],
            ),
          );
        },
      );
    },
  );
}

String _locationLabel(LatLng? location) {
  if (location == null) return 'Unavailable';
  return '${location.latitude.toStringAsFixed(6)}, '
      '${location.longitude.toStringAsFixed(6)}';
}

class _DiagnosticsRow extends StatelessWidget {
  const _DiagnosticsRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: TextStyle(
                color: Colors.grey.shade600,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}

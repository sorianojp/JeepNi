import 'package:cloud_firestore/cloud_firestore.dart';

class EJeepSchedule {
  const EJeepSchedule({
    required this.id,
    required this.ejeepName,
    required this.route,
    required this.dayRange,
    required this.startTime,
    required this.endTime,
    required this.isActive,
    this.notes = '',
  });

  final String id;
  final String ejeepName;
  final String route;
  final String dayRange;
  final String startTime;
  final String endTime;
  final bool isActive;
  final String notes;

  String get timeRangeLabel {
    if (endTime.isEmpty) return startTime;
    return '$startTime - $endTime';
  }

  factory EJeepSchedule.fromFirestore(String id, Map<String, dynamic> data) {
    return EJeepSchedule(
      id: id,
      ejeepName: data['ejeepName'] as String? ?? '',
      route: data['route'] as String? ?? '',
      dayRange: data['dayRange'] as String? ?? data['day'] as String? ?? '',
      startTime:
          data['startTime'] as String? ??
          data['departureTime'] as String? ??
          '',
      endTime: data['endTime'] as String? ?? '',
      isActive: data['isActive'] as bool? ?? true,
      notes: data['notes'] as String? ?? '',
    );
  }

  Map<String, Object?> toFirestore() {
    return {
      'ejeepName': ejeepName,
      'route': route,
      'dayRange': dayRange,
      'startTime': startTime,
      'endTime': endTime,
      'isActive': isActive,
      'notes': notes,
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }
}

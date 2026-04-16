import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:latlong2/latlong.dart';

enum UserRole { student, driver, admin }

UserRole userRoleFromValue(Object? value) {
  switch (value?.toString().toLowerCase()) {
    case 'student':
      return UserRole.student;
    case 'driver':
      return UserRole.driver;
    case 'admin':
      return UserRole.admin;
    default:
      return UserRole.student;
  }
}

LatLng? latLngFromValue(Object? value) {
  if (value is LatLng) return value;
  if (value is GeoPoint) {
    return LatLng(value.latitude, value.longitude);
  }
  if (value is Map) {
    final latitude = value['latitude'];
    final longitude = value['longitude'];
    if (latitude is num && longitude is num) {
      return LatLng(latitude.toDouble(), longitude.toDouble());
    }
  }
  return null;
}

class UserModel {
  final String id;
  final String email;
  final String name;
  final UserRole role;
  LatLng? location;
  
  // Specific to driver - which route they are on
  final String? routeId;
  
  // Specific to student - which driver they are waiting for / riding with
  final String? assignedDriverId;

  UserModel({
    required this.id,
    required this.email,
    required this.name,
    required this.role,
    this.location,
    this.routeId,
    this.assignedDriverId,
  });

  UserModel copyWith({
    String? id,
    String? email,
    String? name,
    UserRole? role,
    LatLng? location,
    String? routeId,
    String? assignedDriverId,
  }) {
    return UserModel(
      id: id ?? this.id,
      email: email ?? this.email,
      name: name ?? this.name,
      role: role ?? this.role,
      location: location ?? this.location,
      routeId: routeId ?? this.routeId,
      assignedDriverId: assignedDriverId ?? this.assignedDriverId,
    );
  }

  factory UserModel.fromFirestore(String id, Map<String, dynamic> data) {
    return UserModel(
      id: id,
      email: data['email'] as String? ?? '',
      name: data['name'] as String? ?? id,
      role: userRoleFromValue(data['role']),
      location: latLngFromValue(data['location']),
      routeId: data['routeId'] as String?,
      assignedDriverId: data['assignedDriverId'] as String?,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'email': email,
      'name': name,
      'role': role.name,
      'location': location == null
          ? null
          : {
              'latitude': location!.latitude,
              'longitude': location!.longitude,
            },
      'routeId': routeId,
      'assignedDriverId': assignedDriverId,
    };
  }
}

import 'package:cloud_firestore/cloud_firestore.dart';

class RouteModel {
  final String id;
  final String name;
  final String? description;
  final String? driverId;

  const RouteModel({
    required this.id,
    required this.name,
    this.description,
    this.driverId,
  });

  factory RouteModel.fromFirestore(String id, Map<String, dynamic> data) {
    return RouteModel(
      id: id,
      name: data['name'] as String? ?? id,
      description: data['description'] as String?,
      driverId: data['driverId'] as String?,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'description': description,
      'driverId': driverId,
    };
  }

  factory RouteModel.fromSnapshot(DocumentSnapshot<Map<String, dynamic>> snapshot) {
    return RouteModel.fromFirestore(snapshot.id, snapshot.data() ?? const {});
  }
}

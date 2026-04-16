import 'package:latlong2/latlong.dart';

import '../models/user_model.dart';

class AppDefaults {
  const AppDefaults._();

  static const defaultRouteId = 'route_A';

  static const defaultRouteName = 'Route A';
  static const defaultRouteDescription = 'Main campus loop';

  static const Map<UserRole, LatLng> roleLocations = {
    UserRole.student: LatLng(14.5995, 120.9842),
    UserRole.driver: LatLng(14.59, 120.975),
    UserRole.admin: LatLng(14.595, 120.98),
  };
}

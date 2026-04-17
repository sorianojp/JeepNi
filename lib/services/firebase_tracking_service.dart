import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

class FirebaseTrackingService extends ChangeNotifier {
  static const Duration _heartbeatInterval = Duration(seconds: 30);
  static const Duration _staleLocationTimeout = Duration(minutes: 3);

  final Map<String, LatLng> _userLocations = <String, LatLng>{};
  final Map<String, String> _userNames = <String, String>{};
  final Map<String, double> _userSpeedsKmh = <String, double>{};
  final Map<String, DateTime> _userLocationUpdatedAt = <String, DateTime>{};
  final Set<String> _driverIds = <String>{};
  final Set<String> _studentIds = <String>{};

  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _usersSubscription;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _subscription;
  StreamSubscription<Position>? _positionSubscription;
  StreamSubscription<fb.User?>? _authSubscription;
  Timer? _heartbeatTimer;
  Position? _lastPosition;
  String? _sharingUserId;
  bool _isStartingLocationStream = false;
  String? _locationError;

  String? get locationError => _locationError;
  bool get isStartingLocationStream => _isStartingLocationStream;

  bool isSharingLocation(String userId) {
    return _positionSubscription != null && _sharingUserId == userId;
  }

  FirebaseTrackingService() {
    _authSubscription = fb.FirebaseAuth.instance.authStateChanges().listen((
      user,
    ) {
      if (user == null || user.uid != _sharingUserId) {
        _stopListening();
      }
    });
  }

  void _ensureListening() {
    if (fb.FirebaseAuth.instance.currentUser == null) {
      return;
    }

    _usersSubscription ??= FirebaseFirestore.instance
        .collection('users')
        .snapshots()
        .listen(
          (snapshot) {
            final nextDriverIds = <String>{};
            final nextStudentIds = <String>{};
            final nextUserNames = <String, String>{};

            for (final doc in snapshot.docs) {
              final data = doc.data();
              final role = data['role']?.toString().toLowerCase();
              final name = data['name']?.toString().trim();
              final email = data['email']?.toString().trim();
              nextUserNames[doc.id] = name?.isNotEmpty == true
                  ? name!
                  : email?.isNotEmpty == true
                  ? email!
                  : doc.id;

              if (role == 'driver') {
                nextDriverIds.add(doc.id);
              } else if (role == 'student') {
                nextStudentIds.add(doc.id);
              }
            }

            _driverIds
              ..clear()
              ..addAll(nextDriverIds);
            _studentIds
              ..clear()
              ..addAll(nextStudentIds);
            _userNames
              ..clear()
              ..addAll(nextUserNames);
            notifyListeners();
          },
          onError: (Object error) {
            debugPrint('Driver listener skipped: $error');
          },
        );

    _subscription ??= FirebaseFirestore.instance
        .collection('locations')
        .snapshots()
        .listen(
          (snapshot) {
            final nextLocations = <String, LatLng>{};
            final nextSpeedsKmh = <String, double>{};
            final nextUpdatedAt = <String, DateTime>{};
            final staleBefore = DateTime.now().subtract(_staleLocationTimeout);

            for (final doc in snapshot.docs) {
              final data = doc.data();
              final latitude = data['latitude'];
              final longitude = data['longitude'];
              final updatedAt = _updatedAtFromValue(data['updatedAt']);
              if (updatedAt == null || updatedAt.isBefore(staleBefore)) {
                continue;
              }

              if (latitude is num && longitude is num) {
                nextLocations[doc.id] = LatLng(
                  latitude.toDouble(),
                  longitude.toDouble(),
                );
                nextUpdatedAt[doc.id] = updatedAt;
                final speedKmh = data['speedKmh'];
                if (speedKmh is num) {
                  nextSpeedsKmh[doc.id] = speedKmh.toDouble();
                }
              }
            }

            _userLocations
              ..clear()
              ..addAll(nextLocations);
            _userSpeedsKmh
              ..clear()
              ..addAll(nextSpeedsKmh);
            _userLocationUpdatedAt
              ..clear()
              ..addAll(nextUpdatedAt);
            notifyListeners();
          },
          onError: (Object error) {
            debugPrint('Location listener skipped: $error');
          },
        );
  }

  void _stopListening() {
    _usersSubscription?.cancel();
    _usersSubscription = null;
    _subscription?.cancel();
    _subscription = null;
    _positionSubscription?.cancel();
    _positionSubscription = null;
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
    _lastPosition = null;
    _sharingUserId = null;
    _isStartingLocationStream = false;
    _driverIds.clear();
    _studentIds.clear();
    _userNames.clear();
    _userSpeedsKmh.clear();
    _userLocationUpdatedAt.clear();
    _userLocations.clear();
  }

  Future<void> startSharingLocation(String userId) async {
    _ensureListening();

    final currentUser = fb.FirebaseAuth.instance.currentUser;
    if (currentUser == null ||
        currentUser.uid != userId ||
        _isStartingLocationStream) {
      return;
    }

    if (_positionSubscription != null && _sharingUserId == userId) {
      return;
    }

    if (_positionSubscription != null && _sharingUserId != userId) {
      await _positionSubscription?.cancel();
      _positionSubscription = null;
      _heartbeatTimer?.cancel();
      _heartbeatTimer = null;
      _lastPosition = null;
    }

    _isStartingLocationStream = true;
    final hasPermission = await _ensureLocationPermission();
    if (!hasPermission) {
      _isStartingLocationStream = false;
      notifyListeners();
      return;
    }

    try {
      final currentPosition = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.bestForNavigation,
        ),
      );
      await _writePosition(userId, currentPosition);
    } catch (error) {
      debugPrint('Current location lookup failed: $error');
      final lastKnown = await Geolocator.getLastKnownPosition();
      if (lastKnown != null) {
        await _writePosition(userId, lastKnown);
      }
    }

    _positionSubscription =
        Geolocator.getPositionStream(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.bestForNavigation,
            distanceFilter: 3,
          ),
        ).listen(
          (position) => _writePosition(userId, position),
          onError: (Object error) {
            _locationError = error.toString();
            debugPrint('Location stream failed: $error');
            notifyListeners();
          },
        );
    _sharingUserId = userId;
    _heartbeatTimer?.cancel();
    _heartbeatTimer = Timer.periodic(_heartbeatInterval, (_) {
      final lastPosition = _lastPosition;
      final sharingUserId = _sharingUserId;
      if (lastPosition != null && sharingUserId == userId) {
        _writePosition(sharingUserId!, lastPosition);
      }
    });
    _isStartingLocationStream = false;
    notifyListeners();
  }

  Future<void> stopSharingLocation(String userId) async {
    final currentUser = fb.FirebaseAuth.instance.currentUser;
    if (currentUser?.uid != userId) {
      return;
    }

    if (_sharingUserId == userId) {
      await _positionSubscription?.cancel();
      _positionSubscription = null;
      _heartbeatTimer?.cancel();
      _heartbeatTimer = null;
      _lastPosition = null;
      _sharingUserId = null;
    }

    _userLocations.remove(userId);
    _userSpeedsKmh.remove(userId);
    _userLocationUpdatedAt.remove(userId);
    await FirebaseFirestore.instance
        .collection('locations')
        .doc(userId)
        .delete();
    notifyListeners();
  }

  Future<bool> _ensureLocationPermission() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      _locationError = 'Turn on Location Services to show your exact position.';
      return false;
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.denied) {
      _locationError = 'Location permission is required for accurate tracking.';
      return false;
    }

    if (permission == LocationPermission.deniedForever) {
      _locationError =
          'Enable location permission for JeepNi in system settings.';
      return false;
    }

    final accuracy = await Geolocator.getLocationAccuracy();
    if (accuracy == LocationAccuracyStatus.reduced) {
      _locationError = 'Enable Precise Location for better accuracy.';
    } else {
      _locationError = null;
    }

    return true;
  }

  Future<void> _writePosition(String userId, Position position) async {
    final nextLocation = LatLng(position.latitude, position.longitude);
    final speedKmh = position.speed <= 0 ? 0.0 : position.speed * 3.6;
    final now = DateTime.now();
    _lastPosition = position;
    _userLocations[userId] = nextLocation;
    _userSpeedsKmh[userId] = speedKmh;
    _userLocationUpdatedAt[userId] = now;
    await FirebaseFirestore.instance.collection('locations').doc(userId).set({
      'latitude': position.latitude,
      'longitude': position.longitude,
      'accuracyMeters': position.accuracy,
      'speedKmh': speedKmh,
      'updatedAt': FieldValue.serverTimestamp(),
    });
    notifyListeners();
  }

  LatLng? getLocation(String userId) {
    _ensureListening();
    return _userLocations[userId];
  }

  Map<String, LatLng> getAllLocations() {
    _ensureListening();
    return Map.unmodifiable(_userLocations);
  }

  bool isDriver(String userId) {
    _ensureListening();
    return _driverIds.contains(userId);
  }

  List<String> getDriverIds() {
    _ensureListening();
    return List.unmodifiable(_driverIds);
  }

  bool isStudent(String userId) {
    _ensureListening();
    return _studentIds.contains(userId);
  }

  String displayNameFor(String userId) {
    _ensureListening();
    return _userNames[userId] ?? userId;
  }

  double? getSpeedKmh(String userId) {
    _ensureListening();
    return _userSpeedsKmh[userId];
  }

  Future<void> updateLocation(String userId, LatLng newLocation) async {
    _ensureListening();
    _userLocations[userId] = newLocation;
    _userLocationUpdatedAt[userId] = DateTime.now();
    await FirebaseFirestore.instance.collection('locations').doc(userId).set({
      'latitude': newLocation.latitude,
      'longitude': newLocation.longitude,
      'updatedAt': FieldValue.serverTimestamp(),
    });
    notifyListeners();
  }

  DateTime? _updatedAtFromValue(Object? value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    return null;
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    _authSubscription = null;
    _stopListening();
    super.dispose();
  }
}

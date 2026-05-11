import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

class FirebaseTrackingService extends ChangeNotifier {
  static const Duration _freshnessTickInterval = Duration(seconds: 15);
  static const Duration _currentLocationTimeout = Duration(seconds: 12);
  static const Duration _staleLocationTimeout = Duration(minutes: 3);
  static const Duration _freshLocationDuration = Duration(seconds: 60);
  static const Duration _driverHeartbeatInterval = Duration(seconds: 10);
  static const Duration _studentHeartbeatInterval = Duration(seconds: 30);
  static const Duration _driverLiveUpdateInterval = Duration(seconds: 2);
  static const Duration _studentLiveUpdateInterval = Duration(seconds: 10);
  static const int _driverDistanceFilterMeters = 2;
  static const int _studentDistanceFilterMeters = 10;
  static const double _minimumMovingSpeedKmh = 1;
  static const double _maximumPlausibleSpeedKmh = 180;
  static const double _speedSmoothingFactor = 0.45;
  static const double _stationaryDistanceMeters = 3;
  static const Duration _stationarySpeedTimeout = Duration(seconds: 8);

  final Map<String, LatLng> _userLocations = <String, LatLng>{};
  final Map<String, String> _userNames = <String, String>{};
  final Map<String, double> _userSpeedsKmh = <String, double>{};
  final Map<String, double> _userAccuraciesMeters = <String, double>{};
  final Map<String, DateTime> _userLocationUpdatedAt = <String, DateTime>{};
  final Map<String, String> _userRoles = <String, String>{};
  final Map<String, _TrackedLocation> _visibleLocationCache =
      <String, _TrackedLocation>{};
  _TrackedLocation? _ownLocationCache;
  final Set<String> _driverIds = <String>{};
  final Set<String> _studentIds = <String>{};

  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>?
  _ownUserSubscription;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>?
  _visibleUsersSubscription;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>?
  _ownLocationSubscription;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>?
  _visibleLocationsSubscription;
  StreamSubscription<Position>? _positionSubscription;
  StreamSubscription<fb.User?>? _authSubscription;
  Timer? _heartbeatTimer;
  Timer? _freshnessTimer;
  Position? _lastPosition;
  Position? _lastMeaningfulMovementPosition;
  DateTime? _lastMeaningfulMovementAt;
  String? _sharingUserId;
  String? _listeningUserId;
  String? _listeningUserRole;
  bool _isStartingLocationStream = false;
  bool _isRefreshingCurrentPosition = false;
  bool _hasLoadedVisibleUsers = false;
  bool _hasLoadedVisibleLocations = false;
  bool _isUsingCachedVisibleUsers = false;
  bool _isUsingCachedVisibleLocations = false;
  String? _locationError;
  String? _dataConnectionError;

  String? get locationError => _locationError;
  String? get dataConnectionError => _dataConnectionError;
  bool get isStartingLocationStream => _isStartingLocationStream;
  bool get isLoadingVisibleData {
    _ensureListening();
    final role = _listeningUserRole;
    if (role == null) return true;

    final needsVisibleUsers = role == 'student' || role == 'admin';
    final usersLoaded = !needsVisibleUsers || _hasLoadedVisibleUsers;
    return !usersLoaded || !_hasLoadedVisibleLocations;
  }

  bool get isUsingCachedData {
    _ensureListening();
    return _isUsingCachedVisibleUsers || _isUsingCachedVisibleLocations;
  }

  String? get liveDataStatusMessage {
    _ensureListening();
    if (_dataConnectionError != null) {
      return _dataConnectionError;
    }
    if (isLoadingVisibleData) {
      return 'Loading live data...';
    }
    if (isUsingCachedData) {
      return 'Showing cached data. Check your internet if it does not update.';
    }
    return null;
  }

  bool isSharingLocation(String userId) {
    return _positionSubscription != null && _sharingUserId == userId;
  }

  Future<void> openAppSettings() async {
    await Geolocator.openAppSettings();
  }

  Future<void> openLocationSettings() async {
    await Geolocator.openLocationSettings();
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
    final authUser = fb.FirebaseAuth.instance.currentUser;
    if (authUser == null) {
      return;
    }

    if (_listeningUserId == authUser.uid) {
      return;
    }

    _stopListening();
    _listeningUserId = authUser.uid;
    _startOwnUserListener(authUser.uid);
    _startOwnLocationListener(authUser.uid);

    _freshnessTimer ??= Timer.periodic(_freshnessTickInterval, (_) {
      _refreshFreshnessState();
    });
  }

  void _startOwnUserListener(String userId) {
    _ownUserSubscription = FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .snapshots()
        .listen(
          (snapshot) {
            final data = snapshot.data();
            final role = _roleFromData(data);
            _applyUserProfile(snapshot.id, data, fallbackRole: role);

            if (_listeningUserRole != role) {
              _listeningUserRole = role;
              _startRoleScopedListeners(role);
            }

            _rebuildUserIndexes();
            notifyListeners();
          },
          onError: (Object error) {
            debugPrint('Own user listener skipped: $error');
          },
        );
  }

  void _startRoleScopedListeners(String role) {
    _visibleUsersSubscription?.cancel();
    _visibleUsersSubscription = null;
    _visibleLocationsSubscription?.cancel();
    _visibleLocationsSubscription = null;
    _visibleLocationCache.clear();
    _hasLoadedVisibleUsers = false;
    _hasLoadedVisibleLocations = false;
    _isUsingCachedVisibleUsers = false;
    _isUsingCachedVisibleLocations = false;
    _dataConnectionError = null;

    final firestore = FirebaseFirestore.instance;

    if (role == 'admin') {
      _visibleUsersSubscription = firestore
          .collection('users')
          .snapshots(includeMetadataChanges: true)
          .listen(
            _handleVisibleUsersSnapshot,
            onError: (Object error) {
              _handleDataConnectionError('User listener skipped', error);
            },
          );
      _visibleLocationsSubscription = firestore
          .collection('locations')
          .snapshots(includeMetadataChanges: true)
          .listen(
            _handleVisibleLocationsSnapshot,
            onError: (Object error) {
              _handleDataConnectionError('Location listener skipped', error);
            },
          );
      return;
    }

    if (role == 'student') {
      _visibleUsersSubscription = firestore
          .collection('users')
          .where('role', isEqualTo: 'driver')
          .snapshots(includeMetadataChanges: true)
          .listen(
            _handleVisibleUsersSnapshot,
            onError: (Object error) {
              _handleDataConnectionError(
                'Driver profile listener skipped',
                error,
              );
            },
          );
      _visibleLocationsSubscription = firestore
          .collection('locations')
          .where('role', isEqualTo: 'driver')
          .snapshots(includeMetadataChanges: true)
          .listen(
            _handleVisibleLocationsSnapshot,
            onError: (Object error) {
              _handleDataConnectionError(
                'Driver location listener skipped',
                error,
              );
            },
          );
      return;
    }

    if (role == 'driver') {
      _visibleLocationsSubscription = firestore
          .collection('locations')
          .where('role', isEqualTo: 'student')
          .snapshots(includeMetadataChanges: true)
          .listen(
            _handleVisibleLocationsSnapshot,
            onError: (Object error) {
              _handleDataConnectionError(
                'Student location listener skipped',
                error,
              );
            },
          );
    }
  }

  void _startOwnLocationListener(String userId) {
    _ownLocationSubscription = FirebaseFirestore.instance
        .collection('locations')
        .doc(userId)
        .snapshots()
        .listen(
          (snapshot) {
            final trackedLocation = _trackedLocationFromDoc(snapshot);
            if (trackedLocation != null) {
              _ownLocationCache = trackedLocation;
            } else if (!snapshot.exists) {
              _ownLocationCache = null;
            }
            _rebuildLocationsFromCaches();
            notifyListeners();
          },
          onError: (Object error) {
            debugPrint('Own location listener skipped: $error');
          },
        );
  }

  void _handleVisibleUsersSnapshot(
    QuerySnapshot<Map<String, dynamic>> snapshot,
  ) {
    _hasLoadedVisibleUsers = true;
    _isUsingCachedVisibleUsers = snapshot.metadata.isFromCache;
    _dataConnectionError = null;
    final nextUserNames = <String, String>{};
    final nextUserRoles = <String, String>{};

    for (final doc in snapshot.docs) {
      final data = doc.data();
      final role = _roleFromData(data);
      nextUserNames[doc.id] = _displayNameFromData(doc.id, data);
      nextUserRoles[doc.id] = role;
    }

    final ownUserId = _listeningUserId;
    final ownName = ownUserId == null ? null : _userNames[ownUserId];
    final ownRole = ownUserId == null ? null : _userRoles[ownUserId];

    _userNames
      ..clear()
      ..addAll(nextUserNames);
    _userRoles
      ..clear()
      ..addAll(nextUserRoles);

    if (ownUserId != null) {
      if (ownName != null) _userNames[ownUserId] = ownName;
      if (ownRole != null) _userRoles[ownUserId] = ownRole;
    }

    _rebuildUserIndexes();
    notifyListeners();
  }

  void _handleVisibleLocationsSnapshot(
    QuerySnapshot<Map<String, dynamic>> snapshot,
  ) {
    _hasLoadedVisibleLocations = true;
    _isUsingCachedVisibleLocations = snapshot.metadata.isFromCache;
    _dataConnectionError = null;
    final nextLocations = <String, _TrackedLocation>{};

    for (final doc in snapshot.docs) {
      final trackedLocation = _trackedLocationFromDoc(doc);
      if (trackedLocation != null) {
        nextLocations[doc.id] = trackedLocation;
      }
    }

    _visibleLocationCache
      ..clear()
      ..addAll(nextLocations);
    _rebuildLocationsFromCaches();
    notifyListeners();
  }

  void _handleDataConnectionError(String label, Object error) {
    debugPrint('$label: $error');
    _dataConnectionError =
        'Could not load live data. Check your internet connection.';
    notifyListeners();
  }

  void _applyUserProfile(
    String userId,
    Map<String, dynamic>? data, {
    required String fallbackRole,
  }) {
    _userNames[userId] = _displayNameFromData(userId, data);
    _userRoles[userId] = _roleFromData(data, fallbackRole: fallbackRole);
  }

  void _rebuildUserIndexes() {
    _driverIds.clear();
    _studentIds.clear();

    for (final entry in _userRoles.entries) {
      if (entry.value == 'driver') {
        _driverIds.add(entry.key);
      } else if (entry.value == 'student') {
        _studentIds.add(entry.key);
      }
    }

    for (final entry in _visibleLocationCache.entries) {
      if (entry.value.role == 'driver') {
        _driverIds.add(entry.key);
      } else if (entry.value.role == 'student') {
        _studentIds.add(entry.key);
      }
    }

    final ownUserId = _listeningUserId;
    final ownLocation = _ownLocationCache;
    if (ownUserId != null && ownLocation != null) {
      if (ownLocation.role == 'driver') {
        _driverIds.add(ownUserId);
      } else if (ownLocation.role == 'student') {
        _studentIds.add(ownUserId);
      }
    }
  }

  void _rebuildLocationsFromCaches() {
    _userLocations.clear();
    _userSpeedsKmh.clear();
    _userAccuraciesMeters.clear();
    _userLocationUpdatedAt.clear();

    for (final entry in _visibleLocationCache.entries) {
      _applyTrackedLocation(entry.key, entry.value);
    }

    final ownUserId = _listeningUserId;
    final ownLocation = _ownLocationCache;
    if (ownUserId != null && ownLocation != null) {
      _applyTrackedLocation(ownUserId, ownLocation);
    }

    _rebuildUserIndexes();
  }

  void _applyTrackedLocation(String userId, _TrackedLocation trackedLocation) {
    _userLocations[userId] = trackedLocation.location;
    if (trackedLocation.speedKmh != null) {
      _userSpeedsKmh[userId] = trackedLocation.speedKmh!;
    }
    if (trackedLocation.accuracyMeters != null) {
      _userAccuraciesMeters[userId] = trackedLocation.accuracyMeters!;
    } else {
      _userAccuraciesMeters.remove(userId);
    }
    _userLocationUpdatedAt[userId] = trackedLocation.updatedAt;
    _userRoles[userId] = trackedLocation.role;
  }

  _TrackedLocation? _trackedLocationFromDoc(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data();
    if (data == null) return null;

    final latitude = data['latitude'];
    final longitude = data['longitude'];
    final updatedAt = _updatedAtFromValue(data['updatedAt']);
    final role = _roleFromData(data);
    final staleBefore = DateTime.now().subtract(_staleLocationTimeout);
    if (latitude is! num ||
        longitude is! num ||
        updatedAt == null ||
        updatedAt.isBefore(staleBefore)) {
      return null;
    }

    final speedKmh = data['speedKmh'];
    final accuracyMeters = data['accuracyMeters'];
    return _TrackedLocation(
      location: LatLng(latitude.toDouble(), longitude.toDouble()),
      speedKmh: speedKmh is num ? speedKmh.toDouble() : null,
      accuracyMeters: accuracyMeters is num ? accuracyMeters.toDouble() : null,
      updatedAt: updatedAt,
      role: role,
    );
  }

  String _displayNameFromData(String userId, Map<String, dynamic>? data) {
    final name = data?['name']?.toString().trim();
    final email = data?['email']?.toString().trim();
    return name?.isNotEmpty == true
        ? name!
        : email?.isNotEmpty == true
        ? email!
        : userId;
  }

  String _roleFromData(
    Map<String, dynamic>? data, {
    String fallbackRole = 'student',
  }) {
    final role = data?['role']?.toString().toLowerCase();
    if (role == 'driver' || role == 'admin' || role == 'student') {
      return role!;
    }
    return fallbackRole;
  }

  void _stopListening() {
    _ownUserSubscription?.cancel();
    _ownUserSubscription = null;
    _visibleUsersSubscription?.cancel();
    _visibleUsersSubscription = null;
    _ownLocationSubscription?.cancel();
    _ownLocationSubscription = null;
    _visibleLocationsSubscription?.cancel();
    _visibleLocationsSubscription = null;
    _positionSubscription?.cancel();
    _positionSubscription = null;
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
    _freshnessTimer?.cancel();
    _freshnessTimer = null;
    _lastPosition = null;
    _lastMeaningfulMovementPosition = null;
    _lastMeaningfulMovementAt = null;
    _sharingUserId = null;
    _listeningUserId = null;
    _listeningUserRole = null;
    _isStartingLocationStream = false;
    _isRefreshingCurrentPosition = false;
    _hasLoadedVisibleUsers = false;
    _hasLoadedVisibleLocations = false;
    _isUsingCachedVisibleUsers = false;
    _isUsingCachedVisibleLocations = false;
    _dataConnectionError = null;
    _driverIds.clear();
    _studentIds.clear();
    _userNames.clear();
    _userRoles.clear();
    _userSpeedsKmh.clear();
    _userAccuraciesMeters.clear();
    _userLocationUpdatedAt.clear();
    _userLocations.clear();
    _visibleLocationCache.clear();
    _ownLocationCache = null;
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
      _lastMeaningfulMovementPosition = null;
      _lastMeaningfulMovementAt = null;
    }

    _isStartingLocationStream = true;
    final role = await _roleForUser(userId);
    final hasPermission = await _ensureLocationPermission();
    if (!hasPermission) {
      _isStartingLocationStream = false;
      notifyListeners();
      return;
    }

    try {
      final currentPosition = await Geolocator.getCurrentPosition(
        locationSettings: _currentLocationSettings(role),
      );
      await _writePosition(userId, currentPosition, role: role);
    } catch (error) {
      debugPrint('Current location lookup failed: $error');
      final lastKnown = await Geolocator.getLastKnownPosition();
      if (lastKnown != null) {
        await _writePosition(userId, lastKnown, role: role);
      }
    }

    _positionSubscription =
        Geolocator.getPositionStream(
          locationSettings: _streamLocationSettings(role),
        ).listen(
          (position) => _writePosition(userId, position, role: role),
          onError: (Object error) {
            _locationError = error.toString();
            debugPrint('Location stream failed: $error');
            notifyListeners();
          },
        );
    _sharingUserId = userId;
    _heartbeatTimer?.cancel();
    _heartbeatTimer = Timer.periodic(_heartbeatIntervalForRole(role), (_) {
      _refreshCurrentPosition(userId);
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
      _lastMeaningfulMovementPosition = null;
      _lastMeaningfulMovementAt = null;
      _sharingUserId = null;
      _isRefreshingCurrentPosition = false;
    }

    _userLocations.remove(userId);
    _userSpeedsKmh.remove(userId);
    _userAccuraciesMeters.remove(userId);
    _userLocationUpdatedAt.remove(userId);
    _visibleLocationCache.remove(userId);
    if (_listeningUserId == userId) {
      _ownLocationCache = null;
    }
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
          'Enable location permission for eJeep in system settings.';
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

  LocationSettings _currentLocationSettings(String role) {
    return _locationSettings(role: role, timeLimit: _currentLocationTimeout);
  }

  LocationSettings _streamLocationSettings(String role) {
    return _locationSettings(role: role, useForegroundService: true);
  }

  LocationSettings _locationSettings({
    required String role,
    Duration? timeLimit,
    bool useForegroundService = false,
  }) {
    final accuracy = _accuracyForRole(role);
    final distanceFilter = _distanceFilterForRole(role);
    final intervalDuration = _liveUpdateIntervalForRole(role);

    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return AndroidSettings(
          accuracy: accuracy,
          distanceFilter: distanceFilter,
          intervalDuration: intervalDuration,
          timeLimit: timeLimit,
          foregroundNotificationConfig: useForegroundService
              ? const ForegroundNotificationConfig(
                  notificationTitle: 'eJeep live location',
                  notificationText: 'Sharing your location for live tracking.',
                  notificationChannelName: 'Live location',
                  enableWakeLock: true,
                  setOngoing: true,
                )
              : null,
        );
      case TargetPlatform.iOS:
      case TargetPlatform.macOS:
        return AppleSettings(
          accuracy: accuracy,
          activityType: ActivityType.automotiveNavigation,
          distanceFilter: distanceFilter,
          pauseLocationUpdatesAutomatically: false,
          allowBackgroundLocationUpdates: false,
          timeLimit: timeLimit,
        );
      case TargetPlatform.fuchsia:
      case TargetPlatform.linux:
      case TargetPlatform.windows:
        return LocationSettings(
          accuracy: accuracy,
          distanceFilter: distanceFilter,
          timeLimit: timeLimit,
        );
    }
  }

  Duration _heartbeatIntervalForRole(String role) {
    return role == 'driver'
        ? _driverHeartbeatInterval
        : _studentHeartbeatInterval;
  }

  Duration _liveUpdateIntervalForRole(String role) {
    return role == 'driver'
        ? _driverLiveUpdateInterval
        : _studentLiveUpdateInterval;
  }

  int _distanceFilterForRole(String role) {
    return role == 'driver'
        ? _driverDistanceFilterMeters
        : _studentDistanceFilterMeters;
  }

  LocationAccuracy _accuracyForRole(String role) {
    return role == 'driver'
        ? LocationAccuracy.bestForNavigation
        : LocationAccuracy.high;
  }

  Future<void> _refreshCurrentPosition(String userId) async {
    if (_isRefreshingCurrentPosition || _sharingUserId != userId) {
      return;
    }

    _isRefreshingCurrentPosition = true;
    try {
      final role = await _roleForUser(userId);
      final currentPosition = await Geolocator.getCurrentPosition(
        locationSettings: _currentLocationSettings(role),
      );
      if (_sharingUserId == userId) {
        await _writePosition(userId, currentPosition, role: role);
      }
    } catch (error) {
      final lastPosition = _lastPosition;
      if (lastPosition != null && _sharingUserId == userId) {
        await _writePosition(userId, lastPosition, forceStopped: true);
      } else {
        debugPrint('Location refresh failed: $error');
      }
    } finally {
      _isRefreshingCurrentPosition = false;
    }
  }

  Future<void> _writePosition(
    String userId,
    Position position, {
    String? role,
    bool forceStopped = false,
  }) async {
    role ??= await _roleForUser(userId);
    final nextLocation = LatLng(position.latitude, position.longitude);
    final speedKmh = _speedKmhForPosition(
      userId,
      position,
      forceStopped: forceStopped,
    );
    final now = DateTime.now();
    _lastPosition = position;
    _userLocations[userId] = nextLocation;
    _userSpeedsKmh[userId] = speedKmh;
    _userAccuraciesMeters[userId] = position.accuracy;
    _userLocationUpdatedAt[userId] = now;
    _userRoles[userId] = role;
    if (_listeningUserId == userId) {
      _ownLocationCache = _TrackedLocation(
        location: nextLocation,
        speedKmh: speedKmh,
        accuracyMeters: position.accuracy,
        updatedAt: now,
        role: role,
      );
    }
    await FirebaseFirestore.instance.collection('locations').doc(userId).set({
      'latitude': position.latitude,
      'longitude': position.longitude,
      'accuracyMeters': position.accuracy,
      'speedKmh': speedKmh,
      'role': role,
      'updatedAt': FieldValue.serverTimestamp(),
    });
    notifyListeners();
  }

  double _speedKmhForPosition(
    String userId,
    Position position, {
    required bool forceStopped,
  }) {
    if (forceStopped || _isStationary(position)) {
      return 0.0;
    }

    final deviceSpeedKmh = position.speed > 0 ? position.speed * 3.6 : 0.0;
    final calculatedSpeedKmh = _calculatedSpeedKmh(_lastPosition, position);
    final rawSpeedKmh =
        deviceSpeedKmh < _minimumMovingSpeedKmh &&
            calculatedSpeedKmh != null &&
            calculatedSpeedKmh >= _minimumMovingSpeedKmh
        ? calculatedSpeedKmh
        : deviceSpeedKmh;

    final previousSpeedKmh = _userSpeedsKmh[userId];
    if (previousSpeedKmh == null || rawSpeedKmh < _minimumMovingSpeedKmh) {
      return rawSpeedKmh;
    }

    return (previousSpeedKmh * (1 - _speedSmoothingFactor)) +
        (rawSpeedKmh * _speedSmoothingFactor);
  }

  bool _isStationary(Position position) {
    final now = DateTime.now();
    final reference = _lastMeaningfulMovementPosition;
    if (reference == null) {
      _lastMeaningfulMovementPosition = position;
      _lastMeaningfulMovementAt = now;
      return false;
    }

    final meters = Geolocator.distanceBetween(
      reference.latitude,
      reference.longitude,
      position.latitude,
      position.longitude,
    );
    if (meters > _stationaryDistanceMeters) {
      _lastMeaningfulMovementPosition = position;
      _lastMeaningfulMovementAt = now;
      return false;
    }

    final lastMovementAt = _lastMeaningfulMovementAt;
    return lastMovementAt != null &&
        now.difference(lastMovementAt) >= _stationarySpeedTimeout;
  }

  double? _calculatedSpeedKmh(Position? previous, Position current) {
    if (previous == null) {
      return null;
    }

    final elapsedSeconds =
        current.timestamp
            .difference(previous.timestamp)
            .inMilliseconds
            .abs()
            .toDouble() /
        1000;
    if (elapsedSeconds <= 0) {
      return null;
    }

    final meters = Geolocator.distanceBetween(
      previous.latitude,
      previous.longitude,
      current.latitude,
      current.longitude,
    );
    final speedKmh = (meters / elapsedSeconds) * 3.6;
    if (speedKmh.isNaN ||
        speedKmh.isInfinite ||
        speedKmh > _maximumPlausibleSpeedKmh) {
      return null;
    }

    return speedKmh;
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

  double? getAccuracyMeters(String userId) {
    _ensureListening();
    return _userAccuraciesMeters[userId];
  }

  DateTime? getLocationUpdatedAt(String userId) {
    _ensureListening();
    return _userLocationUpdatedAt[userId];
  }

  bool isLocationFresh(String userId) {
    final updatedAt = getLocationUpdatedAt(userId);
    if (updatedAt == null) return false;
    return DateTime.now().difference(updatedAt) <= _freshLocationDuration;
  }

  String locationFreshnessLabel(String userId) {
    return freshnessLabelFor(getLocationUpdatedAt(userId));
  }

  String freshnessLabelFor(DateTime? updatedAt) {
    if (updatedAt == null) return 'Update time unavailable';

    final age = DateTime.now().difference(updatedAt);
    if (age.inSeconds < 10) return 'Updated just now';
    if (age.inMinutes < 1) return 'Updated ${age.inSeconds}s ago';
    if (age.inHours < 1) return 'Updated ${age.inMinutes}m ago';
    return 'Updated ${age.inHours}h ago';
  }

  bool isFreshUpdatedAt(DateTime? updatedAt) {
    if (updatedAt == null) return false;
    return DateTime.now().difference(updatedAt) <= _freshLocationDuration;
  }

  Future<void> updateLocation(String userId, LatLng newLocation) async {
    _ensureListening();
    final role = await _roleForUser(userId);
    _userLocations[userId] = newLocation;
    _userAccuraciesMeters.remove(userId);
    _userLocationUpdatedAt[userId] = DateTime.now();
    await FirebaseFirestore.instance.collection('locations').doc(userId).set({
      'latitude': newLocation.latitude,
      'longitude': newLocation.longitude,
      'role': role,
      'updatedAt': FieldValue.serverTimestamp(),
    });
    notifyListeners();
  }

  Future<String> _roleForUser(String userId) async {
    final cachedRole = _userRoles[userId];
    if (cachedRole != null) {
      return cachedRole;
    }

    final snapshot = await FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .get();
    final role = _roleFromData(snapshot.data());
    _userRoles[userId] = role;
    return role;
  }

  DateTime? _updatedAtFromValue(Object? value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    return null;
  }

  void _refreshFreshnessState() {
    final removedExpiredLocations = _dropExpiredLocations();
    if (_userLocations.isNotEmpty || removedExpiredLocations) {
      notifyListeners();
    }
  }

  bool _dropExpiredLocations() {
    final staleBefore = DateTime.now().subtract(_staleLocationTimeout);
    final expiredUserIds = _userLocationUpdatedAt.entries
        .where((entry) => entry.value.isBefore(staleBefore))
        .map((entry) => entry.key)
        .toList();

    if (expiredUserIds.isEmpty) {
      return false;
    }

    for (final userId in expiredUserIds) {
      _userLocations.remove(userId);
      _userSpeedsKmh.remove(userId);
      _userAccuraciesMeters.remove(userId);
      _userLocationUpdatedAt.remove(userId);
      _visibleLocationCache.remove(userId);
      if (_listeningUserId == userId) {
        _ownLocationCache = null;
      }
    }

    _rebuildUserIndexes();
    return true;
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    _authSubscription = null;
    _stopListening();
    super.dispose();
  }
}

class _TrackedLocation {
  const _TrackedLocation({
    required this.location,
    required this.updatedAt,
    required this.role,
    this.speedKmh,
    this.accuracyMeters,
  });

  final LatLng location;
  final double? speedKmh;
  final double? accuracyMeters;
  final DateTime updatedAt;
  final String role;
}

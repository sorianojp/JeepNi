import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/widgets.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/user_model.dart';
import 'firebase_auth_service.dart';
import 'firebase_tracking_service.dart';

class NearbyDriverAlertService extends ChangeNotifier
    with WidgetsBindingObserver {
  static const double nearbyDistanceMeters = 300;
  static const double _rearmDistanceMeters = 420;
  static const double _minimumMovingSpeedKmh = 4;
  static const Duration _notificationCooldown = Duration(minutes: 8);
  static const int _testNotificationId = 100001;
  static const String _channelId = 'nearby-driver-alerts';
  static const String _channelName = 'Nearby driver alerts';
  static const String _channelDescription =
      'Alerts when a moving driver is close to the student';
  static const String _alertsEnabledPreferenceKey =
      'nearby_driver_alerts_enabled';

  NearbyDriverAlertService(
    this._authService,
    this._trackingService, {
    FlutterLocalNotificationsPlugin? notificationsPlugin,
  }) : _notificationsPlugin =
           notificationsPlugin ?? FlutterLocalNotificationsPlugin() {
    WidgetsBinding.instance.addObserver(this);
    _authService.addListener(_handleStateChanged);
    _trackingService.addListener(_handleStateChanged);
  }

  final FirebaseAuthService _authService;
  final FirebaseTrackingService _trackingService;
  final FlutterLocalNotificationsPlugin _notificationsPlugin;
  final SharedPreferencesAsync _preferences = SharedPreferencesAsync();
  final Set<String> _driversInsideZone = <String>{};
  final Map<String, DateTime> _lastNotificationAt = <String, DateTime>{};

  bool _isInitialized = false;
  bool _isInitializing = false;
  bool _alertsEnabled = false;
  bool _notificationsPermissionGranted = false;
  bool _isUpdatingPreference = false;
  bool _isEvaluating = false;
  bool _needsReevaluation = false;
  String? _activeStudentId;

  bool get alertsEnabled => _alertsEnabled;
  bool get notificationsPermissionGranted => _notificationsPermissionGranted;
  bool get requiresSystemPermission =>
      _alertsEnabled && !_notificationsPermissionGranted;
  bool get isUpdatingPreference => _isUpdatingPreference || _isInitializing;
  bool get alertsActive => _alertsEnabled && _notificationsPermissionGranted;

  String get settingsDescription {
    if (!_alertsEnabled) {
      return 'Notify you when a moving driver is within ${nearbyDistanceMeters.round()} m.';
    }
    if (_notificationsPermissionGranted) {
      return 'Nearby driver alerts are on within ${nearbyDistanceMeters.round()} m.';
    }
    return 'Alerts are enabled here, but system notifications are off for this app.';
  }

  Future<void> initialize() async {
    if (_isInitialized || _isInitializing) {
      return;
    }

    _isInitializing = true;
    try {
      const androidSettings = AndroidInitializationSettings('launcher_icon');
      const darwinSettings = DarwinInitializationSettings(
        requestAlertPermission: false,
        requestBadgePermission: false,
        requestSoundPermission: false,
      );
      const settings = InitializationSettings(
        android: androidSettings,
        iOS: darwinSettings,
        macOS: darwinSettings,
      );

      await _notificationsPlugin.initialize(settings: settings);

      final androidImplementation = _notificationsPlugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();
      await androidImplementation?.createNotificationChannel(
        const AndroidNotificationChannel(
          _channelId,
          _channelName,
          description: _channelDescription,
          importance: Importance.high,
        ),
      );

      _alertsEnabled =
          await _preferences.getBool(_alertsEnabledPreferenceKey) ?? false;
      _notificationsPermissionGranted = await _areNotificationsEnabled();
      _isInitialized = true;
      _handleStateChanged();
    } finally {
      _isInitializing = false;
      notifyListeners();
    }
  }

  Future<void> setAlertsEnabled(bool enabled) async {
    if (_isUpdatingPreference) {
      return;
    }

    _isUpdatingPreference = true;
    try {
      _alertsEnabled = enabled;
      await _preferences.setBool(_alertsEnabledPreferenceKey, enabled);
      notifyListeners();

      if (enabled && !_notificationsPermissionGranted) {
        await _requestNotificationPermissions();
      }

      await refreshPermissionStatus();
    } finally {
      _isUpdatingPreference = false;
      notifyListeners();
    }

    if (!enabled) {
      _driversInsideZone.clear();
      _lastNotificationAt.clear();
    }
    _scheduleEvaluation();
  }

  Future<void> openAppSettings() async {
    await Geolocator.openAppSettings();
  }

  Future<bool> sendTestNotification() async {
    if (!_notificationsPermissionGranted) {
      return false;
    }

    const androidDetails = AndroidNotificationDetails(
      _channelId,
      _channelName,
      channelDescription: _channelDescription,
      importance: Importance.high,
      priority: Priority.high,
      category: AndroidNotificationCategory.transport,
    );
    const darwinDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: false,
      presentSound: true,
      threadIdentifier: _channelId,
    );

    await _notificationsPlugin.show(
      id: _testNotificationId,
      title: 'eJeep notification test',
      body: 'Nearby driver alerts are ready on this device.',
      notificationDetails: const NotificationDetails(
        android: androidDetails,
        iOS: darwinDetails,
        macOS: darwinDetails,
      ),
    );
    return true;
  }

  Future<void> refreshPermissionStatus() async {
    if (!_isInitialized) {
      return;
    }

    final nextPermissionValue = await _areNotificationsEnabled();
    if (_notificationsPermissionGranted != nextPermissionValue) {
      _notificationsPermissionGranted = nextPermissionValue;
      notifyListeners();
    }
    _scheduleEvaluation();
  }

  void _handleStateChanged() {
    if (!_isInitialized) {
      return;
    }

    final currentUser = _authService.currentUser;
    final nextStudentId = currentUser?.role == UserRole.student
        ? currentUser!.id
        : null;

    if (_activeStudentId != nextStudentId) {
      _activeStudentId = nextStudentId;
      _driversInsideZone.clear();
      _lastNotificationAt.clear();
      notifyListeners();
    }

    if (nextStudentId == null) {
      _driversInsideZone.clear();
      return;
    }

    _scheduleEvaluation();
  }

  void _scheduleEvaluation() {
    if (_isEvaluating) {
      _needsReevaluation = true;
      return;
    }
    unawaited(_runEvaluationLoop());
  }

  Future<void> _runEvaluationLoop() async {
    _isEvaluating = true;
    do {
      _needsReevaluation = false;
      await _evaluateNearbyDrivers();
    } while (_needsReevaluation);
    _isEvaluating = false;
  }

  Future<void> _evaluateNearbyDrivers() async {
    final studentId = _activeStudentId;
    if (studentId == null || !alertsActive) {
      _driversInsideZone.clear();
      return;
    }

    final studentLocation = _trackingService.getLocation(studentId);
    if (!_trackingService.isSharingLocation(studentId) ||
        studentLocation == null) {
      _driversInsideZone.clear();
      return;
    }

    final now = DateTime.now();
    final nextDriversInsideZone = <String>{};
    for (final driverId in _trackingService.getDriverIds()) {
      final driverLocation = _trackingService.getLocation(driverId);
      if (driverLocation == null ||
          !_trackingService.isLocationFresh(driverId)) {
        continue;
      }

      final distanceMeters = Geolocator.distanceBetween(
        studentLocation.latitude,
        studentLocation.longitude,
        driverLocation.latitude,
        driverLocation.longitude,
      );
      final wasInsideZone = _driversInsideZone.contains(driverId);
      if (distanceMeters <= nearbyDistanceMeters ||
          (wasInsideZone && distanceMeters <= _rearmDistanceMeters)) {
        nextDriversInsideZone.add(driverId);
      }

      if (wasInsideZone || distanceMeters > nearbyDistanceMeters) {
        continue;
      }

      final speedKmh = _trackingService.getSpeedKmh(driverId) ?? 0;
      if (speedKmh < _minimumMovingSpeedKmh) {
        continue;
      }

      final lastNotificationAt = _lastNotificationAt[driverId];
      if (lastNotificationAt != null &&
          now.difference(lastNotificationAt) < _notificationCooldown) {
        continue;
      }

      await _showNearbyDriverNotification(
        driverId: driverId,
        distanceMeters: distanceMeters,
        speedKmh: speedKmh,
      );
      _lastNotificationAt[driverId] = now;
    }

    _driversInsideZone
      ..clear()
      ..addAll(nextDriversInsideZone);
  }

  Future<void> _showNearbyDriverNotification({
    required String driverId,
    required double distanceMeters,
    required double speedKmh,
  }) async {
    final driverName = _trackingService.displayNameFor(driverId);
    final distanceLabel = distanceMeters < 1000
        ? '${distanceMeters.round()} m'
        : '${(distanceMeters / 1000).toStringAsFixed(1)} km';
    final speedLabel = '${speedKmh.round()} km/h';

    const androidDetails = AndroidNotificationDetails(
      _channelId,
      _channelName,
      channelDescription: _channelDescription,
      importance: Importance.high,
      priority: Priority.high,
      category: AndroidNotificationCategory.transport,
    );
    const darwinDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: false,
      presentSound: true,
      threadIdentifier: _channelId,
    );

    await _notificationsPlugin.show(
      id: driverId.hashCode & 0x7fffffff,
      title: 'Driver nearby',
      body:
          '$driverName is about $distanceLabel away and moving at $speedLabel.',
      notificationDetails: const NotificationDetails(
        android: androidDetails,
        iOS: darwinDetails,
        macOS: darwinDetails,
      ),
    );
  }

  Future<bool> _requestNotificationPermissions() async {
    if (kIsWeb) {
      return false;
    }

    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        final androidImplementation = _notificationsPlugin
            .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin
            >();
        return await androidImplementation?.requestNotificationsPermission() ??
            false;
      case TargetPlatform.iOS:
        final iosImplementation = _notificationsPlugin
            .resolvePlatformSpecificImplementation<
              IOSFlutterLocalNotificationsPlugin
            >();
        return await iosImplementation?.requestPermissions(
              alert: true,
              badge: false,
              sound: true,
            ) ??
            false;
      case TargetPlatform.macOS:
        final macosImplementation = _notificationsPlugin
            .resolvePlatformSpecificImplementation<
              MacOSFlutterLocalNotificationsPlugin
            >();
        return await macosImplementation?.requestPermissions(
              alert: true,
              badge: false,
              sound: true,
            ) ??
            false;
      case TargetPlatform.fuchsia:
      case TargetPlatform.linux:
      case TargetPlatform.windows:
        return false;
    }
  }

  Future<bool> _areNotificationsEnabled() async {
    if (kIsWeb) {
      return false;
    }

    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        final androidImplementation = _notificationsPlugin
            .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin
            >();
        return await androidImplementation?.areNotificationsEnabled() ?? false;
      case TargetPlatform.iOS:
        final iosImplementation = _notificationsPlugin
            .resolvePlatformSpecificImplementation<
              IOSFlutterLocalNotificationsPlugin
            >();
        final permissions = await iosImplementation?.checkPermissions();
        return permissions?.isEnabled ?? false;
      case TargetPlatform.macOS:
        final macosImplementation = _notificationsPlugin
            .resolvePlatformSpecificImplementation<
              MacOSFlutterLocalNotificationsPlugin
            >();
        final permissions = await macosImplementation?.checkPermissions();
        return permissions?.isEnabled ?? false;
      case TargetPlatform.fuchsia:
      case TargetPlatform.linux:
      case TargetPlatform.windows:
        return false;
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(refreshPermissionStatus());
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _authService.removeListener(_handleStateChanged);
    _trackingService.removeListener(_handleStateChanged);
    super.dispose();
  }
}

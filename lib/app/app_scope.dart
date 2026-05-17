import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../core/router.dart';
import '../services/ejeep_schedule_service.dart';
import '../services/firebase_auth_service.dart';
import '../services/firebase_tracking_service.dart';
import '../services/nearby_driver_alert_service.dart';

class AppScope extends StatefulWidget {
  const AppScope({super.key, required this.child});

  final Widget child;

  @override
  State<AppScope> createState() => _AppScopeState();
}

class _AppScopeState extends State<AppScope> {
  late final FirebaseAuthService _authService;
  late final FirebaseTrackingService _trackingService;
  late final EJeepScheduleService _scheduleService;
  late final NearbyDriverAlertService _nearbyDriverAlertService;
  late final GoRouter _router;

  @override
  void initState() {
    super.initState();
    _authService = FirebaseAuthService();
    _trackingService = FirebaseTrackingService();
    _scheduleService = EJeepScheduleService();
    _nearbyDriverAlertService = NearbyDriverAlertService(
      _authService,
      _trackingService,
    );
    unawaited(_nearbyDriverAlertService.initialize());
    _router = createRouter(_authService);
  }

  @override
  void dispose() {
    _nearbyDriverAlertService.dispose();
    _scheduleService.dispose();
    _authService.dispose();
    _trackingService.dispose();
    _router.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: _authService),
        ChangeNotifierProvider.value(value: _trackingService),
        ChangeNotifierProvider.value(value: _scheduleService),
        ChangeNotifierProvider.value(value: _nearbyDriverAlertService),
        Provider<GoRouter>.value(value: _router),
      ],
      child: widget.child,
    );
  }
}

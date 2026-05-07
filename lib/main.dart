import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'screens/splash/splash_screen.dart';
import 'firebase_options.dart';
import 'services/firebase_auth_service.dart';
import 'services/nearby_driver_alert_service.dart';
import 'services/firebase_tracking_service.dart';
import 'core/router.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await _initializeFirebase();
  runApp(const JeepNiApp());
}

Future<void> _initializeFirebase() async {
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } on FirebaseException catch (error) {
    if (error.code != 'duplicate-app') {
      rethrow;
    }
  }
}

class JeepNiApp extends StatefulWidget {
  const JeepNiApp({super.key});

  @override
  State<JeepNiApp> createState() => _JeepNiAppState();
}

class _JeepNiAppState extends State<JeepNiApp> {
  static const _minimumSplashDuration = Duration(milliseconds: 1600);

  late final FirebaseAuthService _authService;
  late final FirebaseTrackingService _trackingService;
  late final NearbyDriverAlertService _nearbyDriverAlertService;
  late final GoRouter _router;
  bool _hasShownSplash = false;

  @override
  void initState() {
    super.initState();
    _authService = FirebaseAuthService();
    _trackingService = FirebaseTrackingService();
    _nearbyDriverAlertService = NearbyDriverAlertService(
      _authService,
      _trackingService,
    );
    unawaited(_nearbyDriverAlertService.initialize());
    _router = createRouter(_authService);
    Future<void>.delayed(_minimumSplashDuration, () {
      if (!mounted) return;

      setState(() {
        _hasShownSplash = true;
      });
    });
  }

  @override
  void dispose() {
    _nearbyDriverAlertService.dispose();
    _authService.dispose();
    _trackingService.dispose();
    _router.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = ThemeData(
      colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
      useMaterial3: true,
    );

    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: _authService),
        ChangeNotifierProvider.value(value: _trackingService),
        ChangeNotifierProvider.value(value: _nearbyDriverAlertService),
      ],
      child: AnimatedBuilder(
        animation: _authService,
        builder: (context, child) {
          final isReady = _hasShownSplash && _authService.isInitialized;

          if (!isReady) {
            return MaterialApp(
              title: 'JeepNi Tracking',
              theme: theme,
              home: SplashScreen(
                message: _authService.isInitialized
                    ? 'Launching JeepNi...'
                    : 'Checking your session...',
              ),
            );
          }

          return MaterialApp.router(
            title: 'JeepNi Tracking',
            theme: theme,
            routerConfig: _router,
          );
        },
      ),
    );
  }
}

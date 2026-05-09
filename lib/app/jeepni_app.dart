import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../screens/splash/splash_screen.dart';
import '../services/firebase_auth_service.dart';
import 'app_scope.dart';

class JeepNiApp extends StatelessWidget {
  const JeepNiApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const AppScope(child: _JeepNiAppView());
  }
}

class _JeepNiAppView extends StatefulWidget {
  const _JeepNiAppView();

  @override
  State<_JeepNiAppView> createState() => _JeepNiAppViewState();
}

class _JeepNiAppViewState extends State<_JeepNiAppView> {
  static const _minimumSplashDuration = Duration(milliseconds: 1600);

  Timer? _splashTimer;
  bool _hasShownSplash = false;

  @override
  void initState() {
    super.initState();
    _splashTimer = Timer(_minimumSplashDuration, () {
      if (!mounted) return;
      setState(() {
        _hasShownSplash = true;
      });
    });
  }

  @override
  void dispose() {
    _splashTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authService = context.watch<FirebaseAuthService>();
    final router = context.read<GoRouter>();
    final theme = ThemeData(
      colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
      useMaterial3: true,
    );
    final isReady = _hasShownSplash && authService.isInitialized;

    if (!isReady) {
      return MaterialApp(
        title: 'JeepNi Tracking',
        theme: theme,
        home: SplashScreen(
          message: authService.isInitialized
              ? 'Launching JeepNi...'
              : 'Checking your session...',
        ),
      );
    }

    return MaterialApp.router(
      title: 'JeepNi Tracking',
      theme: theme,
      routerConfig: router,
    );
  }
}

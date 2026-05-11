import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../screens/splash/splash_screen.dart';
import '../services/firebase_auth_service.dart';
import 'app_scope.dart';

class EJeepApp extends StatelessWidget {
  const EJeepApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const AppScope(child: _EJeepAppView());
  }
}

class _EJeepAppView extends StatefulWidget {
  const _EJeepAppView();

  @override
  State<_EJeepAppView> createState() => _EJeepAppViewState();
}

class _EJeepAppViewState extends State<_EJeepAppView> {
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
        title: 'eJeep Tracking',
        theme: theme,
        home: SplashScreen(
          message: authService.isInitialized
              ? 'Launching eJeep...'
              : 'Checking your session...',
        ),
      );
    }

    return MaterialApp.router(
      title: 'eJeep Tracking',
      theme: theme,
      routerConfig: router,
    );
  }
}

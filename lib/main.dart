import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'firebase_options.dart';
import 'services/firebase_auth_service.dart';
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
  late final FirebaseAuthService _authService;
  late final FirebaseTrackingService _trackingService;
  late final GoRouter _router;

  @override
  void initState() {
    super.initState();
    _authService = FirebaseAuthService();
    _trackingService = FirebaseTrackingService();
    _router = createRouter(_authService);
  }

  @override
  void dispose() {
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
      ],
      child: MaterialApp.router(
        title: 'JeepNi Tracking',
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
          useMaterial3: true,
        ),
        routerConfig: _router,
      ),
    );
  }
}

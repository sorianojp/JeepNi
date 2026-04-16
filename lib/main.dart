import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
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
    if (kIsWeb) {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
    } else {
      await Firebase.initializeApp();
    }
  } on FirebaseException catch (error) {
    if (error.code != 'duplicate-app') {
      rethrow;
    }
  }
}

class JeepNiApp extends StatelessWidget {
  const JeepNiApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => FirebaseAuthService()),
        ChangeNotifierProvider(create: (_) => FirebaseTrackingService()),
      ],
      child: MaterialApp.router(
        title: 'JeepNi Tracking',
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
          useMaterial3: true,
        ),
        routerConfig: router,
      ),
    );
  }
}

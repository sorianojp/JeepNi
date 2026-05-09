import 'package:firebase_core/firebase_core.dart';

import '../firebase_options.dart';

Future<void> bootstrapApp() async {
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

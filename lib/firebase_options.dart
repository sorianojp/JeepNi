import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      case TargetPlatform.macOS:
        return macos;
      case TargetPlatform.windows:
        return windows;
      case TargetPlatform.linux:
        throw UnsupportedError(
          'FirebaseOptions are not configured for Linux. Add a Linux app in Firebase first.',
        );
      case TargetPlatform.fuchsia:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyBdVyAMys3zcg4Hhg-EwGo4avPQMM7uz7o',
    appId: '1:145780868219:android:544652aaa5f2469d1e8ede',
    messagingSenderId: '145780868219',
    projectId: 'ejeep-782c9',
    storageBucket: 'ejeep-782c9.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyAkfxW9A9H3NIkLOMFb6dTurSCtvSx5OEk',
    appId: '1:145780868219:ios:d611df38dccbc5521e8ede',
    messagingSenderId: '145780868219',
    projectId: 'ejeep-782c9',
    storageBucket: 'ejeep-782c9.firebasestorage.app',
    iosBundleId: 'com.arzatech.ejeep',
  );

  static const FirebaseOptions macos = FirebaseOptions(
    apiKey: 'AIzaSyAkfxW9A9H3NIkLOMFb6dTurSCtvSx5OEk',
    appId: '1:145780868219:ios:440f1c4d6383bcae1e8ede',
    messagingSenderId: '145780868219',
    projectId: 'ejeep-782c9',
    storageBucket: 'ejeep-782c9.firebasestorage.app',
    iosBundleId: 'com.arzatech.ejeep',
  );

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyDNzclv8MOqioETE-UXF0_5JyhA3ZSnX-4',
    appId: '1:145780868219:web:a948f5ff617949e31e8ede',
    messagingSenderId: '145780868219',
    projectId: 'ejeep-782c9',
    authDomain: 'ejeep-782c9.firebaseapp.com',
    storageBucket: 'ejeep-782c9.firebasestorage.app',
    measurementId: 'G-NF7F5BSN83',
  );

  static const FirebaseOptions windows = FirebaseOptions(
    apiKey: 'AIzaSyDNzclv8MOqioETE-UXF0_5JyhA3ZSnX-4',
    appId: '1:145780868219:web:c67e954d4610b35b1e8ede',
    messagingSenderId: '145780868219',
    projectId: 'ejeep-782c9',
    authDomain: 'ejeep-782c9.firebaseapp.com',
    storageBucket: 'ejeep-782c9.firebasestorage.app',
    measurementId: 'G-KQPZ7LLPE1',
  );

}

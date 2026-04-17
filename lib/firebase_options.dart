import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      throw UnsupportedError(
        'FirebaseOptions are not configured for web. Add a web app in Firebase first.',
      );
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      case TargetPlatform.macOS:
        return macos;
      case TargetPlatform.windows:
        throw UnsupportedError(
          'FirebaseOptions are not configured for Windows. Add a Windows app in Firebase first.',
        );
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
    apiKey: 'AIzaSyBIY2IGEr-chFfuFdK7CCwLRavcCj8OcJA',
    appId: '1:978580525395:android:a4f9f0c6914c49da0591a6',
    messagingSenderId: '978580525395',
    projectId: 'jeepni-45b6c',
    storageBucket: 'jeepni-45b6c.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyArA_ADqGErmk2LH4uf1eB2ON1S7sqNkmk',
    appId: '1:978580525395:ios:cae594743fc5e8270591a6',
    messagingSenderId: '978580525395',
    projectId: 'jeepni-45b6c',
    storageBucket: 'jeepni-45b6c.firebasestorage.app',
    iosBundleId: 'com.arzatech.jeepni',
  );

  static const FirebaseOptions macos = FirebaseOptions(
    apiKey: 'AIzaSyArA_ADqGErmk2LH4uf1eB2ON1S7sqNkmk',
    appId: '1:978580525395:ios:cae594743fc5e8270591a6',
    messagingSenderId: '978580525395',
    projectId: 'jeepni-45b6c',
    storageBucket: 'jeepni-45b6c.firebasestorage.app',
    iosBundleId: 'com.arzatech.jeepni',
  );
}

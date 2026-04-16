import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart' show defaultTargetPlatform, kIsWeb, TargetPlatform;

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
        return linux;
      case TargetPlatform.fuchsia:
        throw UnsupportedError('DefaultFirebaseOptions are not supported for this platform.');
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyBT8psFxrMV6_RaOK5qeJ0HZ5Fl38-6IUc',
    appId: '1:134297565560:web:jeppniwebapp',
    messagingSenderId: '134297565560',
    projectId: 'jeppni',
    authDomain: 'jeppni.firebaseapp.com',
    storageBucket: 'jeppni.firebasestorage.app',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyBT8psFxrMV6_RaOK5qeJ0HZ5Fl38-6IUc',
    appId: '1:134297565560:android:8f621839c9170a3b3cb08d',
    messagingSenderId: '134297565560',
    projectId: 'jeppni',
    storageBucket: 'jeppni.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyBDYHtceRE4T4rHaTwni_hQ6JrU1FxzVWU',
    appId: '1:134297565560:ios:147bfeaaddd409803cb08d',
    messagingSenderId: '134297565560',
    projectId: 'jeppni',
    storageBucket: 'jeppni.firebasestorage.app',
    iosBundleId: 'com.arzatech.jeepni',
  );

  static const FirebaseOptions macos = FirebaseOptions(
    apiKey: 'AIzaSyBDYHtceRE4T4rHaTwni_hQ6JrU1FxzVWU',
    appId: '1:134297565560:ios:147bfeaaddd409803cb08d',
    messagingSenderId: '134297565560',
    projectId: 'jeppni',
    storageBucket: 'jeppni.firebasestorage.app',
    iosBundleId: 'com.arzatech.jeepni',
  );

  static const FirebaseOptions windows = FirebaseOptions(
    apiKey: 'AIzaSyBT8psFxrMV6_RaOK5qeJ0HZ5Fl38-6IUc',
    appId: '1:134297565560:web:jeppniwindowsapp',
    messagingSenderId: '134297565560',
    projectId: 'jeppni',
    storageBucket: 'jeppni.firebasestorage.app',
  );

  static const FirebaseOptions linux = FirebaseOptions(
    apiKey: 'AIzaSyBT8psFxrMV6_RaOK5qeJ0HZ5Fl38-6IUc',
    appId: '1:134297565560:web:jeppnilinuxapp',
    messagingSenderId: '134297565560',
    projectId: 'jeppni',
    storageBucket: 'jeppni.firebasestorage.app',
  );
}

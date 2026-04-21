import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

/// Default [FirebaseOptions] for use with your Firebase apps.
///
/// Example:
/// ```dart
/// import 'firebase_options.dart';
/// // ...
/// await Firebase.initializeApp(
///   options: DefaultFirebaseOptions.currentPlatform,
/// );
/// ```
class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for ios - '
          'you can reconfigure this by running the FlutterFire CLI again.',
        );
      case TargetPlatform.macOS:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for macos - '
          'you can reconfigure this by running the FlutterFire CLI again.',
        );
      case TargetPlatform.windows:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for windows - '
          'you can reconfigure this by running the FlutterFire CLI again.',
        );
      case TargetPlatform.linux:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for linux - '
          'you can reconfigure this by running the FlutterFire CLI again.',
        );
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyAetWd4jreAn4ddd3Il2i1FHOFTXjr0Y-4',
    appId: '1:461877024151:web:214d6aaa6b95faaa6b20d2',
    messagingSenderId: '461877024151',
    projectId: 'quizzly-7404c',
    authDomain: 'quizzly-7404c.firebaseapp.com',
    storageBucket: 'quizzly-7404c.firebasestorage.app',
    measurementId: 'G-GV3NRBGVXK',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyASLYk_-skCcvrWoLW3XB2P5igLHgzwyq0',
    appId: '1:461877024151:android:1621f4d535230a5b6b20d2',
    messagingSenderId: '461877024151',
    projectId: 'quizzly-7404c',
    storageBucket: 'quizzly-7404c.firebasestorage.app',
  );
}

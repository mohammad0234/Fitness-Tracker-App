// File generated by FlutterFire CLI.
// ignore_for_file: type=lint
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
        return ios;
      case TargetPlatform.macOS:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for macos - '
          'you can reconfigure this by running the FlutterFire CLI again.',
        );
      case TargetPlatform.windows:
        return windows;
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
    apiKey: 'AIzaSyDvW3QgrI7JrRdJrozAHrnT15A-dZ5LRK8',
    appId: '1:917276313680:web:b00cb137a128d5c2a3a955',
    messagingSenderId: '917276313680',
    projectId: 'fitjourney-f4a76',
    authDomain: 'fitjourney-f4a76.firebaseapp.com',
    storageBucket: 'fitjourney-f4a76.firebasestorage.app',
    measurementId: 'G-1V7VZFSXGG',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyA8eOGPju2Eodk7_eE2lnywP-2yP5vbYQ4',
    appId: '1:917276313680:android:5ff62662d8a9ba80a3a955',
    messagingSenderId: '917276313680',
    projectId: 'fitjourney-f4a76',
    storageBucket: 'fitjourney-f4a76.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyDcYfdwx7ezgqKagYhvkvXqICKDlX3DA4w',
    appId: '1:917276313680:ios:3d195d2f913a21afa3a955',
    messagingSenderId: '917276313680',
    projectId: 'fitjourney-f4a76',
    storageBucket: 'fitjourney-f4a76.firebasestorage.app',
    iosBundleId: 'com.example.fitjourney',
  );

  static const FirebaseOptions windows = FirebaseOptions(
    apiKey: 'AIzaSyDvW3QgrI7JrRdJrozAHrnT15A-dZ5LRK8',
    appId: '1:917276313680:web:aab20dc1471f79fca3a955',
    messagingSenderId: '917276313680',
    projectId: 'fitjourney-f4a76',
    authDomain: 'fitjourney-f4a76.firebaseapp.com',
    storageBucket: 'fitjourney-f4a76.firebasestorage.app',
    measurementId: 'G-NKZJY2PLTH',
  );

}
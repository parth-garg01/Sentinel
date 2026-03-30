import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      default:
        throw UnsupportedError(
          'Platform not supported',
        );
    }
  }

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: "AIzaSyBkocWjcT0UAlHQETcMHWWKf89_utHXNxM",
    appId: "1:552666185090:android:b5e60ce3c1938d07b7239b",
    messagingSenderId: "552666185090",
    projectId: "sentinel102932",
    storageBucket: "sentinel102932.firebasestorage.app",
  );
}
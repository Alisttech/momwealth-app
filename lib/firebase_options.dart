// Firebase settings for project "mom-wealth".
// Android: the existing Android app registered in Firebase (package com.mycompany.momwealth).
// iOS: from GoogleService-Info.plist of the iOS app registered with bundle ID com.momrehoboth.momwealth.
// These values identify the project; they are not secrets. Access is controlled by Firestore rules and Auth.
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart' show defaultTargetPlatform, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    switch (defaultTargetPlatform) {
      case TargetPlatform.iOS:
        return ios;
      case TargetPlatform.android:
        return android;
      default:
        throw UnsupportedError('MOM Wealth runs on iOS and Android only.');
    }
  }

  static const android = FirebaseOptions(
    apiKey: 'AIzaSyAfvCEOOj13J2-ugeNOBX_eg38tTldnqMY',
    appId: '1:326655003698:android:1489d3423088bb6302802b',
    messagingSenderId: '326655003698',
    projectId: 'mom-wealth',
    storageBucket: 'mom-wealth.firebasestorage.app',
  );

  // FILL FROM GoogleService-Info.plist: API_KEY and GOOGLE_APP_ID.
  static const ios = FirebaseOptions(
    apiKey: 'IOS_API_KEY',
    appId: 'IOS_GOOGLE_APP_ID',
    messagingSenderId: '326655003698',
    projectId: 'mom-wealth',
    storageBucket: 'mom-wealth.firebasestorage.app',
    iosBundleId: 'com.momrehoboth.momwealth',
  );
}

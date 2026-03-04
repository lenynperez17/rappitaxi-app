// File generated for Firebase project: rapi-team
// ignore_for_file: lines_longer_than_80_chars, avoid_classes_with_only_static_members
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
    apiKey: 'AIzaSyCMiZKCmDTFrPgKEw_M7hrW-3dCWs2zArA',
    appId: '1:52925359166:web:b92cb3861b9d54526fdd6f',
    messagingSenderId: '52925359166',
    projectId: 'rapi-team',
    authDomain: 'rapi-team.firebaseapp.com',
    storageBucket: 'rapi-team.firebasestorage.app',
    measurementId: 'G-58Y4CBEFDM',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyBSNK-cUnPCHof9ObXq0whK0ffSyCfJTqY',
    appId: '1:52925359166:android:849a90b5cd4d2d336fdd6f',
    messagingSenderId: '52925359166',
    projectId: 'rapi-team',
    storageBucket: 'rapi-team.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyA_m_nF7Xx_VRjGsXD7wbHM9OHl0tLJ5HM',
    appId: '1:52925359166:ios:ceb29da064ddd1cc6fdd6f',
    messagingSenderId: '52925359166',
    projectId: 'rapi-team',
    storageBucket: 'rapi-team.firebasestorage.app',
    iosBundleId: 'com.rapiteam.app',
  );

  static const FirebaseOptions macos = FirebaseOptions(
    apiKey: 'AIzaSyA_m_nF7Xx_VRjGsXD7wbHM9OHl0tLJ5HM',
    appId: '1:52925359166:ios:ceb29da064ddd1cc6fdd6f',
    messagingSenderId: '52925359166',
    projectId: 'rapi-team',
    storageBucket: 'rapi-team.firebasestorage.app',
    iosBundleId: 'com.rapiteam.app',
  );
}

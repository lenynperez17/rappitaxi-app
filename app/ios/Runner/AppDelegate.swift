import Flutter
import UIKit
import FirebaseCore
import UserNotifications

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // ✅ PASO 1: Firebase DEBE inicializarse PRIMERO, ANTES de registrar plugins
    // Verificamos si ya está configurado para evitar duplicate-app crash
    if FirebaseApp.app() == nil {
      FirebaseApp.configure()
    }

    // ✅ PASO 2: Configurar delegado de notificaciones manualmente
    // Requerido porque FirebaseAppDelegateProxyEnabled = false en Info.plist
    if #available(iOS 10.0, *) {
      UNUserNotificationCenter.current().delegate = self
    }

    // ✅ PASO 3: DESPUÉS de Firebase, registrar los plugins de Flutter
    GeneratedPluginRegistrant.register(with: self)

    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}

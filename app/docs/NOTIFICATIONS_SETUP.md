# Configuración de Notificaciones Push

## Android

### 1. Agregar google-services.json

1. Descarga el archivo `google-services.json` desde Firebase Console
2. Copia el archivo a `android/app/`
3. Asegúrate de que el package name coincida: `com.oasisperu.taxi.passenger`

### 2. Configurar AndroidManifest.xml

Agregar los siguientes permisos y configuraciones en `android/app/src/main/AndroidManifest.xml`:

```xml
<uses-permission android:name="android.permission.INTERNET"/>
<uses-permission android:name="android.permission.VIBRATE" />
<uses-permission android:name="android.permission.RECEIVE_BOOT_COMPLETED"/>

<application>
    <!-- ... otras configuraciones ... -->
    
    <!-- Firebase Messaging Service -->
    <service
        android:name="com.google.firebase.messaging.FirebaseMessagingService"
        android:exported="false">
        <intent-filter>
            <action android:name="com.google.firebase.MESSAGING_EVENT" />
        </intent-filter>
    </service>
    
    <!-- Notification Channel -->
    <meta-data
        android:name="com.google.firebase.messaging.default_notification_channel_id"
        android:value="oasis_taxi_channel"/>
    
    <!-- Notification Icon -->
    <meta-data
        android:name="com.google.firebase.messaging.default_notification_icon"
        android:resource="@drawable/ic_notification" />
    
    <!-- Notification Color -->
    <meta-data
        android:name="com.google.firebase.messaging.default_notification_color"
        android:resource="@color/colorPrimary" />
</application>
```

### 3. Crear ícono de notificación

Crear el ícono de notificación en `android/app/src/main/res/drawable/ic_notification.png` en diferentes densidades:
- mdpi: 24x24
- hdpi: 36x36
- xhdpi: 48x48
- xxhdpi: 72x72
- xxxhdpi: 96x96

## iOS

### 1. Configurar capacidades en Xcode

1. Abrir `ios/Runner.xcworkspace` en Xcode
2. Seleccionar el target Runner
3. En la pestaña "Signing & Capabilities":
   - Agregar "Push Notifications"
   - Agregar "Background Modes" y habilitar:
     - Remote notifications
     - Background fetch

### 2. Configurar Info.plist

Agregar en `ios/Runner/Info.plist`:

```xml
<key>UIBackgroundModes</key>
<array>
    <string>fetch</string>
    <string>remote-notification</string>
</array>

<key>FirebaseMessagingAutoInitEnabled</key>
<true/>
```

### 3. Configurar AppDelegate.swift

Actualizar `ios/Runner/AppDelegate.swift`:

```swift
import UIKit
import Flutter
import Firebase
import FirebaseMessaging

@UIApplicationMain
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    FirebaseApp.configure()
    
    // Configure notifications
    if #available(iOS 10.0, *) {
      UNUserNotificationCenter.current().delegate = self
      let authOptions: UNAuthorizationOptions = [.alert, .badge, .sound]
      UNUserNotificationCenter.current().requestAuthorization(
        options: authOptions,
        completionHandler: { _, _ in }
      )
    } else {
      let settings: UIUserNotificationSettings =
        UIUserNotificationSettings(types: [.alert, .badge, .sound], categories: nil)
      application.registerUserNotificationSettings(settings)
    }
    
    application.registerForRemoteNotifications()
    
    // Set messaging delegate
    Messaging.messaging().delegate = self
    
    GeneratedPluginRegistrant.register(with: self)
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
  
  override func application(_ application: UIApplication,
    didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
    Messaging.messaging().apnsToken = deviceToken
  }
}

extension AppDelegate: MessagingDelegate {
  func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String?) {
    print("Firebase registration token: \(String(describing: fcmToken))")
  }
}
```

### 4. Certificados de Push

1. Crear un App ID con Push Notifications habilitado en Apple Developer Portal
2. Crear certificado de producción APNs
3. Subir el certificado a Firebase Console en la configuración de iOS

## Tipos de Notificaciones

### Notificaciones de Viaje

- **ride_accepted**: Conductor aceptó el viaje
- **driver_arriving**: Conductor está llegando
- **ride_started**: Viaje iniciado
- **ride_completed**: Viaje completado
- **ride_cancelled**: Viaje cancelado

### Notificaciones de Pago

- **payment_success**: Pago exitoso
- **payment_failed**: Pago fallido
- **payment_method_added**: Método de pago agregado

### Notificaciones Promocionales

- **promotion**: Nueva promoción disponible
- **discount**: Descuento aplicado

## Testing

### Android
```bash
# Enviar notificación de prueba
curl -X POST https://fcm.googleapis.com/fcm/send \
  -H "Authorization: key=YOUR_SERVER_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "to": "FCM_TOKEN",
    "notification": {
      "title": "OASIS TAXI",
      "body": "Tu conductor está en camino"
    },
    "data": {
      "type": "driver_arriving",
      "ride_id": "123456"
    }
  }'
```

### iOS
- Usar la herramienta de notificaciones de prueba en Firebase Console
- Asegurarse de que el dispositivo tenga el certificado APNs correcto

## Troubleshooting

### Android
- Verificar que google-services.json esté en el lugar correcto
- Verificar que el package name coincida
- Revisar logcat para errores de FCM

### iOS
- Verificar que los certificados APNs estén configurados
- Verificar que las capacidades estén habilitadas
- Revisar la consola de Xcode para errores
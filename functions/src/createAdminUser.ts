import * as functions from 'firebase-functions';
import * as admin from 'firebase-admin';

export const createAdminUserOnce = functions.https.onRequest(async (req, res) => {
  try {
    const auth = admin.auth();
    const db = admin.firestore();

    const adminEmail = 'facturacion.rapiteam@gmail.com';
    const adminPassword = 'RappiTeam2026!$';

    // Crear usuario en Firebase Auth
    const userRecord = await auth.createUser({
      email: adminEmail,
      password: adminPassword,
      emailVerified: true, // Pre-verificado
      displayName: 'Administrador Rappi Team',
    });

    // Datos del documento de Firestore
    const adminData = {
      fullName: "Administrador Rappi Team",
      email: adminEmail,
      phone: "999999999",
      phoneVerified: true,
      emailVerified: true,
      profilePhotoUrl: "",
      userType: "admin",
      activeMode: "admin",
      currentMode: "admin",
      availableRoles: ["admin"],
      isDualAccount: false,
      isAdmin: true,
      adminLevel: "super_admin",
      permissions: [
        "users.read", "users.write", "users.delete",
        "drivers.read", "drivers.write", "drivers.approve", "drivers.reject", "drivers.documents.verify",
        "trips.read", "trips.write", "trips.cancel",
        "analytics.read", "promotions.read", "promotions.write",
        "settings.read", "settings.write", "reports.read", "system.manage"
      ],
      rating: 5,
      totalTrips: 0,
      balance: 0,
      isActive: true,
      isVerified: true,
      twoFactorEnabled: false,
      deviceInfo: { trustedDevices: [], lastDeviceId: "" },
      securitySettings: {
        loginAttempts: 0,
        passwordHistory: [],
        lastPasswordChange: admin.firestore.FieldValue.serverTimestamp()
      },
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      lastLoginAt: null,
      fcmToken: "",
      fcmTokenUpdatedAt: null,
      phoneHash: ""
    };

    // Crear documento en Firestore con el UID del usuario
    await db.collection('users').doc(userRecord.uid).set(adminData);

    res.status(200).send({
      success: true,
      message: '✅ Usuario admin creado exitosamente',
      uid: userRecord.uid,
      email: adminEmail
    });
  } catch (error: any) {
    console.error('Error creating admin:', error);
    res.status(500).send({
      success: false,
      error: error.message
    });
  }
});

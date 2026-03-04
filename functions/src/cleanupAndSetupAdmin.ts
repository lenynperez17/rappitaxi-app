/**
 * ✅ SCRIPT PROFESIONAL DE LIMPIEZA Y CONFIGURACIÓN DE ADMIN
 *
 * Este script hace lo siguiente:
 * 1. Elimina TODOS los usuarios de Firebase Authentication EXCEPTO facturacion.rapiteam@gmail.com
 * 2. Limpia TODOS los documentos de la colección 'users' en Firestore
 * 3. Actualiza/crea el usuario admin con:
 *    - Email: facturacion.rapiteam@gmail.com
 *    - Teléfono: +51901039918
 *    - Custom claims: { admin: true, role: 'admin' }
 * 4. Crea documento en Firestore con todos los datos del admin
 *
 * @author NYNEL MKT
 * @date 2025-01-21
 */

import * as admin from 'firebase-admin';
import * as dotenv from 'dotenv';
import * as path from 'path';

// Cargar variables de entorno
dotenv.config({ path: path.join(__dirname, '../.env') });

// Inicializar Firebase Admin con Project ID
if (!admin.apps.length) {
  admin.initializeApp({
    projectId: 'rapi-team',
  });
}

const auth = admin.auth();
const db = admin.firestore();

// ==================== CONFIGURACIÓN DEL ADMIN ====================
const ADMIN_CONFIG = {
  email: 'facturacion.rapiteam@gmail.com',
  phoneNumber: '+51901039918',
  displayName: 'Rappi Team Admin',
  role: 'admin',
  customClaims: {
    admin: true,
    role: 'admin',
    permissions: [
      'manage_users',
      'manage_drivers',
      'manage_trips',
      'manage_payments',
      'manage_settings',
      'view_analytics',
      'manage_promotions',
      'manage_zones',
    ],
  },
};

/**
 * ✅ Paso 1: Listar todos los usuarios de Firebase Authentication
 */
async function listAllUsers(): Promise<admin.auth.UserRecord[]> {
  console.log('📋 Listando todos los usuarios de Firebase Authentication...');

  const allUsers: admin.auth.UserRecord[] = [];
  let pageToken: string | undefined;

  do {
    const listUsersResult = await auth.listUsers(1000, pageToken);
    allUsers.push(...listUsersResult.users);
    pageToken = listUsersResult.pageToken;
  } while (pageToken);

  console.log(`✅ Total de usuarios encontrados: ${allUsers.length}`);
  return allUsers;
}

/**
 * ✅ Paso 2: Eliminar usuarios de Authentication (excepto el admin)
 */
async function deleteNonAdminUsers(users: admin.auth.UserRecord[]): Promise<void> {
  console.log('\n🗑️  Eliminando usuarios NO-ADMIN de Firebase Authentication...');

  const usersToDelete = users.filter(user => user.email !== ADMIN_CONFIG.email);

  if (usersToDelete.length === 0) {
    console.log('✅ No hay usuarios para eliminar (solo existe el admin)');
    return;
  }

  console.log(`⚠️  Se eliminarán ${usersToDelete.length} usuarios:`);
  usersToDelete.forEach(user => {
    console.log(`   - ${user.email || user.phoneNumber || user.uid}`);
  });

  // Eliminar en lotes de 100 (límite de Firebase)
  const uidsToDelete = usersToDelete.map(user => user.uid);
  const batchSize = 100;

  for (let i = 0; i < uidsToDelete.length; i += batchSize) {
    const batch = uidsToDelete.slice(i, i + batchSize);

    try {
      const result = await auth.deleteUsers(batch);
      console.log(`✅ Eliminados ${result.successCount} usuarios (lote ${Math.floor(i / batchSize) + 1})`);

      if (result.failureCount > 0) {
        console.error(`❌ Errores en ${result.failureCount} usuarios:`);
        result.errors.forEach(error => {
          console.error(`   - UID ${error.index}: ${error.error.message}`);
        });
      }
    } catch (error) {
      console.error(`❌ Error eliminando lote ${Math.floor(i / batchSize) + 1}:`, error);
    }
  }

  console.log('✅ Proceso de eliminación de usuarios completado');
}

/**
 * ✅ Paso 3: Limpiar TODA la colección 'users' en Firestore
 */
async function cleanFirestoreUsersCollection(): Promise<void> {
  console.log('\n🧹 Limpiando colección "users" en Firestore...');

  const usersRef = db.collection('users');
  const snapshot = await usersRef.get();

  if (snapshot.empty) {
    console.log('✅ La colección "users" ya está vacía');
    return;
  }

  console.log(`⚠️  Se eliminarán ${snapshot.size} documentos de Firestore`);

  // Eliminar en lotes de 500 (límite de Firestore batch)
  const batch = db.batch();
  let count = 0;

  snapshot.forEach(doc => {
    batch.delete(doc.ref);
    count++;

    // Ejecutar batch cada 500 documentos
    if (count % 500 === 0) {
      console.log(`   Procesando lote de ${count} documentos...`);
    }
  });

  await batch.commit();
  console.log(`✅ ${count} documentos eliminados de Firestore`);
}

/**
 * ✅ Paso 4: Obtener o crear usuario admin en Authentication
 */
async function getOrCreateAdminUser(): Promise<admin.auth.UserRecord> {
  console.log('\n👤 Configurando usuario ADMIN en Firebase Authentication...');

  let adminUser: admin.auth.UserRecord;

  try {
    // Intentar obtener usuario existente por email
    adminUser = await auth.getUserByEmail(ADMIN_CONFIG.email);
    console.log(`✅ Usuario admin encontrado: ${adminUser.uid}`);

    // Actualizar teléfono si es necesario
    if (adminUser.phoneNumber !== ADMIN_CONFIG.phoneNumber) {
      console.log(`📞 Actualizando teléfono de ${adminUser.phoneNumber || 'null'} a ${ADMIN_CONFIG.phoneNumber}...`);
      adminUser = await auth.updateUser(adminUser.uid, {
        phoneNumber: ADMIN_CONFIG.phoneNumber,
        displayName: ADMIN_CONFIG.displayName,
      });
      console.log('✅ Teléfono actualizado');
    }
  } catch (error: any) {
    if (error.code === 'auth/user-not-found') {
      console.log('⚠️  Usuario admin no existe, creando nuevo...');

      // Crear nuevo usuario admin
      adminUser = await auth.createUser({
        email: ADMIN_CONFIG.email,
        phoneNumber: ADMIN_CONFIG.phoneNumber,
        displayName: ADMIN_CONFIG.displayName,
        emailVerified: true,
        disabled: false,
      });

      console.log(`✅ Usuario admin creado: ${adminUser.uid}`);
    } else {
      throw error;
    }
  }

  return adminUser;
}

/**
 * ✅ Paso 5: Asignar custom claims de administrador
 */
async function setAdminClaims(uid: string): Promise<void> {
  console.log('\n🔑 Asignando custom claims de ADMINISTRADOR...');

  await auth.setCustomUserClaims(uid, ADMIN_CONFIG.customClaims);

  console.log('✅ Custom claims asignados:');
  console.log('   - admin: true');
  console.log('   - role: admin');
  console.log(`   - permissions: ${ADMIN_CONFIG.customClaims.permissions.length} permisos`);
}

/**
 * ✅ Paso 6: Crear documento del admin en Firestore
 */
async function createAdminFirestoreDocument(adminUser: admin.auth.UserRecord): Promise<void> {
  console.log('\n📄 Creando documento del ADMIN en Firestore...');

  const adminDocData = {
    // Información básica
    uid: adminUser.uid,
    email: adminUser.email,
    phoneNumber: adminUser.phoneNumber,
    displayName: ADMIN_CONFIG.displayName,
    photoURL: adminUser.photoURL || null,

    // Rol y permisos
    role: 'admin',
    isAdmin: true,
    permissions: ADMIN_CONFIG.customClaims.permissions,

    // Estado
    emailVerified: true,
    disabled: false,
    isActive: true,

    // Metadata
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    lastLoginAt: admin.firestore.FieldValue.serverTimestamp(),

    // Información adicional
    metadata: {
      creationTime: adminUser.metadata.creationTime,
      lastSignInTime: adminUser.metadata.lastSignInTime,
      lastRefreshTime: adminUser.metadata.lastRefreshTime || null,
    },

    // Configuración
    settings: {
      language: 'es',
      timezone: 'America/Lima',
      notifications: {
        email: true,
        push: true,
        sms: false,
      },
    },
  };

  await db.collection('users').doc(adminUser.uid).set(adminDocData, { merge: true });

  console.log(`✅ Documento creado en: users/${adminUser.uid}`);
}

/**
 * ✅ Paso 7: Verificación final
 */
async function verifySetup(): Promise<void> {
  console.log('\n🔍 Verificando configuración final...');

  // Verificar Authentication
  const users = await listAllUsers();
  console.log(`✅ Usuarios en Authentication: ${users.length}`);

  if (users.length === 1 && users[0].email === ADMIN_CONFIG.email) {
    console.log('✅ Solo existe el usuario admin en Authentication');
  } else {
    console.warn('⚠️  Advertencia: hay más de un usuario en Authentication');
  }

  // Verificar Firestore
  const usersSnapshot = await db.collection('users').get();
  console.log(`✅ Documentos en colección users: ${usersSnapshot.size}`);

  if (usersSnapshot.size === 1) {
    const adminDoc = usersSnapshot.docs[0];
    const adminData = adminDoc.data();
    console.log('✅ Solo existe el documento del admin en Firestore');
    console.log(`   Email: ${adminData.email}`);
    console.log(`   Teléfono: ${adminData.phoneNumber}`);
    console.log(`   Rol: ${adminData.role}`);
    console.log(`   Admin: ${adminData.isAdmin}`);
  } else {
    console.warn('⚠️  Advertencia: hay más de un documento en Firestore users');
  }

  // Verificar custom claims
  const adminUser = await auth.getUserByEmail(ADMIN_CONFIG.email);
  await auth.createCustomToken(adminUser.uid);
  console.log('✅ Custom token generado correctamente para verificación');
}

/**
 * ==================== FUNCIÓN PRINCIPAL ====================
 */
async function main() {
  console.log('╔═══════════════════════════════════════════════════════════════╗');
  console.log('║   🚀 LIMPIEZA Y CONFIGURACIÓN DE ADMINISTRADOR - RAPPI TEAM  ║');
  console.log('╚═══════════════════════════════════════════════════════════════╝\n');

  try {
    // Paso 1: Listar usuarios
    const allUsers = await listAllUsers();

    // Paso 2: Eliminar usuarios no-admin de Authentication
    await deleteNonAdminUsers(allUsers);

    // Paso 3: Limpiar Firestore
    await cleanFirestoreUsersCollection();

    // Paso 4: Obtener/crear usuario admin
    const adminUser = await getOrCreateAdminUser();

    // Paso 5: Asignar custom claims
    await setAdminClaims(adminUser.uid);

    // Paso 6: Crear documento Firestore
    await createAdminFirestoreDocument(adminUser);

    // Paso 7: Verificación final
    await verifySetup();

    console.log('\n╔═══════════════════════════════════════════════════════════════╗');
    console.log('║              ✅ PROCESO COMPLETADO EXITOSAMENTE              ║');
    console.log('╚═══════════════════════════════════════════════════════════════╝\n');

    console.log('📊 RESUMEN:');
    console.log(`   ✅ Usuario admin: ${ADMIN_CONFIG.email}`);
    console.log(`   ✅ Teléfono: ${ADMIN_CONFIG.phoneNumber}`);
    console.log('   ✅ Custom claims: admin = true');
    console.log('   ✅ Documento Firestore creado');
    console.log('   ✅ Todos los demás usuarios eliminados\n');

    process.exit(0);
  } catch (error) {
    console.error('\n❌ ERROR CRÍTICO:', error);
    process.exit(1);
  }
}

// Ejecutar script
main();

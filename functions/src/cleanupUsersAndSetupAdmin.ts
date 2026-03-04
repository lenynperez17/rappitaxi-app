/**
 * ✅ CLOUD FUNCTION PARA LIMPIEZA DE USUARIOS Y CONFIGURACIÓN DE ADMIN
 *
 * Esta función HTTP hace lo siguiente:
 * 1. Lista todos los usuarios de Firebase Authentication
 * 2. Elimina todos EXCEPTO facturacion.rapiteam@gmail.com
 * 3. Limpia toda la colección 'users' de Firestore
 * 4. Actualiza el usuario admin con teléfono +51901039918
 * 5. Asigna custom claims de admin
 * 6. Crea documento completo en Firestore
 *
 * @author NYNEL MKT
 * @date 2025-01-21
 */

import { onRequest } from 'firebase-functions/v2/https';
import * as admin from 'firebase-admin';

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

export const cleanupUsersAndSetupAdmin = onRequest(
  {
    timeoutSeconds: 540, // 9 minutos
    memory: '512MiB',
    maxInstances: 1,
  },
  async (req, res) => {
    const auth = admin.auth();
    const db = admin.firestore();
    const logs: string[] = [];

    try {
      logs.push('╔═══════════════════════════════════════════════════════════════╗');
      logs.push('║   🚀 LIMPIEZA Y CONFIGURACIÓN DE ADMINISTRADOR - RAPPI TEAM  ║');
      logs.push('╚═══════════════════════════════════════════════════════════════╝');
      logs.push('');

      // ============================================================
      // PASO 1: LISTAR TODOS LOS USUARIOS
      // ============================================================
      logs.push('📋 PASO 1: Listando todos los usuarios de Firebase Authentication...');

      const allUsers: admin.auth.UserRecord[] = [];
      let pageToken: string | undefined;

      do {
        const listUsersResult = await auth.listUsers(1000, pageToken);
        allUsers.push(...listUsersResult.users);
        pageToken = listUsersResult.pageToken;
      } while (pageToken);

      logs.push(`✅ Total de usuarios encontrados: ${allUsers.length}`);
      logs.push('');

      // ============================================================
      // PASO 2: ELIMINAR USUARIOS NO-ADMIN
      // ============================================================
      logs.push('🗑️  PASO 2: Eliminando usuarios NO-ADMIN de Firebase Authentication...');

      const usersToDelete = allUsers.filter(user => user.email !== ADMIN_CONFIG.email);

      if (usersToDelete.length === 0) {
        logs.push('✅ No hay usuarios para eliminar (solo existe el admin)');
      } else {
        logs.push(`⚠️  Se eliminarán ${usersToDelete.length} usuarios:`);
        usersToDelete.forEach(user => {
          logs.push(`   - ${user.email || user.phoneNumber || user.uid}`);
        });

        // Eliminar en lotes de 100 (límite de Firebase)
        const uidsToDelete = usersToDelete.map(user => user.uid);
        const batchSize = 100;

        for (let i = 0; i < uidsToDelete.length; i += batchSize) {
          const batch = uidsToDelete.slice(i, i + batchSize);

          try {
            const result = await auth.deleteUsers(batch);
            logs.push(`✅ Eliminados ${result.successCount} usuarios (lote ${Math.floor(i / batchSize) + 1})`);

            if (result.failureCount > 0) {
              logs.push(`❌ Errores en ${result.failureCount} usuarios:`);
              result.errors.forEach(error => {
                logs.push(`   - UID ${error.index}: ${error.error.message}`);
              });
            }
          } catch (error: any) {
            logs.push(`❌ Error eliminando lote ${Math.floor(i / batchSize) + 1}: ${error.message}`);
          }
        }
      }

      logs.push('✅ Proceso de eliminación de usuarios completado');
      logs.push('');

      // ============================================================
      // PASO 3: LIMPIAR COLECCIÓN 'users' DE FIRESTORE
      // ============================================================
      logs.push('🧹 PASO 3: Limpiando colección "users" en Firestore...');

      const usersRef = db.collection('users');
      const snapshot = await usersRef.get();

      if (snapshot.empty) {
        logs.push('✅ La colección "users" ya está vacía');
      } else {
        logs.push(`⚠️  Se eliminarán ${snapshot.size} documentos de Firestore`);

        // Eliminar en lotes de 500 (límite de Firestore batch)
        const batch = db.batch();
        let count = 0;

        snapshot.forEach(doc => {
          batch.delete(doc.ref);
          count++;
        });

        await batch.commit();
        logs.push(`✅ ${count} documentos eliminados de Firestore`);
      }

      logs.push('');

      // ============================================================
      // PASO 4: OBTENER O CREAR USUARIO ADMIN
      // ============================================================
      logs.push('👤 PASO 4: Configurando usuario ADMIN en Firebase Authentication...');

      let adminUser: admin.auth.UserRecord;

      try {
        // Intentar obtener usuario existente por email
        adminUser = await auth.getUserByEmail(ADMIN_CONFIG.email);
        logs.push(`✅ Usuario admin encontrado: ${adminUser.uid}`);

        // Actualizar teléfono si es necesario
        if (adminUser.phoneNumber !== ADMIN_CONFIG.phoneNumber) {
          logs.push(`📞 Actualizando teléfono de ${adminUser.phoneNumber || 'null'} a ${ADMIN_CONFIG.phoneNumber}...`);
          adminUser = await auth.updateUser(adminUser.uid, {
            phoneNumber: ADMIN_CONFIG.phoneNumber,
            displayName: ADMIN_CONFIG.displayName,
          });
          logs.push('✅ Teléfono actualizado');
        }
      } catch (error: any) {
        if (error.code === 'auth/user-not-found') {
          logs.push('⚠️  Usuario admin no existe, creando nuevo...');

          // Crear nuevo usuario admin
          adminUser = await auth.createUser({
            email: ADMIN_CONFIG.email,
            phoneNumber: ADMIN_CONFIG.phoneNumber,
            displayName: ADMIN_CONFIG.displayName,
            emailVerified: true,
            disabled: false,
          });

          logs.push(`✅ Usuario admin creado: ${adminUser.uid}`);
        } else {
          throw error;
        }
      }

      logs.push('');

      // ============================================================
      // PASO 5: ASIGNAR CUSTOM CLAIMS DE ADMINISTRADOR
      // ============================================================
      logs.push('🔑 PASO 5: Asignando custom claims de ADMINISTRADOR...');

      await auth.setCustomUserClaims(adminUser.uid, ADMIN_CONFIG.customClaims);

      logs.push('✅ Custom claims asignados:');
      logs.push('   - admin: true');
      logs.push('   - role: admin');
      logs.push(`   - permissions: ${ADMIN_CONFIG.customClaims.permissions.length} permisos`);
      logs.push('');

      // ============================================================
      // PASO 6: CREAR DOCUMENTO DEL ADMIN EN FIRESTORE
      // ============================================================
      logs.push('📄 PASO 6: Creando documento del ADMIN en Firestore...');

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

      logs.push(`✅ Documento creado en: users/${adminUser.uid}`);
      logs.push('');

      // ============================================================
      // PASO 7: VERIFICACIÓN FINAL
      // ============================================================
      logs.push('🔍 PASO 7: Verificando configuración final...');

      // Verificar Authentication
      const allUsersAfter: admin.auth.UserRecord[] = [];
      let pageTokenAfter: string | undefined;

      do {
        const listUsersResult = await auth.listUsers(1000, pageTokenAfter);
        allUsersAfter.push(...listUsersResult.users);
        pageTokenAfter = listUsersResult.pageToken;
      } while (pageTokenAfter);

      logs.push(`✅ Usuarios en Authentication: ${allUsersAfter.length}`);

      if (allUsersAfter.length === 1 && allUsersAfter[0].email === ADMIN_CONFIG.email) {
        logs.push('✅ Solo existe el usuario admin en Authentication');
      } else {
        logs.push('⚠️  Advertencia: hay más de un usuario en Authentication');
      }

      // Verificar Firestore
      const usersSnapshotAfter = await db.collection('users').get();
      logs.push(`✅ Documentos en colección users: ${usersSnapshotAfter.size}`);

      if (usersSnapshotAfter.size === 1) {
        const adminDoc = usersSnapshotAfter.docs[0];
        const adminData = adminDoc.data();
        logs.push('✅ Solo existe el documento del admin en Firestore');
        logs.push(`   Email: ${adminData.email}`);
        logs.push(`   Teléfono: ${adminData.phoneNumber}`);
        logs.push(`   Rol: ${adminData.role}`);
        logs.push(`   Admin: ${adminData.isAdmin}`);
      } else {
        logs.push('⚠️  Advertencia: hay más de un documento en Firestore users');
      }

      logs.push('');
      logs.push('╔═══════════════════════════════════════════════════════════════╗');
      logs.push('║              ✅ PROCESO COMPLETADO EXITOSAMENTE              ║');
      logs.push('╚═══════════════════════════════════════════════════════════════╝');
      logs.push('');
      logs.push('📊 RESUMEN:');
      logs.push(`   ✅ Usuario admin: ${ADMIN_CONFIG.email}`);
      logs.push(`   ✅ Teléfono: ${ADMIN_CONFIG.phoneNumber}`);
      logs.push('   ✅ Custom claims: admin = true');
      logs.push('   ✅ Documento Firestore creado');
      logs.push('   ✅ Todos los demás usuarios eliminados');

      // Enviar respuesta exitosa
      res.status(200).json({
        success: true,
        message: '✅ Limpieza y configuración completada exitosamente',
        logs: logs,
        summary: {
          adminEmail: ADMIN_CONFIG.email,
          adminPhone: ADMIN_CONFIG.phoneNumber,
          usersDeletedCount: usersToDelete.length,
          firestoreDocsDeleted: snapshot.size,
          finalUserCount: allUsersAfter.length,
          finalFirestoreCount: usersSnapshotAfter.size,
        },
      });
    } catch (error: any) {
      logs.push('');
      logs.push('❌ ERROR CRÍTICO:');
      logs.push(error.message);
      logs.push('');
      logs.push('Stack trace:');
      logs.push(error.stack);

      console.error('❌ ERROR CRÍTICO:', error);

      res.status(500).json({
        success: false,
        error: error.message,
        logs: logs,
      });
    }
  }
);

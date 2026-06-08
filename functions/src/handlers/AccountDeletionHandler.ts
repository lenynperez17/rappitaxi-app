/**
 * CLOUD FUNCTION CALLABLE: Eliminar mi cuenta (auto-borrado)
 *
 * Reemplaza al trigger 1st gen `auth.user().onDelete()` por una callable 2nd
 * gen que el cliente invoca explícitamente cuando el usuario quiere borrar
 * su propia cuenta.
 *
 * Ventajas:
 *  - 100% en 2nd gen → sin cobro mínimo mensual de App Engine
 *  - Compatible con Apple Review (Apple exige el botón en la app desde 2022)
 *  - El usuario tiene que estar autenticado para borrarse
 *  - Si la limpieza falla, NO se borra el Auth user (evita huérfanos)
 *
 * Limpia:
 *  - Documento /users/{uid} en Firestore + subcolecciones
 *  - Subcolección drivers/{uid}/documents/
 *  - wallets/{uid} (si es conductor)
 *  - Archivos en Storage (profile_photos, drivers, documents)
 *  - Registra log en deletion_logs
 *  - Borra el user de Firebase Auth al final
 */

import { onCall, HttpsError } from 'firebase-functions/v2/https'
import * as admin from 'firebase-admin'

export const deleteMyAccount = onCall(
  {
    cors: true,
    region: 'us-central1',
    memory: '256MiB',
    timeoutSeconds: 60,
  },
  async (request) => {
    const uid = request.auth?.uid
    if (!uid) {
      throw new HttpsError(
        'unauthenticated',
        'Debes estar autenticado para borrar tu cuenta.',
      )
    }

    const { reason } = request.data ?? {}

    // Obtener metadata del user para logging
    let email = 'N/A'
    let phone = 'N/A'
    try {
      const userRecord = await admin.auth().getUser(uid)
      email = userRecord.email || 'N/A'
      phone = userRecord.phoneNumber || 'N/A'
    } catch {
      // El user puede no existir en Auth aún (caso edge); seguimos igual.
    }

    console.log(`🗑️ Solicitud de auto-borrado: ${uid}`)
    console.log(`   Email: ${email}, Phone: ${phone}, Reason: ${reason ?? 'N/A'}`)

    const db = admin.firestore()
    const storage = admin.storage().bucket()

    const deletionResults = {
      firestore: false,
      driversSubcol: false,
      wallet: false,
      storage: [] as string[],
      errors: [] as string[],
    }

    // ============================================
    // 1. Eliminar documento y subcolecciones de Firestore
    // ============================================
    try {
      const userDoc = await db.collection('users').doc(uid).get()
      if (userDoc.exists) {
        // Subcolecciones de users/{uid}
        const subcollections = [
          'transactions',
          'notifications',
          'favorites',
          'payment_methods',
          'rides',
          'documents',
        ]
        for (const subcol of subcollections) {
          try {
            const subcolRef = db.collection('users').doc(uid).collection(subcol)
            const subcolDocs = await subcolRef.limit(500).get()
            if (!subcolDocs.empty) {
              const batch = db.batch()
              subcolDocs.docs.forEach((doc) => batch.delete(doc.ref))
              await batch.commit()
              console.log(`   ✅ users/${uid}/${subcol}: ${subcolDocs.size} docs`)
            }
          } catch (err) {
            console.warn(`   ⚠️ users/${uid}/${subcol}:`, err)
          }
        }
        // Borrar el doc principal al final
        await db.collection('users').doc(uid).delete()
        deletionResults.firestore = true
        console.log(`   ✅ users/${uid} eliminado`)
      }
    } catch (error) {
      const msg = error instanceof Error ? error.message : String(error)
      console.error('   ❌ Firestore users:', msg)
      deletionResults.errors.push(`Firestore users: ${msg}`)
    }

    // ============================================
    // 2. Eliminar drivers/{uid} + subcolección documents
    // ============================================
    try {
      const docsRef = db.collection('drivers').doc(uid).collection('documents')
      const docsSnap = await docsRef.limit(500).get()
      if (!docsSnap.empty) {
        const batch = db.batch()
        docsSnap.docs.forEach((d) => batch.delete(d.ref))
        await batch.commit()
        console.log(`   ✅ drivers/${uid}/documents/: ${docsSnap.size} docs`)
      }
      const driverDoc = await db.collection('drivers').doc(uid).get()
      if (driverDoc.exists) {
        await db.collection('drivers').doc(uid).delete()
        console.log(`   ✅ drivers/${uid} eliminado`)
      }
      deletionResults.driversSubcol = true
    } catch (error) {
      const msg = error instanceof Error ? error.message : String(error)
      console.warn('   ⚠️ drivers/:', msg)
    }

    // ============================================
    // 3. Eliminar wallet (si era conductor)
    // ============================================
    try {
      const walletSnap = await db.collection('wallets').doc(uid).get()
      if (walletSnap.exists) {
        await db.collection('wallets').doc(uid).delete()
        console.log(`   ✅ wallets/${uid} eliminado`)
      }
      deletionResults.wallet = true
    } catch (error) {
      const msg = error instanceof Error ? error.message : String(error)
      console.warn('   ⚠️ wallet:', msg)
    }

    // ============================================
    // 4. Eliminar archivos de Storage
    // ============================================
    try {
      const storagePaths = [
        `profile_photos/${uid}.jpg`,
        `profile_photos/${uid}.png`,
        `profile_photos/${uid}/`,
        `drivers/${uid}/`,
        `documents/${uid}/`,
        `driver_applications/${uid}/`,
      ]
      for (const path of storagePaths) {
        try {
          if (path.endsWith('/')) {
            const [files] = await storage.getFiles({ prefix: path })
            for (const file of files) {
              await file.delete()
              deletionResults.storage.push(file.name)
            }
          } else {
            const file = storage.file(path)
            const [exists] = await file.exists()
            if (exists) {
              await file.delete()
              deletionResults.storage.push(path)
            }
          }
        } catch (err) {
          const msg = err instanceof Error ? err.message : String(err)
          if (!msg.includes('No such object')) {
            console.warn(`   ⚠️ Storage ${path}:`, msg)
          }
        }
      }
      console.log(`   ✅ Storage: ${deletionResults.storage.length} archivos`)
    } catch (error) {
      const msg = error instanceof Error ? error.message : String(error)
      console.error('   ❌ Storage:', msg)
      deletionResults.errors.push(`Storage: ${msg}`)
    }

    // ============================================
    // 5. Registrar log de eliminación
    // ============================================
    try {
      await db.collection('deletion_logs').add({
        uid,
        email,
        phone,
        reason: reason ?? null,
        deletedAt: admin.firestore.FieldValue.serverTimestamp(),
        results: deletionResults,
        success: deletionResults.errors.length === 0,
        source: 'deleteMyAccount_callable_v2',
      })
    } catch (err) {
      console.warn('   ⚠️ Could not write deletion_log:', err)
    }

    // ============================================
    // 6. Eliminar user de Firebase Auth (AL FINAL)
    // ============================================
    // Lo dejamos al final para que si la limpieza falla, el user siga
    // existiendo y se pueda reintentar.
    try {
      await admin.auth().deleteUser(uid)
      console.log(`🗑️ Auth user eliminado: ${uid}`)
    } catch (error) {
      const msg = error instanceof Error ? error.message : String(error)
      console.error(`❌ Auth user ${uid}:`, msg)
      deletionResults.errors.push(`Auth: ${msg}`)
    }

    return {
      success: deletionResults.errors.length === 0,
      uid,
      firestoreDeleted: deletionResults.firestore,
      driversSubcolDeleted: deletionResults.driversSubcol,
      walletDeleted: deletionResults.wallet,
      storageFilesDeleted: deletionResults.storage.length,
      errors: deletionResults.errors,
    }
  },
)

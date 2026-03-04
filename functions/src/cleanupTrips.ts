/**
 * Script de limpieza de colección obsoleta 'trips'
 *
 * Este script elimina TODOS los documentos de la colección 'trips' que fue
 * reemplazada por la colección 'rides'. Solo debe ejecutarse UNA VEZ.
 *
 * ADVERTENCIA: Esta operación es IRREVERSIBLE
 *
 * Uso:
 * 1. Desplegar esta función: firebase deploy --only functions:cleanupTripsCollection
 * 2. Ejecutar manualmente desde Firebase Console o con gcloud:
 *    gcloud functions call cleanupTripsCollection --data '{}'
 *
 * O ejecutar directamente con:
 * npx ts-node cleanupTrips.ts
 */

import * as admin from "firebase-admin";
import { onCall, HttpsError } from "firebase-functions/v2/https";

// Inicializar Firebase Admin si no está inicializado
if (!admin.apps.length) {
  admin.initializeApp();
}

const db = admin.firestore();

/**
 * Elimina todos los documentos de la colección 'trips' en batches
 */
async function cleanupTripsCollection(): Promise<{
  success: boolean;
  deletedCount: number;
  errors: string[];
  duration: number;
}> {
  const startTime = Date.now();
  let deletedCount = 0;
  const errors: string[] = [];
  const batchSize = 500; // Firestore permite máximo 500 operaciones por batch

  try {
    console.log("🗑️  Iniciando limpieza de colección 'trips'...");
    console.log(`📊 Tamaño de batch: ${batchSize} documentos`);

    let hasMore = true;

    while (hasMore) {
      // Obtener batch de documentos
      const snapshot = await db
        .collection("trips")
        .limit(batchSize)
        .get();

      // Si no hay más documentos, terminar
      if (snapshot.empty) {
        hasMore = false;
        console.log("✅ No hay más documentos para eliminar");
        break;
      }

      console.log(`📦 Procesando batch de ${snapshot.size} documentos...`);

      // Crear batch para eliminación
      const batch = db.batch();

      snapshot.docs.forEach((doc) => {
        batch.delete(doc.ref);
        deletedCount++;
      });

      // Ejecutar batch
      try {
        await batch.commit();
        console.log(`✅ Batch eliminado exitosamente: ${snapshot.size} documentos`);
        console.log(`📈 Total eliminado hasta ahora: ${deletedCount}`);
      } catch (batchError) {
        const errorMsg = `Error eliminando batch: ${batchError}`;
        console.error(`❌ ${errorMsg}`);
        errors.push(errorMsg);
      }

      // Pequeña pausa entre batches para no sobrecargar Firestore
      await new Promise((resolve) => setTimeout(resolve, 100));
    }

    const duration = Date.now() - startTime;

    console.log("\n" + "=".repeat(60));
    console.log("✅ LIMPIEZA COMPLETADA");
    console.log("=".repeat(60));
    console.log(`📊 Total de documentos eliminados: ${deletedCount}`);
    console.log(`⏱️  Duración: ${(duration / 1000).toFixed(2)} segundos`);
    console.log(`❌ Errores encontrados: ${errors.length}`);
    if (errors.length > 0) {
      console.log("\nErrores:");
      errors.forEach((err, idx) => {
        console.log(`  ${idx + 1}. ${err}`);
      });
    }
    console.log("=".repeat(60) + "\n");

    return {
      success: errors.length === 0,
      deletedCount,
      errors,
      duration,
    };
  } catch (error) {
    const errorMsg = `Error fatal durante limpieza: ${error}`;
    console.error(`❌ ${errorMsg}`);
    errors.push(errorMsg);

    return {
      success: false,
      deletedCount,
      errors,
      duration: Date.now() - startTime,
    };
  }
}

/**
 * Cloud Function callable para ejecutar la limpieza
 * Solo puede ser ejecutada por administradores
 * ✅ ACTUALIZADO: Usa Firebase Functions V2
 */
export const cleanupTripsCollection_callable = onCall(async (request) => {
  // Verificar que el usuario está autenticado
  if (!request.auth) {
    throw new HttpsError(
      "unauthenticated",
      "Debes estar autenticado para ejecutar esta función"
    );
  }

  // Verificar que el usuario es administrador
  const userDoc = await db.collection("users").doc(request.auth.uid).get();
  const userData = userDoc.data();

  if (!userData || userData.userType !== "admin") {
    throw new HttpsError(
      "permission-denied",
      "Solo los administradores pueden ejecutar esta función"
    );
  }

  console.log(
    `🔐 Admin autorizado: ${request.auth.uid} (${userData.email})`
  );
  console.log("⚠️  ADVERTENCIA: Ejecutando limpieza de colección 'trips'");
  console.log("⚠️  Esta operación es IRREVERSIBLE");

  // Ejecutar limpieza
  const result = await cleanupTripsCollection();

  return result;
});

/**
 * Exportar función para ejecución directa con ts-node
 * ⚠️ DESHABILITADO: No compatible con Firebase Functions V2
 *
 * Para ejecutar manualmente, usar Firebase Console o callable function desde la app
 */

export default cleanupTripsCollection;

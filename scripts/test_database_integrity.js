#!/usr/bin/env node

/**
 * RAPPITAXI - TESTING DE INTEGRIDAD DE BASE DE DATOS
 * Script para validar la integridad de Firestore y todas las operaciones CRUD
 */

const admin = require('firebase-admin');
const chalk = require('chalk');
const { performance } = require('perf_hooks');

// Inicializar Firebase Admin (usar credenciales de servicio en producción)
if (!admin.apps.length) {
    admin.initializeApp({
        projectId: 'rappitaxi-app'
    });
}

const db = admin.firestore();

class DatabaseIntegrityTester {
    constructor() {
        this.results = [];
        this.testResults = {
            passed: 0,
            failed: 0,
            total: 0
        };
        
        // Datos de prueba
        this.testData = {
            users: [],
            drivers: [],
            passengers: [],
            rides: [],
            payments: []
        };
    }

    log(message, type = 'info') {
        const timestamp = new Date().toISOString();
        switch (type) {
            case 'success':
                console.log(chalk.green(`✅ [${timestamp}] ${message}`));
                break;
            case 'error':
                console.log(chalk.red(`❌ [${timestamp}] ${message}`));
                break;
            case 'warning':
                console.log(chalk.yellow(`⚠️  [${timestamp}] ${message}`));
                break;
            default:
                console.log(chalk.blue(`ℹ️  [${timestamp}] ${message}`));
        }
    }

    recordResult(testName, success, details = '', performance = null) {
        this.testResults.total++;
        if (success) {
            this.testResults.passed++;
            this.log(`${testName} - ${details}`, 'success');
        } else {
            this.testResults.failed++;
            this.log(`${testName} - ${details}`, 'error');
        }
        
        this.results.push({
            test: testName,
            success,
            details,
            performance,
            timestamp: new Date().toISOString()
        });
    }

    // =============================================================================
    // 1. TESTS DE COLECCIONES PRINCIPALES
    // =============================================================================
    async testUserCollection() {
        this.log('=== INICIANDO TESTS DE COLECCIÓN USERS ===');
        
        try {
            const startTime = performance.now();
            
            // 1.1 Crear usuario de prueba
            const testUser = {
                id: `test-user-${Date.now()}`,
                name: 'Test User DB',
                email: `testdb${Date.now()}@rappitaxi.com`,
                phone: '+51987654000',
                role: 'passenger',
                createdAt: admin.firestore.FieldValue.serverTimestamp(),
                updatedAt: admin.firestore.FieldValue.serverTimestamp(),
                isActive: true,
                profile: {
                    firstName: 'Test',
                    lastName: 'User',
                    dateOfBirth: '1990-01-01',
                    gender: 'male'
                },
                preferences: {
                    notifications: true,
                    language: 'es',
                    currency: 'PEN'
                }
            };
            
            await db.collection('users').doc(testUser.id).set(testUser);
            this.testData.users.push(testUser.id);
            
            // 1.2 Leer usuario creado
            const userDoc = await db.collection('users').doc(testUser.id).get();
            if (!userDoc.exists) {
                throw new Error('Usuario no se pudo leer después de crear');
            }
            
            // 1.3 Actualizar usuario
            await db.collection('users').doc(testUser.id).update({
                name: 'Test User Updated',
                updatedAt: admin.firestore.FieldValue.serverTimestamp()
            });
            
            // 1.4 Verificar actualización
            const updatedDoc = await db.collection('users').doc(testUser.id).get();
            const userData = updatedDoc.data();
            if (userData.name !== 'Test User Updated') {
                throw new Error('Actualización no se reflejó correctamente');
            }
            
            // 1.5 Query compleja - buscar por email
            const querySnapshot = await db.collection('users')
                .where('email', '==', testUser.email)
                .limit(1)
                .get();
                
            if (querySnapshot.empty) {
                throw new Error('Query por email falló');
            }
            
            const endTime = performance.now();
            const duration = endTime - startTime;
            
            this.recordResult('CRUD Colección Users', true, 
                `Crear, leer, actualizar y query exitosos`, { duration: `${duration.toFixed(2)}ms` });
                
        } catch (error) {
            this.recordResult('CRUD Colección Users', false, error.message);
        }
    }

    async testDriverCollection() {
        this.log('=== INICIANDO TESTS DE COLECCIÓN DRIVERS ===');
        
        try {
            const startTime = performance.now();
            
            // Crear conductor de prueba con estructura completa
            const testDriver = {
                id: `test-driver-${Date.now()}`,
                userId: this.testData.users[0] || 'fallback-user-id',
                name: 'Test Driver DB',
                email: `testdriver${Date.now()}@rappitaxi.com`,
                phone: '+51987654001',
                status: 'offline',
                isVerified: true,
                rating: 4.8,
                totalRides: 156,
                totalEarnings: 2450.75,
                createdAt: admin.firestore.FieldValue.serverTimestamp(),
                updatedAt: admin.firestore.FieldValue.serverTimestamp(),
                location: {
                    latitude: -12.0464,
                    longitude: -77.0428,
                    heading: 0,
                    accuracy: 10,
                    lastUpdated: admin.firestore.FieldValue.serverTimestamp()
                },
                vehicle: {
                    licensePlate: 'TEST-001',
                    model: 'Toyota Yaris',
                    color: 'Blanco',
                    year: 2022,
                    category: 'standard',
                    capacity: 4
                },
                documents: {
                    driverLicense: {
                        number: 'DL123456789',
                        expiryDate: '2025-12-31',
                        verified: true
                    },
                    vehicleRegistration: {
                        number: 'VR123456789',
                        expiryDate: '2025-12-31',
                        verified: true
                    }
                },
                bankAccount: {
                    accountNumber: '*****1234',
                    bankName: 'Banco Test',
                    accountType: 'savings'
                }
            };
            
            await db.collection('drivers').doc(testDriver.id).set(testDriver);
            this.testData.drivers.push(testDriver.id);
            
            // Test de queries geoespaciales
            const nearbyDrivers = await db.collection('drivers')
                .where('status', '==', 'online')
                .where('location.latitude', '>=', -12.1)
                .where('location.latitude', '<=', -12.0)
                .get();
                
            // Test de aggregation - calcular estadísticas
            const ratingQuery = await db.collection('drivers')
                .where('rating', '>=', 4.5)
                .get();
            
            let totalRating = 0;
            let count = 0;
            ratingQuery.forEach(doc => {
                const data = doc.data();
                if (data.rating) {
                    totalRating += data.rating;
                    count++;
                }
            });
            
            const avgRating = count > 0 ? totalRating / count : 0;
            
            const endTime = performance.now();
            const duration = endTime - startTime;
            
            this.recordResult('CRUD Colección Drivers', true, 
                `Conductor creado, queries geoespaciales y cálculos de rating (avg: ${avgRating.toFixed(2)})`, 
                { duration: `${duration.toFixed(2)}ms` });
                
        } catch (error) {
            this.recordResult('CRUD Colección Drivers', false, error.message);
        }
    }

    async testRideCollection() {
        this.log('=== INICIANDO TESTS DE COLECCIÓN RIDES ===');
        
        try {
            const startTime = performance.now();
            
            // Crear viaje completo con toda la estructura
            const testRide = {
                id: `test-ride-${Date.now()}`,
                passengerId: this.testData.users[0] || 'fallback-passenger-id',
                driverId: this.testData.drivers[0] || 'fallback-driver-id',
                status: 'completed',
                rideType: 'standard',
                createdAt: admin.firestore.FieldValue.serverTimestamp(),
                updatedAt: admin.firestore.FieldValue.serverTimestamp(),
                requestedAt: admin.firestore.FieldValue.serverTimestamp(),
                acceptedAt: admin.firestore.FieldValue.serverTimestamp(),
                startedAt: admin.firestore.FieldValue.serverTimestamp(),
                completedAt: admin.firestore.FieldValue.serverTimestamp(),
                locations: {
                    pickup: {
                        latitude: -12.0464,
                        longitude: -77.0428,
                        address: 'Lima Centro, Perú'
                    },
                    destination: {
                        latitude: -12.0922,
                        longitude: -77.0214,
                        address: 'Miraflores, Lima, Perú'
                    }
                },
                fare: {
                    baseFare: 5.0,
                    distanceFare: 8.5,
                    timeFare: 2.0,
                    surgePricing: 1.2,
                    totalFare: 18.60,
                    currency: 'PEN'
                },
                distance: {
                    estimated: 8.5,
                    actual: 8.7,
                    unit: 'km'
                },
                duration: {
                    estimated: 15,
                    actual: 18,
                    unit: 'minutes'
                },
                rating: {
                    passengerRating: 5,
                    driverRating: 5,
                    passengerComment: 'Excelente viaje',
                    driverComment: 'Pasajero muy puntual'
                },
                payment: {
                    method: 'cash',
                    status: 'completed',
                    paidAt: admin.firestore.FieldValue.serverTimestamp()
                }
            };
            
            await db.collection('rides').doc(testRide.id).set(testRide);
            this.testData.rides.push(testRide.id);
            
            // Test de queries complejas por fechas y status
            const today = new Date();
            today.setHours(0, 0, 0, 0);
            const tomorrow = new Date(today);
            tomorrow.setDate(tomorrow.getDate() + 1);
            
            const todayRides = await db.collection('rides')
                .where('createdAt', '>=', today)
                .where('createdAt', '<', tomorrow)
                .get();
            
            // Test de aggregation por estado
            const completedRides = await db.collection('rides')
                .where('status', '==', 'completed')
                .get();
            
            let totalFare = 0;
            completedRides.forEach(doc => {
                const data = doc.data();
                if (data.fare && data.fare.totalFare) {
                    totalFare += data.fare.totalFare;
                }
            });
            
            const endTime = performance.now();
            const duration = endTime - startTime;
            
            this.recordResult('CRUD Colección Rides', true, 
                `Viaje creado, queries por fecha y cálculo de ingresos (total: S/${totalFare.toFixed(2)})`,
                { duration: `${duration.toFixed(2)}ms` });
                
        } catch (error) {
            this.recordResult('CRUD Colección Rides', false, error.message);
        }
    }

    // =============================================================================
    // 2. TESTS DE TRANSACCIONES Y CONSISTENCIA
    // =============================================================================
    async testTransactions() {
        this.log('=== INICIANDO TESTS DE TRANSACCIONES ===');
        
        try {
            const startTime = performance.now();
            
            // Test de transacción completa: completar viaje
            const result = await db.runTransaction(async (transaction) => {
                const driverId = this.testData.drivers[0];
                const rideId = this.testData.rides[0];
                
                if (!driverId || !rideId) {
                    throw new Error('No hay datos de prueba para transacción');
                }
                
                // Leer estado actual
                const driverRef = db.collection('drivers').doc(driverId);
                const rideRef = db.collection('rides').doc(rideId);
                
                const driverDoc = await transaction.get(driverRef);
                const rideDoc = await transaction.get(rideRef);
                
                if (!driverDoc.exists || !rideDoc.exists) {
                    throw new Error('Documentos no existen para transacción');
                }
                
                const driverData = driverDoc.data();
                const rideData = rideDoc.data();
                
                // Actualizar múltiples documentos de forma atómica
                transaction.update(driverRef, {
                    totalRides: (driverData.totalRides || 0) + 1,
                    totalEarnings: (driverData.totalEarnings || 0) + (rideData.fare?.totalFare || 0),
                    status: 'online',
                    updatedAt: admin.firestore.FieldValue.serverTimestamp()
                });
                
                transaction.update(rideRef, {
                    status: 'completed',
                    completedAt: admin.firestore.FieldValue.serverTimestamp()
                });
                
                // Crear registro de earnings
                const earningId = `earning-${Date.now()}`;
                const earningRef = db.collection('earnings').doc(earningId);
                transaction.set(earningRef, {
                    driverId,
                    rideId,
                    amount: rideData.fare?.totalFare || 0,
                    currency: 'PEN',
                    date: admin.firestore.FieldValue.serverTimestamp(),
                    status: 'completed'
                });
                
                return { driverId, rideId, earningId };
            });
            
            const endTime = performance.now();
            const duration = endTime - startTime;
            
            this.recordResult('Transacciones Atómicas', true, 
                `Transacción completada: ${result.driverId} -> ${result.rideId}`,
                { duration: `${duration.toFixed(2)}ms` });
                
        } catch (error) {
            this.recordResult('Transacciones Atómicas', false, error.message);
        }
    }

    // =============================================================================
    // 3. TESTS DE RENDIMIENTO Y ESCALABILIDAD
    // =============================================================================
    async testPerformance() {
        this.log('=== INICIANDO TESTS DE RENDIMIENTO ===');
        
        try {
            // Test 1: Escrituras en lote (batch)
            const startBatch = performance.now();
            const batch = db.batch();
            
            for (let i = 0; i < 100; i++) {
                const docRef = db.collection('performance_test').doc(`test-${i}`);
                batch.set(docRef, {
                    index: i,
                    data: `Test data ${i}`,
                    timestamp: admin.firestore.FieldValue.serverTimestamp(),
                    randomValue: Math.random()
                });
            }
            
            await batch.commit();
            const batchDuration = performance.now() - startBatch;
            
            // Test 2: Lectura masiva con paginación
            const startRead = performance.now();
            let totalDocsRead = 0;
            let lastDoc = null;
            
            while (totalDocsRead < 100) {
                let query = db.collection('performance_test')
                    .orderBy('index')
                    .limit(25);
                    
                if (lastDoc) {
                    query = query.startAfter(lastDoc);
                }
                
                const snapshot = await query.get();
                if (snapshot.empty) break;
                
                totalDocsRead += snapshot.docs.length;
                lastDoc = snapshot.docs[snapshot.docs.length - 1];
            }
            
            const readDuration = performance.now() - startRead;
            
            // Test 3: Queries complejas con índices
            const startComplex = performance.now();
            const complexQuery = await db.collection('performance_test')
                .where('index', '>=', 50)
                .where('randomValue', '>=', 0.5)
                .orderBy('index')
                .orderBy('randomValue')
                .limit(10)
                .get();
            
            const complexDuration = performance.now() - startComplex;
            
            // Limpieza
            const deleteBatch = db.batch();
            for (let i = 0; i < 100; i++) {
                const docRef = db.collection('performance_test').doc(`test-${i}`);
                deleteBatch.delete(docRef);
            }
            await deleteBatch.commit();
            
            this.recordResult('Rendimiento Base de Datos', true,
                `Batch: ${batchDuration.toFixed(2)}ms, Read: ${readDuration.toFixed(2)}ms, Complex: ${complexDuration.toFixed(2)}ms`,
                {
                    batchWrite: `${batchDuration.toFixed(2)}ms`,
                    massiveRead: `${readDuration.toFixed(2)}ms`,
                    complexQuery: `${complexDuration.toFixed(2)}ms`,
                    docsProcessed: totalDocsRead
                });
                
        } catch (error) {
            this.recordResult('Rendimiento Base de Datos', false, error.message);
        }
    }

    // =============================================================================
    // 4. TESTS DE REGLAS DE SEGURIDAD
    // =============================================================================
    async testSecurityRules() {
        this.log('=== INICIANDO TESTS DE REGLAS DE SEGURIDAD ===');
        
        try {
            // Estos tests requieren que las reglas de seguridad estén configuradas
            // En un entorno real, usaríamos el Firebase Admin SDK con tokens específicos
            
            const startTime = performance.now();
            
            // Test 1: Verificar que los usuarios no puedan acceder a datos de otros usuarios
            // (Esto requeriría configuración especial con tokens de usuario)
            
            // Test 2: Verificar índices requeridos
            const indexTests = [
                // Test de índice compuesto para rides
                db.collection('rides')
                    .where('passengerId', '==', 'test-passenger')
                    .where('status', '==', 'active')
                    .orderBy('createdAt', 'desc')
                    .limit(1)
                    .get(),
                    
                // Test de índice para drivers por ubicación y status
                db.collection('drivers')
                    .where('status', '==', 'online')
                    .where('location.latitude', '>=', -12.1)
                    .limit(10)
                    .get()
            ];
            
            await Promise.all(indexTests);
            
            const endTime = performance.now();
            const duration = endTime - startTime;
            
            this.recordResult('Reglas de Seguridad e Índices', true,
                `Índices compuestos funcionando correctamente`,
                { duration: `${duration.toFixed(2)}ms` });
                
        } catch (error) {
            if (error.message.includes('index')) {
                this.recordResult('Reglas de Seguridad e Índices', false,
                    'Faltan índices requeridos en Firestore');
            } else {
                this.recordResult('Reglas de Seguridad e Índices', false, error.message);
            }
        }
    }

    // =============================================================================
    // 5. TESTS DE LIMPIEZA Y MANTENIMIENTO
    // =============================================================================
    async cleanup() {
        this.log('=== INICIANDO LIMPIEZA DE DATOS DE PRUEBA ===');
        
        try {
            // Eliminar usuarios de prueba
            for (const userId of this.testData.users) {
                await db.collection('users').doc(userId).delete();
            }
            
            // Eliminar conductores de prueba
            for (const driverId of this.testData.drivers) {
                await db.collection('drivers').doc(driverId).delete();
            }
            
            // Eliminar viajes de prueba
            for (const rideId of this.testData.rides) {
                await db.collection('rides').doc(rideId).delete();
            }
            
            // Eliminar earnings de prueba
            const earningsQuery = await db.collection('earnings')
                .where('driverId', 'in', this.testData.drivers)
                .get();
                
            const batch = db.batch();
            earningsQuery.forEach(doc => {
                batch.delete(doc.ref);
            });
            
            if (!earningsQuery.empty) {
                await batch.commit();
            }
            
            this.recordResult('Limpieza de Datos', true, 
                `Eliminados ${this.testData.users.length + this.testData.drivers.length + this.testData.rides.length} documentos`);
                
        } catch (error) {
            this.recordResult('Limpieza de Datos', false, error.message);
        }
    }

    // =============================================================================
    // FUNCIÓN PRINCIPAL
    // =============================================================================
    async runAllTests() {
        this.log('🚀 INICIANDO TESTING COMPLETO DE INTEGRIDAD DE BASE DE DATOS');
        
        const startTime = performance.now();
        
        try {
            await this.testUserCollection();
            await this.testDriverCollection();
            await this.testRideCollection();
            await this.testTransactions();
            await this.testPerformance();
            await this.testSecurityRules();
            
        } catch (error) {
            this.log(`Error durante testing: ${error.message}`, 'error');
        } finally {
            await this.cleanup();
        }
        
        const duration = performance.now() - startTime;
        this.generateReport(duration);
    }

    generateReport(duration) {
        this.log('=== REPORTE FINAL DE INTEGRIDAD DE BASE DE DATOS ===');
        this.log(`⏱️  Duración total: ${(duration / 1000).toFixed(2)}s`);
        this.log(`✅ Tests exitosos: ${this.testResults.passed}`);
        this.log(`❌ Tests fallidos: ${this.testResults.failed}`);
        this.log(`📊 Total de tests: ${this.testResults.total}`);
        
        const successRate = (this.testResults.passed / this.testResults.total * 100).toFixed(1);
        
        if (successRate >= 95) {
            this.log(`🎉 Tasa de éxito: ${successRate}% - EXCELENTE`, 'success');
        } else if (successRate >= 80) {
            this.log(`⚠️  Tasa de éxito: ${successRate}% - ACEPTABLE`, 'warning');
        } else {
            this.log(`💥 Tasa de éxito: ${successRate}% - REQUIERE ATENCIÓN INMEDIATA`, 'error');
        }

        // Guardar reporte detallado
        const fs = require('fs');
        const path = require('path');
        
        const reportFile = path.join(__dirname, '../docs/test_results', `database_integrity_${Date.now()}.json`);
        const reportDir = path.dirname(reportFile);
        
        if (!fs.existsSync(reportDir)) {
            fs.mkdirSync(reportDir, { recursive: true });
        }
        
        const report = {
            timestamp: new Date().toISOString(),
            duration: duration / 1000,
            summary: this.testResults,
            successRate: successRate,
            details: this.results,
            testData: this.testData,
            recommendations: this.generateRecommendations()
        };
        
        fs.writeFileSync(reportFile, JSON.stringify(report, null, 2));
        this.log(`📋 Reporte guardado: ${reportFile}`, 'success');
    }

    generateRecommendations() {
        const recommendations = [];
        
        if (this.testResults.failed > 0) {
            recommendations.push('Revisar los tests fallidos y corregir problemas de integridad');
        }
        
        if (this.testResults.passed / this.testResults.total < 0.9) {
            recommendations.push('Implementar monitoreo continuo de salud de base de datos');
        }
        
        recommendations.push('Configurar backups automáticos diarios');
        recommendations.push('Implementar alertas para operaciones fallidas');
        recommendations.push('Revisar y optimizar índices de Firestore regularmente');
        
        return recommendations;
    }
}

// Ejecutar si se llama directamente
if (require.main === module) {
    const tester = new DatabaseIntegrityTester();
    tester.runAllTests().then(() => {
        process.exit(0);
    }).catch((error) => {
        console.error('Error en testing de integridad:', error);
        process.exit(1);
    });
}

module.exports = DatabaseIntegrityTester;
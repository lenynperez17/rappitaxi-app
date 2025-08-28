#!/usr/bin/env node

/**
 * RAPPITAXI - TESTING COMPLETO DE WEBSOCKETS
 * Script para probar todas las conexiones en tiempo real
 */

const io = require('socket.io-client');
const chalk = require('chalk');

const BASE_URL = process.env.TEST_BASE_URL || 'http://localhost:3000';

// Tokens de test desde variables de entorno
const TEST_TOKENS = {
    admin: process.env.TEST_ADMIN_TOKEN || 'test-admin-token',
    driver: process.env.TEST_DRIVER_TOKEN || 'test-driver-token',
    passenger: process.env.TEST_PASSENGER_TOKEN || 'test-passenger-token'
};

class WebSocketTester {
    constructor() {
        this.results = [];
        this.connections = new Map();
        this.testResults = {
            passed: 0,
            failed: 0,
            total: 0
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

    async delay(ms) {
        return new Promise(resolve => setTimeout(resolve, ms));
    }

    recordResult(testName, success, details = '') {
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
            timestamp: new Date().toISOString()
        });
    }

    // =============================================================================
    // 1. TEST DE CONEXIÓN BÁSICA
    // =============================================================================
    async testBasicConnection() {
        this.log('=== INICIANDO TESTS DE CONEXIÓN WEBSOCKET ===');
        
        return new Promise((resolve) => {
            const socket = io(BASE_URL, {
                transports: ['websocket'],
                timeout: 5000
            });

            const timeout = setTimeout(() => {
                this.recordResult('Conexión WebSocket Básica', false, 'Timeout de conexión');
                socket.disconnect();
                resolve();
            }, 5000);

            socket.on('connect', () => {
                clearTimeout(timeout);
                this.recordResult('Conexión WebSocket Básica', true, `Socket ID: ${socket.id}`);
                this.connections.set('basic', socket);
                
                socket.on('disconnect', () => {
                    this.log('Conexión básica desconectada');
                });
                
                resolve();
            });

            socket.on('connect_error', (error) => {
                clearTimeout(timeout);
                this.recordResult('Conexión WebSocket Básica', false, `Error: ${error.message}`);
                resolve();
            });
        });
    }

    // =============================================================================
    // 2. TEST DE AUTENTICACIÓN EN WEBSOCKET
    // =============================================================================
    async testAuthentication() {
        this.log('=== INICIANDO TESTS DE AUTENTICACIÓN WEBSOCKET ===');
        
        return new Promise((resolve) => {
            const socket = io(BASE_URL, {
                transports: ['websocket'],
                auth: {
                    token: TEST_TOKENS.admin
                }
            });

            socket.on('connect', () => {
                this.log('Conectado para test de autenticación');
                
                // Test de autenticación exitosa
                socket.emit('authenticate', {
                    token: 'valid-test-token',
                    userType: 'passenger'
                });

                socket.on('authenticated', (data) => {
                    this.recordResult('Autenticación WebSocket', true, `Usuario autenticado: ${data.userId}`);
                    this.connections.set('authenticated', socket);
                    resolve();
                });

                socket.on('authentication_error', (error) => {
                    this.recordResult('Autenticación WebSocket', false, `Error de autenticación: ${error}`);
                    resolve();
                });
            });

            socket.on('connect_error', (error) => {
                this.recordResult('Autenticación WebSocket', false, `Error de conexión: ${error.message}`);
                resolve();
            });
        });
    }

    // =============================================================================
    // 3. TEST DE TRACKING GPS EN TIEMPO REAL
    // =============================================================================
    async testGPSTracking() {
        this.log('=== INICIANDO TESTS DE GPS TRACKING ===');
        
        const driverSocket = io(`${BASE_URL}/driver`, {
            transports: ['websocket'],
            auth: { token: TEST_TOKENS.driver }
        });

        const passengerSocket = io(`${BASE_URL}/passenger`, {
            transports: ['websocket'],
            auth: { token: TEST_TOKENS.passenger }
        });

        return new Promise((resolve) => {
            let driverConnected = false;
            let passengerConnected = false;
            let locationReceived = false;

            const checkCompletion = () => {
                if (driverConnected && passengerConnected && locationReceived) {
                    this.recordResult('GPS Tracking Tiempo Real', true, 'Tracking bidireccional funcionando');
                    driverSocket.disconnect();
                    passengerSocket.disconnect();
                    resolve();
                }
            };

            // Conductor conecta y empieza tracking
            driverSocket.on('connect', () => {
                driverConnected = true;
                this.log('Conductor conectado para GPS tracking');
                
                // Simular actualización de ubicación cada 2 segundos
                const locationInterval = setInterval(() => {
                    const randomLat = -12.0464 + (Math.random() - 0.5) * 0.01;
                    const randomLng = -77.0428 + (Math.random() - 0.5) * 0.01;
                    
                    driverSocket.emit('location_update', {
                        latitude: randomLat,
                        longitude: randomLng,
                        heading: Math.random() * 360,
                        speed: Math.random() * 50,
                        timestamp: new Date().toISOString()
                    });
                }, 2000);

                setTimeout(() => {
                    clearInterval(locationInterval);
                }, 10000);
            });

            // Pasajero conecta y escucha actualizaciones
            passengerSocket.on('connect', () => {
                passengerConnected = true;
                this.log('Pasajero conectado para recibir tracking');
                
                // Suscribirse a actualizaciones de conductor específico
                passengerSocket.emit('track_driver', {
                    driverId: 'test-driver-id',
                    rideId: 'test-ride-id'
                });
            });

            // Pasajero recibe actualizaciones de ubicación
            passengerSocket.on('driver_location_update', (data) => {
                if (!locationReceived) {
                    locationReceived = true;
                    this.log(`Ubicación del conductor recibida: ${data.latitude}, ${data.longitude}`);
                    checkCompletion();
                }
            });

            setTimeout(() => {
                if (!locationReceived) {
                    this.recordResult('GPS Tracking Tiempo Real', false, 'No se recibieron actualizaciones de ubicación');
                    driverSocket.disconnect();
                    passengerSocket.disconnect();
                    resolve();
                }
            }, 15000);
        });
    }

    // =============================================================================
    // 4. TEST DE CHAT EN TIEMPO REAL
    // =============================================================================
    async testRealTimeChat() {
        this.log('=== INICIANDO TESTS DE CHAT TIEMPO REAL ===');
        
        const passengerSocket = io(`${BASE_URL}`, {
            transports: ['websocket'],
            auth: { token: TEST_TOKENS.passenger }
        });

        const driverSocket = io(`${BASE_URL}`, {
            transports: ['websocket'], 
            auth: { token: TEST_TOKENS.driver }
        });

        return new Promise((resolve) => {
            let messagesSent = 0;
            let messagesReceived = 0;
            const testMessages = [
                { from: 'passenger', text: 'Hola, ¿dónde estás?' },
                { from: 'driver', text: 'Estoy llegando, 2 minutos' },
                { from: 'passenger', text: 'Perfecto, te espero' }
            ];

            const rideId = 'test-ride-id';

            // Unir a la sala de chat del viaje
            passengerSocket.emit('join_ride_chat', { rideId });
            driverSocket.emit('join_ride_chat', { rideId });

            // Configurar listeners para mensajes
            passengerSocket.on('new_message', (data) => {
                if (data.senderId !== 'passenger-test-id') {
                    messagesReceived++;
                    this.log(`Pasajero recibió: ${data.message}`);
                    checkChatCompletion();
                }
            });

            driverSocket.on('new_message', (data) => {
                if (data.senderId !== 'driver-test-id') {
                    messagesReceived++;
                    this.log(`Conductor recibió: ${data.message}`);
                    checkChatCompletion();
                }
            });

            const checkChatCompletion = () => {
                if (messagesSent === testMessages.length && messagesReceived >= 2) {
                    this.recordResult('Chat Tiempo Real', true, `${messagesReceived} mensajes intercambiados`);
                    passengerSocket.disconnect();
                    driverSocket.disconnect();
                    resolve();
                }
            };

            // Enviar mensajes de prueba con delay
            const sendNextMessage = () => {
                if (messagesSent < testMessages.length) {
                    const message = testMessages[messagesSent];
                    const socket = message.from === 'passenger' ? passengerSocket : driverSocket;
                    const senderId = message.from === 'passenger' ? 'passenger-test-id' : 'driver-test-id';
                    
                    socket.emit('send_message', {
                        rideId,
                        message: message.text,
                        senderId,
                        messageType: 'text'
                    });

                    messagesSent++;
                    this.log(`Enviado (${message.from}): ${message.text}`);

                    setTimeout(sendNextMessage, 1000);
                }
            };

            // Esperar conexiones y comenzar chat
            setTimeout(() => {
                sendNextMessage();
            }, 2000);

            // Timeout de seguridad
            setTimeout(() => {
                if (messagesReceived < 2) {
                    this.recordResult('Chat Tiempo Real', false, 'No se completó el intercambio de mensajes');
                    passengerSocket.disconnect();
                    driverSocket.disconnect();
                    resolve();
                }
            }, 15000);
        });
    }

    // =============================================================================
    // 5. TEST DE NOTIFICACIONES EN TIEMPO REAL
    // =============================================================================
    async testRealTimeNotifications() {
        this.log('=== INICIANDO TESTS DE NOTIFICACIONES TIEMPO REAL ===');
        
        const userSocket = io(`${BASE_URL}`, {
            transports: ['websocket'],
            auth: { token: 'user-test-token' }
        });

        return new Promise((resolve) => {
            let notificationsReceived = 0;
            const expectedNotifications = [
                'ride_requested',
                'driver_assigned', 
                'driver_arrived',
                'ride_started',
                'ride_completed'
            ];

            userSocket.on('connect', () => {
                this.log('Usuario conectado para notificaciones');
                
                // Suscribirse a notificaciones del usuario
                userSocket.emit('subscribe_notifications', {
                    userId: 'test-user-id'
                });
            });

            userSocket.on('notification', (notification) => {
                notificationsReceived++;
                this.log(`Notificación recibida: ${notification.type} - ${notification.title}`);
                
                if (notificationsReceived >= expectedNotifications.length) {
                    this.recordResult('Notificaciones Tiempo Real', true, `${notificationsReceived} notificaciones recibidas`);
                    userSocket.disconnect();
                    resolve();
                }
            });

            // Simular envío de notificaciones desde el servidor
            setTimeout(() => {
                expectedNotifications.forEach((type, index) => {
                    setTimeout(() => {
                        // Aquí normalmente el servidor emitiría la notificación
                        // Para testing, emitimos desde el cliente
                        userSocket.emit('test_notification', {
                            type,
                            title: `Test ${type}`,
                            body: `Notificación de prueba ${index + 1}`,
                            userId: 'test-user-id'
                        });
                    }, index * 1000);
                });
            }, 2000);

            // Timeout
            setTimeout(() => {
                if (notificationsReceived < expectedNotifications.length) {
                    this.recordResult('Notificaciones Tiempo Real', false, `Solo recibidas ${notificationsReceived}/${expectedNotifications.length}`);
                    userSocket.disconnect();
                    resolve();
                }
            }, 15000);
        });
    }

    // =============================================================================
    // 6. TEST DE NEGOCIACIÓN DE PRECIOS EN TIEMPO REAL
    // =============================================================================
    async testPriceNegotiation() {
        this.log('=== INICIANDO TESTS DE NEGOCIACIÓN DE PRECIOS ===');
        
        const passengerSocket = io(`${BASE_URL}`, {
            transports: ['websocket'],
            auth: { token: TEST_TOKENS.passenger }
        });

        const driversockets = [];
        for (let i = 0; i < 3; i++) {
            driversockets.push(io(`${BASE_URL}`, {
                transports: ['websocket'],
                auth: { token: `${TEST_TOKENS.driver}-${i}` }
            }));
        }

        return new Promise((resolve) => {
            let offersReceived = 0;
            const negotiationId = 'test-negotiation-' + Date.now();

            // Pasajero inicia negociación
            passengerSocket.on('connect', () => {
                this.log('Iniciando negociación de precios');
                
                passengerSocket.emit('start_price_negotiation', {
                    negotiationId,
                    pickupLocation: { lat: -12.0464, lng: -77.0428 },
                    destinationLocation: { lat: -12.0922, lng: -77.0214 },
                    proposedFare: 20.0,
                    maxWaitTime: 300
                });
            });

            // Conductores reciben la solicitud y envían ofertas
            driversockets.forEach((socket, index) => {
                socket.on('connect', () => {
                    this.log(`Conductor ${index + 1} conectado`);
                });

                socket.on('price_negotiation_available', (data) => {
                    if (data.negotiationId === negotiationId) {
                        // Enviar oferta con delay aleatorio
                        setTimeout(() => {
                            const offerPrice = 20 + (Math.random() - 0.5) * 10; // 15-25 rango
                            socket.emit('submit_price_offer', {
                                negotiationId,
                                offeredFare: offerPrice,
                                driverId: `driver-${index + 1}`,
                                estimatedArrival: Math.floor(Math.random() * 10) + 2,
                                message: `Oferta del conductor ${index + 1}`
                            });
                            this.log(`Conductor ${index + 1} envió oferta: S/${offerPrice.toFixed(2)}`);
                        }, Math.random() * 3000);
                    }
                });
            });

            // Pasajero recibe ofertas
            passengerSocket.on('price_offer_received', (offer) => {
                offersReceived++;
                this.log(`Oferta recibida de ${offer.driverId}: S/${offer.offeredFare}`);
                
                // Aceptar la primera oferta después de recibir al menos 2
                if (offersReceived >= 2) {
                    passengerSocket.emit('accept_price_offer', {
                        negotiationId,
                        offerId: offer.id,
                        driverId: offer.driverId
                    });
                }
            });

            passengerSocket.on('price_negotiation_completed', (data) => {
                this.recordResult('Negociación de Precios', true, `Completada con ${offersReceived} ofertas, precio final: S/${data.finalFare}`);
                
                // Desconectar todos los sockets
                passengerSocket.disconnect();
                driversockets.forEach(socket => socket.disconnect());
                resolve();
            });

            // Timeout
            setTimeout(() => {
                if (offersReceived === 0) {
                    this.recordResult('Negociación de Precios', false, 'No se recibieron ofertas');
                    passengerSocket.disconnect();
                    driversockets.forEach(socket => socket.disconnect());
                    resolve();
                }
            }, 20000);
        });
    }

    // =============================================================================
    // 7. TEST DE CARGA CON MÚLTIPLES CONEXIONES
    // =============================================================================
    async testLoadWithMultipleConnections() {
        this.log('=== INICIANDO TEST DE CARGA WEBSOCKETS ===');
        
        const connectionCount = 50;
        const connections = [];
        let connectedCount = 0;
        let messagesExchanged = 0;

        return new Promise((resolve) => {
            // Crear múltiples conexiones
            for (let i = 0; i < connectionCount; i++) {
                const socket = io(BASE_URL, {
                    transports: ['websocket'],
                    auth: { token: `load-test-token-${i}` }
                });

                socket.on('connect', () => {
                    connectedCount++;
                    
                    if (connectedCount === connectionCount) {
                        this.log(`${connectedCount} conexiones establecidas`);
                        
                        // Intercambiar mensajes entre conexiones
                        connections.forEach((conn, index) => {
                            conn.emit('broadcast_message', {
                                message: `Test message from connection ${index}`,
                                timestamp: Date.now()
                            });
                        });
                    }
                });

                socket.on('broadcast_received', (data) => {
                    messagesExchanged++;
                });

                socket.on('disconnect', () => {
                    this.log(`Conexión ${i} desconectada`);
                });

                connections.push(socket);
            }

            // Verificar resultados después de 10 segundos
            setTimeout(() => {
                const successRate = connectedCount / connectionCount;
                const messageRate = messagesExchanged / (connectionCount * connectionCount);
                
                if (successRate >= 0.9) {
                    this.recordResult('Test de Carga WebSocket', true, 
                        `${connectedCount}/${connectionCount} conexiones, ${messagesExchanged} mensajes`);
                } else {
                    this.recordResult('Test de Carga WebSocket', false, 
                        `Solo ${connectedCount}/${connectionCount} conexiones exitosas`);
                }

                // Desconectar todas las conexiones
                connections.forEach(socket => socket.disconnect());
                resolve();
            }, 10000);
        });
    }

    // =============================================================================
    // FUNCIÓN PRINCIPAL DE TESTING
    // =============================================================================
    async runAllTests() {
        this.log('🚀 INICIANDO TESTING COMPLETO DE WEBSOCKETS');
        
        const startTime = Date.now();
        
        try {
            await this.testBasicConnection();
            await this.delay(1000);
            
            await this.testAuthentication();
            await this.delay(1000);
            
            await this.testGPSTracking();
            await this.delay(2000);
            
            await this.testRealTimeChat();
            await this.delay(2000);
            
            await this.testRealTimeNotifications();
            await this.delay(2000);
            
            await this.testPriceNegotiation();
            await this.delay(2000);
            
            await this.testLoadWithMultipleConnections();
            
        } catch (error) {
            this.log(`Error durante testing: ${error.message}`, 'error');
        }
        
        const duration = Date.now() - startTime;
        
        // Cerrar todas las conexiones restantes
        this.connections.forEach((socket, name) => {
            if (socket.connected) {
                socket.disconnect();
                this.log(`Desconectada: ${name}`);
            }
        });
        
        this.generateReport(duration);
    }

    generateReport(duration) {
        this.log('=== REPORTE FINAL DE WEBSOCKETS ===');
        this.log(`⏱️  Duración total: ${(duration / 1000).toFixed(2)}s`);
        this.log(`✅ Tests exitosos: ${this.testResults.passed}`);
        this.log(`❌ Tests fallidos: ${this.testResults.failed}`);
        this.log(`📊 Total de tests: ${this.testResults.total}`);
        
        const successRate = (this.testResults.passed / this.testResults.total * 100).toFixed(1);
        
        if (successRate >= 90) {
            this.log(`🎉 Tasa de éxito: ${successRate}% - EXCELENTE`, 'success');
        } else if (successRate >= 70) {
            this.log(`⚠️  Tasa de éxito: ${successRate}% - ACEPTABLE`, 'warning');
        } else {
            this.log(`💥 Tasa de éxito: ${successRate}% - REQUIERE ATENCIÓN`, 'error');
        }

        // Guardar reporte detallado
        const reportFile = `../docs/test_results/websocket_test_${Date.now()}.json`;
        const fs = require('fs');
        const path = require('path');
        
        const reportDir = path.dirname(reportFile);
        if (!fs.existsSync(reportDir)) {
            fs.mkdirSync(reportDir, { recursive: true });
        }
        
        const report = {
            timestamp: new Date().toISOString(),
            duration: duration,
            summary: this.testResults,
            successRate: successRate,
            details: this.results
        };
        
        fs.writeFileSync(reportFile, JSON.stringify(report, null, 2));
        this.log(`📋 Reporte guardado: ${reportFile}`, 'success');
    }
}

// Ejecutar si se llama directamente
if (require.main === module) {
    const tester = new WebSocketTester();
    tester.runAllTests().then(() => {
        process.exit(0);
    }).catch((error) => {
        console.error('Error en testing de WebSockets:', error);
        process.exit(1);
    });
}

module.exports = WebSocketTester;
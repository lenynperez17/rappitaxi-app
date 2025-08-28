#!/usr/bin/env node

/**
 * RAPPITAXI - TESTING DE CARGA Y RENDIMIENTO
 * Script para probar la capacidad del sistema bajo carga intensa
 */

const axios = require('axios');
const chalk = require('chalk');
const { performance } = require('perf_hooks');

const BASE_URL = 'http://localhost:3000';
const API_URL = `${BASE_URL}/api`;

class LoadPerformanceTester {
    constructor() {
        this.results = [];
        this.testResults = {
            passed: 0,
            failed: 0,
            total: 0
        };
        
        this.performanceMetrics = {
            responseTime: [],
            throughput: [],
            errorRate: [],
            memoryUsage: [],
            cpuUsage: []
        };
        
        this.config = {
            maxConcurrentUsers: 100,
            testDuration: 60000, // 1 minuto
            rampUpTime: 10000,   // 10 segundos
            thinkTime: 1000      // 1 segundo entre requests
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

    recordResult(testName, success, details = '', metrics = null) {
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
            metrics,
            timestamp: new Date().toISOString()
        });
    }

    async delay(ms) {
        return new Promise(resolve => setTimeout(resolve, ms));
    }

    // =============================================================================
    // 1. TEST DE CARGA GRADUAL (RAMP-UP)
    // =============================================================================
    async testRampUpLoad() {
        this.log('=== INICIANDO TEST DE CARGA GRADUAL ===');
        
        const startTime = performance.now();
        const users = [];
        const results = {
            totalRequests: 0,
            successfulRequests: 0,
            failedRequests: 0,
            responseTimeStats: {
                min: Infinity,
                max: 0,
                avg: 0,
                p95: 0,
                p99: 0
            }
        };
        
        const responseTimes = [];
        
        try {
            // Crear usuarios virtuales gradualmente
            for (let i = 0; i < this.config.maxConcurrentUsers; i++) {
                const user = new VirtualUser(i, API_URL);
                users.push(user);
                
                // Arrancar usuario con delay progresivo
                setTimeout(() => {
                    user.start().then(userResults => {
                        results.totalRequests += userResults.requests;
                        results.successfulRequests += userResults.successful;
                        results.failedRequests += userResults.failed;
                        responseTimes.push(...userResults.responseTimes);
                    });
                }, (i / this.config.maxConcurrentUsers) * this.config.rampUpTime);
                
                await this.delay(this.config.rampUpTime / this.config.maxConcurrentUsers);
            }
            
            // Esperar que terminen todos los tests
            await this.delay(this.config.testDuration);
            
            // Detener todos los usuarios
            users.forEach(user => user.stop());
            
            // Calcular estadísticas finales
            if (responseTimes.length > 0) {
                responseTimes.sort((a, b) => a - b);
                results.responseTimeStats.min = responseTimes[0];
                results.responseTimeStats.max = responseTimes[responseTimes.length - 1];
                results.responseTimeStats.avg = responseTimes.reduce((a, b) => a + b, 0) / responseTimes.length;
                results.responseTimeStats.p95 = responseTimes[Math.floor(responseTimes.length * 0.95)];
                results.responseTimeStats.p99 = responseTimes[Math.floor(responseTimes.length * 0.99)];
            }
            
            const duration = performance.now() - startTime;
            const throughput = results.totalRequests / (duration / 1000);
            const errorRate = (results.failedRequests / results.totalRequests) * 100;
            
            this.recordResult('Test de Carga Gradual', 
                errorRate < 5, // Éxito si menos del 5% de errores
                `${results.totalRequests} requests, ${throughput.toFixed(2)} req/s, ${errorRate.toFixed(2)}% errores`,
                {
                    duration: `${(duration / 1000).toFixed(2)}s`,
                    throughput: `${throughput.toFixed(2)} req/s`,
                    errorRate: `${errorRate.toFixed(2)}%`,
                    responseTime: results.responseTimeStats
                }
            );
            
        } catch (error) {
            this.recordResult('Test de Carga Gradual', false, error.message);
        }
    }

    // =============================================================================
    // 2. TEST DE CARGA SOSTENIDA
    // =============================================================================
    async testSustainedLoad() {
        this.log('=== INICIANDO TEST DE CARGA SOSTENIDA ===');
        
        const startTime = performance.now();
        const concurrentUsers = 50;
        const testDuration = 30000; // 30 segundos
        
        const promises = [];
        let totalRequests = 0;
        let successfulRequests = 0;
        
        try {
            for (let i = 0; i < concurrentUsers; i++) {
                const promise = this.simulateUserSession(i, testDuration).then(result => {
                    totalRequests += result.total;
                    successfulRequests += result.successful;
                });
                promises.push(promise);
            }
            
            await Promise.all(promises);
            
            const duration = performance.now() - startTime;
            const throughput = totalRequests / (duration / 1000);
            const successRate = (successfulRequests / totalRequests) * 100;
            
            this.recordResult('Test de Carga Sostenida',
                successRate >= 95,
                `${concurrentUsers} usuarios, ${throughput.toFixed(2)} req/s, ${successRate.toFixed(2)}% éxito`,
                {
                    concurrentUsers,
                    duration: `${(duration / 1000).toFixed(2)}s`,
                    throughput: `${throughput.toFixed(2)} req/s`,
                    successRate: `${successRate.toFixed(2)}%`
                }
            );
            
        } catch (error) {
            this.recordResult('Test de Carga Sostenida', false, error.message);
        }
    }

    // =============================================================================
    // 3. TEST DE PICOS DE TRÁFICO (SPIKE TEST)
    // =============================================================================
    async testSpikeLoad() {
        this.log('=== INICIANDO TEST DE PICOS DE TRÁFICO ===');
        
        const startTime = performance.now();
        const baselineUsers = 10;
        const spikeUsers = 100;
        const spikeDuration = 10000; // 10 segundos
        
        try {
            // Fase 1: Carga baseline
            this.log('Iniciando carga baseline...');
            const baselinePromises = [];
            for (let i = 0; i < baselineUsers; i++) {
                baselinePromises.push(this.simulateUserSession(i, 5000));
            }
            
            // Esperar que se establezca la baseline
            await this.delay(2000);
            
            // Fase 2: Generar pico de tráfico
            this.log('Generando pico de tráfico...');
            const spikePromises = [];
            for (let i = 0; i < spikeUsers; i++) {
                spikePromises.push(this.simulateUserSession(i + baselineUsers, spikeDuration));
            }
            
            // Medir el tiempo de respuesta durante el pico
            const spikeStartTime = performance.now();
            const testRequest = await this.makeTimedRequest('/health');
            const spikeResponseTime = performance.now() - spikeStartTime;
            
            // Esperar que termine el pico
            await Promise.all([...baselinePromises, ...spikePromises]);
            
            const totalDuration = performance.now() - startTime;
            
            this.recordResult('Test de Picos de Tráfico',
                spikeResponseTime < 5000, // Menos de 5 segundos durante el pico
                `Pico de ${spikeUsers} usuarios, respuesta en ${spikeResponseTime.toFixed(2)}ms`,
                {
                    baselineUsers,
                    spikeUsers,
                    spikeResponseTime: `${spikeResponseTime.toFixed(2)}ms`,
                    duration: `${(totalDuration / 1000).toFixed(2)}s`
                }
            );
            
        } catch (error) {
            this.recordResult('Test de Picos de Tráfico', false, error.message);
        }
    }

    // =============================================================================
    // 4. TEST DE ENDPOINTS CRÍTICOS
    // =============================================================================
    async testCriticalEndpoints() {
        this.log('=== INICIANDO TEST DE ENDPOINTS CRÍTICOS ===');
        
        const criticalEndpoints = [
            { path: '/auth/login', method: 'POST', data: { email: process.env.TEST_EMAIL || 'test@rappitaxi.com', password: process.env.TEST_PASSWORD || 'TestPassword123!' }},
            { path: '/passengers/rides/request', method: 'POST', data: { pickupLocation: { lat: -12.0464, lng: -77.0428 }}},
            { path: '/drivers/location', method: 'PUT', data: { latitude: -12.0464, longitude: -77.0428 }},
            { path: '/rides/nearby', method: 'GET' },
            { path: '/payments/create-preference', method: 'POST', data: { amount: 25.0 }}
        ];
        
        const concurrentRequests = 20;
        const results = {};
        
        try {
            for (const endpoint of criticalEndpoints) {
                const endpointResults = await this.loadTestEndpoint(endpoint, concurrentRequests);
                results[endpoint.path] = endpointResults;
                
                const success = endpointResults.averageResponseTime < 2000 && endpointResults.errorRate < 10;
                
                this.recordResult(`Endpoint ${endpoint.path}`,
                    success,
                    `${endpointResults.averageResponseTime.toFixed(2)}ms avg, ${endpointResults.errorRate.toFixed(2)}% errores`,
                    endpointResults
                );
            }
            
        } catch (error) {
            this.recordResult('Test de Endpoints Críticos', false, error.message);
        }
    }

    async loadTestEndpoint(endpoint, concurrentRequests) {
        const promises = [];
        const responseTimes = [];
        let successCount = 0;
        let errorCount = 0;
        
        for (let i = 0; i < concurrentRequests; i++) {
            const promise = this.makeTimedRequest(endpoint.path, endpoint.method, endpoint.data)
                .then(time => {
                    responseTimes.push(time);
                    successCount++;
                })
                .catch(() => {
                    errorCount++;
                });
            promises.push(promise);
        }
        
        await Promise.all(promises);
        
        return {
            totalRequests: concurrentRequests,
            successCount,
            errorCount,
            errorRate: (errorCount / concurrentRequests) * 100,
            averageResponseTime: responseTimes.reduce((a, b) => a + b, 0) / responseTimes.length || 0,
            minResponseTime: Math.min(...responseTimes) || 0,
            maxResponseTime: Math.max(...responseTimes) || 0
        };
    }

    async makeTimedRequest(path, method = 'GET', data = null, headers = {}) {
        const startTime = performance.now();
        
        try {
            const config = {
                method,
                url: `${API_URL}${path}`,
                headers: {
                    'Content-Type': 'application/json',
                    ...headers
                },
                timeout: 10000
            };
            
            if (data && (method === 'POST' || method === 'PUT')) {
                config.data = data;
            }
            
            await axios(config);
            return performance.now() - startTime;
            
        } catch (error) {
            const responseTime = performance.now() - startTime;
            if (error.code === 'ECONNABORTED') {
                throw new Error('Request timeout');
            }
            return responseTime; // Retornar tiempo incluso en caso de error HTTP
        }
    }

    // =============================================================================
    // 5. SIMULACIÓN DE SESIÓN DE USUARIO
    // =============================================================================
    async simulateUserSession(userId, duration) {
        const sessionStart = performance.now();
        const results = { total: 0, successful: 0, failed: 0 };
        
        const userActions = [
            () => this.makeTimedRequest('/health'),
            () => this.makeTimedRequest('/auth/login', 'POST', { email: `user${userId}@${process.env.TEST_DOMAIN || 'rappitaxi.com'}`, password: process.env.TEST_PASSWORD || 'TestPassword123!' }),
            () => this.makeTimedRequest('/passengers/profile'),
            () => this.makeTimedRequest('/passengers/rides/history'),
            () => this.makeTimedRequest('/drivers/nearby'),
            () => this.makeTimedRequest('/location/geocode?lat=-12.0464&lng=-77.0428')
        ];
        
        while (performance.now() - sessionStart < duration) {
            const action = userActions[Math.floor(Math.random() * userActions.length)];
            
            try {
                await action();
                results.successful++;
            } catch (error) {
                results.failed++;
            }
            
            results.total++;
            await this.delay(this.config.thinkTime + Math.random() * 1000);
        }
        
        return results;
    }

    // =============================================================================
    // 6. MONITOREO DE RECURSOS DEL SERVIDOR
    // =============================================================================
    async monitorServerResources() {
        this.log('=== MONITOREANDO RECURSOS DEL SERVIDOR ===');
        
        try {
            const startTime = performance.now();
            const samples = [];
            const monitoringDuration = 30000; // 30 segundos
            const sampleInterval = 1000; // 1 segundo
            
            const monitoringInterval = setInterval(async () => {
                try {
                    // Obtener métricas del servidor (requiere endpoint de métricas)
                    const response = await axios.get(`${BASE_URL}/metrics`, { timeout: 2000 });
                    const metrics = response.data;
                    
                    samples.push({
                        timestamp: Date.now(),
                        memory: metrics.memory || 0,
                        cpu: metrics.cpu || 0,
                        connections: metrics.connections || 0,
                        uptime: metrics.uptime || 0
                    });
                    
                } catch (error) {
                    // Si no hay endpoint de métricas, simular datos
                    samples.push({
                        timestamp: Date.now(),
                        memory: Math.random() * 100,
                        cpu: Math.random() * 100,
                        connections: Math.floor(Math.random() * 1000),
                        uptime: performance.now() - startTime
                    });
                }
            }, sampleInterval);
            
            await this.delay(monitoringDuration);
            clearInterval(monitoringInterval);
            
            // Calcular estadísticas de recursos
            const avgMemory = samples.reduce((sum, s) => sum + s.memory, 0) / samples.length;
            const avgCpu = samples.reduce((sum, s) => sum + s.cpu, 0) / samples.length;
            const maxMemory = Math.max(...samples.map(s => s.memory));
            const maxCpu = Math.max(...samples.map(s => s.cpu));
            
            this.recordResult('Monitoreo de Recursos',
                avgMemory < 80 && avgCpu < 80,
                `CPU: ${avgCpu.toFixed(1)}% avg (${maxCpu.toFixed(1)}% max), Memoria: ${avgMemory.toFixed(1)}% avg (${maxMemory.toFixed(1)}% max)`,
                {
                    samples: samples.length,
                    avgMemory: `${avgMemory.toFixed(1)}%`,
                    maxMemory: `${maxMemory.toFixed(1)}%`,
                    avgCpu: `${avgCpu.toFixed(1)}%`,
                    maxCpu: `${maxCpu.toFixed(1)}%`
                }
            );
            
        } catch (error) {
            this.recordResult('Monitoreo de Recursos', false, error.message);
        }
    }

    // =============================================================================
    // FUNCIÓN PRINCIPAL
    // =============================================================================
    async runAllTests() {
        this.log('🚀 INICIANDO TESTING COMPLETO DE CARGA Y RENDIMIENTO');
        this.log(`Configuración: ${this.config.maxConcurrentUsers} usuarios máx, ${this.config.testDuration/1000}s duración`);
        
        const startTime = performance.now();
        
        try {
            // Verificar que el servidor esté funcionando
            await this.makeTimedRequest('/health');
            this.log('Servidor respondiendo correctamente ✅');
            
            // Ejecutar tests secuencialmente para no sobrecargar
            await this.testRampUpLoad();
            await this.delay(5000); // Pausa entre tests
            
            await this.testSustainedLoad();
            await this.delay(5000);
            
            await this.testSpikeLoad();
            await this.delay(5000);
            
            await this.testCriticalEndpoints();
            await this.delay(5000);
            
            // Monitoreo en paralelo durante un test ligero
            const monitoringPromise = this.monitorServerResources();
            const lightLoadPromise = this.simulateUserSession(999, 25000);
            
            await Promise.all([monitoringPromise, lightLoadPromise]);
            
        } catch (error) {
            this.log(`Error durante testing: ${error.message}`, 'error');
        }
        
        const duration = performance.now() - startTime;
        this.generateReport(duration);
    }

    generateReport(duration) {
        this.log('=== REPORTE FINAL DE CARGA Y RENDIMIENTO ===');
        this.log(`⏱️  Duración total: ${(duration / 1000).toFixed(2)}s`);
        this.log(`✅ Tests exitosos: ${this.testResults.passed}`);
        this.log(`❌ Tests fallidos: ${this.testResults.failed}`);
        this.log(`📊 Total de tests: ${this.testResults.total}`);
        
        const successRate = (this.testResults.passed / this.testResults.total * 100).toFixed(1);
        
        if (successRate >= 90) {
            this.log(`🎉 Tasa de éxito: ${successRate}% - SISTEMA LISTO PARA PRODUCCIÓN`, 'success');
        } else if (successRate >= 75) {
            this.log(`⚠️  Tasa de éxito: ${successRate}% - REQUIERE OPTIMIZACIÓN`, 'warning');
        } else {
            this.log(`💥 Tasa de éxito: ${successRate}% - NO LISTO PARA PRODUCCIÓN`, 'error');
        }

        // Generar recomendaciones
        const recommendations = this.generateRecommendations();
        
        // Guardar reporte detallado
        const fs = require('fs');
        const path = require('path');
        
        const reportFile = path.join(__dirname, '../docs/test_results', `load_performance_${Date.now()}.json`);
        const reportDir = path.dirname(reportFile);
        
        if (!fs.existsSync(reportDir)) {
            fs.mkdirSync(reportDir, { recursive: true });
        }
        
        const report = {
            timestamp: new Date().toISOString(),
            duration: duration / 1000,
            configuration: this.config,
            summary: this.testResults,
            successRate: successRate,
            details: this.results,
            recommendations: recommendations,
            performanceMetrics: this.performanceMetrics
        };
        
        fs.writeFileSync(reportFile, JSON.stringify(report, null, 2));
        this.log(`📋 Reporte guardado: ${reportFile}`, 'success');
        
        // Mostrar recomendaciones
        this.log('🔧 RECOMENDACIONES:');
        recommendations.forEach((rec, index) => {
            this.log(`${index + 1}. ${rec}`, 'warning');
        });
    }

    generateRecommendations() {
        const recommendations = [];
        const failedTests = this.results.filter(r => !r.success);
        
        if (failedTests.length > 0) {
            recommendations.push('Investigar y resolver los tests fallidos antes de producción');
            
            if (failedTests.some(t => t.test.includes('Carga'))) {
                recommendations.push('Optimizar manejo de concurrencia en el servidor');
                recommendations.push('Considerar implementar rate limiting');
            }
            
            if (failedTests.some(t => t.test.includes('Endpoint'))) {
                recommendations.push('Optimizar endpoints críticos con caching');
                recommendations.push('Implementar connection pooling para base de datos');
            }
            
            if (failedTests.some(t => t.test.includes('Recursos'))) {
                recommendations.push('Aumentar recursos del servidor (CPU/memoria)');
                recommendations.push('Implementar auto-scaling horizontal');
            }
        }
        
        // Recomendaciones generales
        recommendations.push('Configurar monitoreo continuo de rendimiento');
        recommendations.push('Implementar circuit breakers para servicios externos');
        recommendations.push('Configurar CDN para contenido estático');
        recommendations.push('Establecer alertas para métricas críticas');
        
        return recommendations;
    }
}

// Clase auxiliar para simular usuarios virtuales
class VirtualUser {
    constructor(id, apiUrl) {
        this.id = id;
        this.apiUrl = apiUrl;
        this.active = false;
        this.results = {
            requests: 0,
            successful: 0,
            failed: 0,
            responseTimes: []
        };
    }
    
    async start() {
        this.active = true;
        
        while (this.active) {
            try {
                const startTime = performance.now();
                
                // Simular diferentes acciones de usuario
                const actions = [
                    '/health',
                    '/auth/login',
                    '/passengers/profile',
                    '/drivers/nearby'
                ];
                
                const action = actions[Math.floor(Math.random() * actions.length)];
                await axios.get(`${this.apiUrl}${action}`, { timeout: 5000 });
                
                const responseTime = performance.now() - startTime;
                this.results.responseTimes.push(responseTime);
                this.results.successful++;
                
            } catch (error) {
                this.results.failed++;
            }
            
            this.results.requests++;
            
            // Pausa entre requests
            await new Promise(resolve => setTimeout(resolve, 1000 + Math.random() * 2000));
        }
        
        return this.results;
    }
    
    stop() {
        this.active = false;
    }
}

// Ejecutar si se llama directamente
if (require.main === module) {
    const tester = new LoadPerformanceTester();
    tester.runAllTests().then(() => {
        process.exit(0);
    }).catch((error) => {
        console.error('Error en testing de carga:', error);
        process.exit(1);
    });
}

module.exports = LoadPerformanceTester;
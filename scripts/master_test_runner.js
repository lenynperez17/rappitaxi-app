#!/usr/bin/env node

/**
 * RAPPITAXI - MASTER TEST RUNNER
 * Ejecuta todas las suites de testing de forma ordenada y genera reporte consolidado
 */

const { spawn } = require('child_process');
const fs = require('fs');
const path = require('path');
const chalk = require('chalk');

class MasterTestRunner {
    constructor() {
        this.results = {
            suites: [],
            totalTests: 0,
            passedTests: 0,
            failedTests: 0,
            startTime: Date.now(),
            endTime: null,
            duration: 0
        };
        
        this.testSuites = [
            {
                name: 'REST API Endpoints',
                script: './test_all_endpoints.sh',
                type: 'bash',
                description: 'Testing completo de todos los endpoints REST',
                critical: true,
                estimatedDuration: '5-10 minutos'
            },
            {
                name: 'WebSocket Real-Time',
                script: './test_websockets.js',
                type: 'node',
                description: 'Testing de conexiones WebSocket y comunicación tiempo real',
                critical: true,
                estimatedDuration: '3-5 minutos'
            },
            {
                name: 'Database Integrity',
                script: './test_database_integrity.js',
                type: 'node',
                description: 'Testing de integridad de Firestore y operaciones CRUD',
                critical: true,
                estimatedDuration: '2-4 minutos'
            },
            {
                name: 'Load & Performance',
                script: './test_load_performance.js',
                type: 'node',
                description: 'Testing de carga, rendimiento y escalabilidad',
                critical: false,
                estimatedDuration: '10-15 minutos'
            }
        ];
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
            case 'header':
                console.log(chalk.cyan.bold(`\n🚀 ${message}\n`));
                break;
            case 'section':
                console.log(chalk.blue.bold(`\n=== ${message} ===`));
                break;
            default:
                console.log(chalk.blue(`ℹ️  [${timestamp}] ${message}`));
        }
    }

    // =============================================================================
    // PREPARACIÓN DEL ENTORNO
    // =============================================================================
    async prepareEnvironment() {
        this.log('PREPARANDO ENTORNO DE TESTING', 'header');
        
        try {
            // 1. Verificar que Node.js tiene las dependencias
            this.log('Verificando dependencias de Node.js...');
            const packageJsonPath = path.join(__dirname, 'package.json');
            
            if (!fs.existsSync(packageJsonPath)) {
                this.log('Creando package.json para testing...');
                const packageJson = {
                    name: 'rappitaxi-testing-suite',
                    version: '1.0.0',
                    description: 'Suite completa de testing para RappiTaxi',
                    scripts: {
                        'test:all': 'node master_test_runner.js',
                        'test:api': 'bash test_all_endpoints.sh',
                        'test:websockets': 'node test_websockets.js',
                        'test:database': 'node test_database_integrity.js',
                        'test:performance': 'node test_load_performance.js'
                    },
                    dependencies: {
                        'axios': '^1.6.0',
                        'socket.io-client': '^4.7.0',
                        'firebase-admin': '^11.11.0',
                        'chalk': '^4.1.2'
                    }
                };
                
                fs.writeFileSync(packageJsonPath, JSON.stringify(packageJson, null, 2));
            }
            
            // 2. Verificar que el servidor backend esté corriendo
            this.log('Verificando servidor backend...');
            const { execSync } = require('child_process');
            
            try {
                execSync('curl -s http://localhost:3000/health', { timeout: 5000 });
                this.log('Servidor backend corriendo ✅', 'success');
            } catch (error) {
                this.log('Servidor backend no está corriendo', 'warning');
                this.log('Intentando iniciar el servidor backend...');
                
                const backendPath = path.join(__dirname, '../backend');
                if (fs.existsSync(backendPath)) {
                    this.log('Iniciando servidor backend en segundo plano...');
                    
                    // Intentar instalar dependencias si no existen
                    if (!fs.existsSync(path.join(backendPath, 'node_modules'))) {
                        this.log('Instalando dependencias del backend...');
                        execSync('npm install', { cwd: backendPath, stdio: 'inherit' });
                    }
                    
                    // Iniciar servidor en background
                    const serverProcess = spawn('npm', ['run', 'dev'], {
                        cwd: backendPath,
                        detached: true,
                        stdio: 'ignore'
                    });
                    
                    serverProcess.unref();
                    
                    // Esperar que el servidor inicie
                    this.log('Esperando que el servidor inicie...');
                    let serverStarted = false;
                    for (let i = 0; i < 30; i++) {
                        try {
                            execSync('curl -s http://localhost:3000/health', { timeout: 2000 });
                            serverStarted = true;
                            break;
                        } catch (e) {
                            await new Promise(resolve => setTimeout(resolve, 1000));
                        }
                    }
                    
                    if (serverStarted) {
                        this.log('Servidor backend iniciado correctamente ✅', 'success');
                    } else {
                        throw new Error('No se pudo iniciar el servidor backend');
                    }
                } else {
                    throw new Error('No se encontró el directorio del backend');
                }
            }
            
            // 3. Crear directorio de resultados
            const resultsDir = path.join(__dirname, '../docs/test_results');
            if (!fs.existsSync(resultsDir)) {
                fs.mkdirSync(resultsDir, { recursive: true });
                this.log('Directorio de resultados creado');
            }
            
            // 4. Verificar permisos de scripts
            this.testSuites.forEach(suite => {
                const scriptPath = path.join(__dirname, suite.script);
                if (fs.existsSync(scriptPath)) {
                    if (suite.type === 'bash') {
                        fs.chmodSync(scriptPath, '755');
                    }
                    this.log(`Script ${suite.name} listo`);
                } else {
                    this.log(`ADVERTENCIA: Script ${suite.script} no encontrado`, 'warning');
                }
            });
            
            this.log('Entorno preparado correctamente ✅', 'success');
            
        } catch (error) {
            this.log(`Error preparando entorno: ${error.message}`, 'error');
            throw error;
        }
    }

    // =============================================================================
    // EJECUCIÓN DE SUITE DE TESTS
    // =============================================================================
    async runTestSuite(suite) {
        this.log(`EJECUTANDO: ${suite.name}`, 'section');
        this.log(`Descripción: ${suite.description}`);
        this.log(`Duración estimada: ${suite.estimatedDuration}`);
        
        const startTime = Date.now();
        let success = false;
        let output = '';
        let error = '';
        
        try {
            const result = await this.executeScript(suite.script, suite.type);
            success = result.success;
            output = result.output;
            error = result.error;
            
        } catch (err) {
            error = err.message;
            this.log(`Error ejecutando ${suite.name}: ${err.message}`, 'error');
        }
        
        const duration = Date.now() - startTime;
        
        const suiteResult = {
            name: suite.name,
            script: suite.script,
            success,
            duration: duration,
            output: output.substring(0, 1000), // Limitar output para reporte
            error: error.substring(0, 500),    // Limitar error para reporte
            critical: suite.critical,
            timestamp: new Date().toISOString()
        };
        
        this.results.suites.push(suiteResult);
        
        if (success) {
            this.log(`${suite.name} COMPLETADO ✅ (${(duration/1000).toFixed(2)}s)`, 'success');
        } else {
            this.log(`${suite.name} FALLÓ ❌ (${(duration/1000).toFixed(2)}s)`, 'error');
            
            if (suite.critical) {
                this.log('SUITE CRÍTICA FALLÓ - Continuando con precaución', 'warning');
            }
        }
        
        return suiteResult;
    }

    async executeScript(scriptPath, type) {
        return new Promise((resolve, reject) => {
            const fullPath = path.join(__dirname, scriptPath);
            let command, args;
            
            if (type === 'bash') {
                command = 'bash';
                args = [fullPath];
            } else if (type === 'node') {
                command = 'node';
                args = [fullPath];
            } else {
                return reject(new Error(`Tipo de script desconocido: ${type}`));
            }
            
            const child = spawn(command, args, {
                cwd: __dirname,
                stdio: ['pipe', 'pipe', 'pipe']
            });
            
            let output = '';
            let error = '';
            
            child.stdout.on('data', (data) => {
                const text = data.toString();
                output += text;
                // Mostrar output en tiempo real
                process.stdout.write(text);
            });
            
            child.stderr.on('data', (data) => {
                const text = data.toString();
                error += text;
                // Mostrar errores en tiempo real
                process.stderr.write(chalk.red(text));
            });
            
            child.on('close', (code) => {
                resolve({
                    success: code === 0,
                    output,
                    error,
                    exitCode: code
                });
            });
            
            child.on('error', (err) => {
                reject(err);
            });
            
            // Timeout de seguridad (30 minutos máximo por suite)
            setTimeout(() => {
                child.kill('SIGTERM');
                reject(new Error('Timeout: Suite tomó más de 30 minutos'));
            }, 30 * 60 * 1000);
        });
    }

    // =============================================================================
    // ANÁLISIS DE RESULTADOS
    // =============================================================================
    analyzeResults() {
        this.log('ANALIZANDO RESULTADOS', 'section');
        
        const totalSuites = this.results.suites.length;
        const successfulSuites = this.results.suites.filter(s => s.success).length;
        const failedSuites = this.results.suites.filter(s => !s.success).length;
        const criticalFailures = this.results.suites.filter(s => !s.success && s.critical).length;
        
        // Calcular métricas
        const successRate = (successfulSuites / totalSuites) * 100;
        const totalDuration = this.results.suites.reduce((sum, s) => sum + s.duration, 0);
        
        this.log(`📊 ESTADÍSTICAS GENERALES:`);
        this.log(`   Total de suites: ${totalSuites}`);
        this.log(`   Suites exitosas: ${successfulSuites}`);
        this.log(`   Suites fallidas: ${failedSuites}`);
        this.log(`   Fallas críticas: ${criticalFailures}`);
        this.log(`   Tasa de éxito: ${successRate.toFixed(1)}%`);
        this.log(`   Duración total: ${(totalDuration / 1000 / 60).toFixed(2)} minutos`);
        
        // Determinar estado del sistema
        let systemStatus;
        let statusColor;
        
        if (criticalFailures === 0 && successRate >= 95) {
            systemStatus = 'SISTEMA LISTO PARA PRODUCCIÓN 🚀';
            statusColor = 'success';
        } else if (criticalFailures === 0 && successRate >= 80) {
            systemStatus = 'SISTEMA REQUIERE MEJORAS MENORES ⚠️';
            statusColor = 'warning';
        } else if (criticalFailures <= 1 && successRate >= 60) {
            systemStatus = 'SISTEMA REQUIERE CORRECCIONES IMPORTANTES 🔧';
            statusColor = 'warning';
        } else {
            systemStatus = 'SISTEMA NO LISTO PARA PRODUCCIÓN ❌';
            statusColor = 'error';
        }
        
        this.log(systemStatus, statusColor);
        
        // Mostrar detalles de fallas
        if (failedSuites > 0) {
            this.log('🔍 ANÁLISIS DE FALLAS:', 'warning');
            this.results.suites.filter(s => !s.success).forEach(suite => {
                this.log(`   ❌ ${suite.name}:`, 'error');
                if (suite.error) {
                    this.log(`      Error: ${suite.error.split('\n')[0]}`, 'error');
                }
            });
        }
        
        return {
            systemStatus,
            successRate,
            criticalFailures,
            totalDuration
        };
    }

    // =============================================================================
    // GENERACIÓN DE REPORTE CONSOLIDADO
    // =============================================================================
    generateConsolidatedReport() {
        this.log('GENERANDO REPORTE CONSOLIDADO', 'section');
        
        this.results.endTime = Date.now();
        this.results.duration = this.results.endTime - this.results.startTime;
        
        const analysis = this.analyzeResults();
        
        const report = {
            metadata: {
                timestamp: new Date().toISOString(),
                version: '1.0.0',
                environment: {
                    node: process.version,
                    platform: process.platform,
                    arch: process.arch
                }
            },
            summary: {
                totalSuites: this.results.suites.length,
                successfulSuites: this.results.suites.filter(s => s.success).length,
                failedSuites: this.results.suites.filter(s => !s.success).length,
                criticalFailures: this.results.suites.filter(s => !s.success && s.critical).length,
                successRate: analysis.successRate,
                totalDuration: this.results.duration,
                systemStatus: analysis.systemStatus
            },
            suites: this.results.suites,
            recommendations: this.generateRecommendations(analysis),
            nextSteps: this.generateNextSteps(analysis)
        };
        
        // Guardar reporte JSON
        const jsonReportPath = path.join(__dirname, '../docs/test_results', `consolidated_report_${Date.now()}.json`);
        fs.writeFileSync(jsonReportPath, JSON.stringify(report, null, 2));
        this.log(`Reporte JSON guardado: ${jsonReportPath}`, 'success');
        
        // Generar reporte HTML
        this.generateHTMLReport(report);
        
        // Generar reporte Markdown
        this.generateMarkdownReport(report);
        
        return report;
    }

    generateRecommendations(analysis) {
        const recommendations = [];
        
        if (analysis.criticalFailures > 0) {
            recommendations.push('🚨 CRÍTICO: Resolver inmediatamente las fallas en suites críticas');
            recommendations.push('No proceder a producción hasta resolver fallas críticas');
        }
        
        if (analysis.successRate < 90) {
            recommendations.push('Investigar y corregir las suites fallidas');
            recommendations.push('Ejecutar tests adicionales después de correcciones');
        }
        
        // Recomendaciones generales
        recommendations.push('Configurar pipeline CI/CD para ejecutar estos tests automáticamente');
        recommendations.push('Establecer monitoreo continuo en producción');
        recommendations.push('Programar ejecución regular de tests de carga');
        recommendations.push('Documentar procedimientos de rollback en caso de issues');
        
        return recommendations;
    }

    generateNextSteps(analysis) {
        const nextSteps = [];
        
        if (analysis.systemStatus.includes('LISTO PARA PRODUCCIÓN')) {
            nextSteps.push('✅ Proceder con deployment a producción');
            nextSteps.push('🔄 Configurar monitoreo post-deployment');
            nextSteps.push('📊 Establecer alertas para métricas críticas');
        } else {
            nextSteps.push('🔧 Corregir issues identificados en testing');
            nextSteps.push('🔄 Re-ejecutar suite completa de tests');
            nextSteps.push('👥 Revisar con el equipo antes de proceder');
        }
        
        nextSteps.push('📚 Actualizar documentación técnica');
        nextSteps.push('🎯 Planificar tests adicionales si es necesario');
        
        return nextSteps;
    }

    generateHTMLReport(report) {
        const html = `
<!DOCTYPE html>
<html lang="es">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>RappiTaxi - Reporte de Testing Completo</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 20px; background: #f5f5f5; }
        .container { max-width: 1200px; margin: 0 auto; background: white; padding: 20px; border-radius: 8px; box-shadow: 0 2px 10px rgba(0,0,0,0.1); }
        .header { background: linear-gradient(135deg, #667eea 0%, #764ba2 100%); color: white; padding: 20px; border-radius: 8px; margin-bottom: 20px; }
        .summary { display: grid; grid-template-columns: repeat(auto-fit, minmax(200px, 1fr)); gap: 15px; margin-bottom: 20px; }
        .metric { background: #f8f9fa; padding: 15px; border-radius: 8px; text-align: center; }
        .metric h3 { margin: 0 0 10px 0; color: #333; }
        .metric .value { font-size: 2em; font-weight: bold; }
        .success { color: #28a745; }
        .warning { color: #ffc107; }
        .error { color: #dc3545; }
        .suite { background: #f8f9fa; margin: 10px 0; padding: 15px; border-radius: 8px; border-left: 4px solid #ddd; }
        .suite.success { border-left-color: #28a745; }
        .suite.failed { border-left-color: #dc3545; }
        .recommendations { background: #e3f2fd; padding: 15px; border-radius: 8px; margin: 20px 0; }
        .next-steps { background: #f3e5f5; padding: 15px; border-radius: 8px; margin: 20px 0; }
    </style>
</head>
<body>
    <div class="container">
        <div class="header">
            <h1>🚕 RappiTaxi - Reporte de Testing Completo</h1>
            <p>Generado el ${new Date(report.metadata.timestamp).toLocaleString('es-ES')}</p>
        </div>
        
        <div class="summary">
            <div class="metric">
                <h3>Estado del Sistema</h3>
                <div class="value ${report.summary.criticalFailures === 0 ? 'success' : 'error'}">
                    ${report.summary.systemStatus.includes('LISTO') ? '✅' : '❌'}
                </div>
            </div>
            <div class="metric">
                <h3>Tasa de Éxito</h3>
                <div class="value ${report.summary.successRate >= 90 ? 'success' : report.summary.successRate >= 70 ? 'warning' : 'error'}">
                    ${report.summary.successRate.toFixed(1)}%
                </div>
            </div>
            <div class="metric">
                <h3>Suites Exitosas</h3>
                <div class="value success">${report.summary.successfulSuites}/${report.summary.totalSuites}</div>
            </div>
            <div class="metric">
                <h3>Duración Total</h3>
                <div class="value">${(report.summary.totalDuration / 1000 / 60).toFixed(1)} min</div>
            </div>
        </div>
        
        <h2>📋 Resultados por Suite</h2>
        ${report.suites.map(suite => `
            <div class="suite ${suite.success ? 'success' : 'failed'}">
                <h3>${suite.success ? '✅' : '❌'} ${suite.name}</h3>
                <p><strong>Duración:</strong> ${(suite.duration / 1000).toFixed(2)}s</p>
                ${!suite.success && suite.error ? `<p><strong>Error:</strong> ${suite.error}</p>` : ''}
                ${suite.critical ? '<span style="background: #ff9800; color: white; padding: 2px 8px; border-radius: 4px; font-size: 0.8em;">CRÍTICO</span>' : ''}
            </div>
        `).join('')}
        
        <div class="recommendations">
            <h2>💡 Recomendaciones</h2>
            <ul>
                ${report.recommendations.map(rec => `<li>${rec}</li>`).join('')}
            </ul>
        </div>
        
        <div class="next-steps">
            <h2>🎯 Próximos Pasos</h2>
            <ul>
                ${report.nextSteps.map(step => `<li>${step}</li>`).join('')}
            </ul>
        </div>
    </div>
</body>
</html>`;
        
        const htmlReportPath = path.join(__dirname, '../docs/test_results', `consolidated_report_${Date.now()}.html`);
        fs.writeFileSync(htmlReportPath, html);
        this.log(`Reporte HTML guardado: ${htmlReportPath}`, 'success');
    }

    generateMarkdownReport(report) {
        const md = `# 🚕 RappiTaxi - Reporte de Testing Completo

**Generado el:** ${new Date(report.metadata.timestamp).toLocaleString('es-ES')}

## 📊 Resumen Ejecutivo

| Métrica | Valor | Estado |
|---------|-------|---------|
| Estado del Sistema | ${report.summary.systemStatus} | ${report.summary.criticalFailures === 0 ? '✅' : '❌'} |
| Tasa de Éxito | ${report.summary.successRate.toFixed(1)}% | ${report.summary.successRate >= 90 ? '✅' : report.summary.successRate >= 70 ? '⚠️' : '❌'} |
| Suites Exitosas | ${report.summary.successfulSuites}/${report.summary.totalSuites} | - |
| Duración Total | ${(report.summary.totalDuration / 1000 / 60).toFixed(1)} minutos | - |

## 📋 Resultados por Suite

${report.suites.map(suite => `
### ${suite.success ? '✅' : '❌'} ${suite.name} ${suite.critical ? '🚨 CRÍTICO' : ''}

- **Duración:** ${(suite.duration / 1000).toFixed(2)}s
- **Estado:** ${suite.success ? 'EXITOSO' : 'FALLIDO'}
${!suite.success && suite.error ? `- **Error:** \`${suite.error.split('\n')[0]}\`` : ''}

`).join('')}

## 💡 Recomendaciones

${report.recommendations.map(rec => `- ${rec}`).join('\n')}

## 🎯 Próximos Pasos

${report.nextSteps.map(step => `- ${step}`).join('\n')}

---

*Reporte generado automáticamente por RappiTaxi Testing Suite v1.0.0*
`;
        
        const mdReportPath = path.join(__dirname, '../docs/test_results', `consolidated_report_${Date.now()}.md`);
        fs.writeFileSync(mdReportPath, md);
        this.log(`Reporte Markdown guardado: ${mdReportPath}`, 'success');
    }

    // =============================================================================
    // FUNCIÓN PRINCIPAL
    // =============================================================================
    async runAllTests() {
        this.log('RAPPITAXI - INICIANDO TESTING COMPLETO DEL SISTEMA', 'header');
        
        try {
            // Preparar entorno
            await this.prepareEnvironment();
            
            // Ejecutar cada suite de tests
            for (const suite of this.testSuites) {
                await this.runTestSuite(suite);
                
                // Pausa entre suites para no sobrecargar el sistema
                await new Promise(resolve => setTimeout(resolve, 2000));
            }
            
            // Generar reporte consolidado
            const report = this.generateConsolidatedReport();
            
            this.log('TESTING COMPLETO FINALIZADO', 'header');
            this.log(report.summary.systemStatus, 
                report.summary.criticalFailures === 0 ? 'success' : 'error');
            
            // Exit code basado en resultados
            const exitCode = report.summary.criticalFailures === 0 && report.summary.successRate >= 80 ? 0 : 1;
            process.exit(exitCode);
            
        } catch (error) {
            this.log(`Error crítico en testing: ${error.message}`, 'error');
            process.exit(1);
        }
    }
}

// Ejecutar si se llama directamente
if (require.main === module) {
    const runner = new MasterTestRunner();
    runner.runAllTests();
}

module.exports = MasterTestRunner;
import { Request, Response } from 'express';
import * as admin from 'firebase-admin';
import { logger } from '@shared/utils/logger';
import { ApiResponse } from '@shared/types';

/**
 * Obtener métricas del dashboard
 */
export const getDashboardMetrics = async (req: Request, res: Response): Promise<void> => {
  try {
    const { period = 'today' } = req.query as {
      period: string;
    };

    // Calcular fechas según período
    const now = new Date();
    let startDate: Date;
    
    switch (period) {
      case 'week':
        startDate = new Date(now.getTime() - 7 * 24 * 60 * 60 * 1000);
        break;
      case 'month':
        startDate = new Date(now.getFullYear(), now.getMonth(), 1);
        break;
      case 'quarter':
        startDate = new Date(now.getFullYear(), Math.floor(now.getMonth() / 3) * 3, 1);
        break;
      case 'year':
        startDate = new Date(now.getFullYear(), 0, 1);
        break;
      default: // today
        startDate = new Date(now.getFullYear(), now.getMonth(), now.getDate());
    }

    const db = admin.firestore();

    // Métricas paralelas
    const [
      totalUsers,
      activeRides,
      completedRides,
      totalRevenue,
      activeDrivers,
      waitingRequests
    ] = await Promise.all([
      // Total de usuarios
      db.collection('users').count().get().then(snap => snap.data().count),
      
      // Viajes activos
      db.collection('rides')
        .where('status', 'in', ['accepted', 'in_progress', 'arrived'])
        .count()
        .get()
        .then(snap => snap.data().count),
        
      // Viajes completados en el período
      db.collection('rides')
        .where('completedAt', '>=', admin.firestore.Timestamp.fromDate(startDate))
        .where('status', '==', 'completed')
        .count()
        .get()
        .then(snap => snap.data().count),
        
      // Ingresos totales del período
      db.collection('payments')
        .where('createdAt', '>=', admin.firestore.Timestamp.fromDate(startDate))
        .where('status', '==', 'completed')
        .get()
        .then(snap => {
          return snap.docs.reduce((sum, doc) => {
            return sum + (doc.data().amount || 0);
          }, 0);
        }),
        
      // Conductores activos (últimas 24h)
      db.collection('drivers')
        .where('lastActiveAt', '>=', admin.firestore.Timestamp.fromDate(
          new Date(now.getTime() - 24 * 60 * 60 * 1000)
        ))
        .where('status', '==', 'online')
        .count()
        .get()
        .then(snap => snap.data().count),
        
      // Solicitudes esperando conductor
      db.collection('rides')
        .where('status', '==', 'pending')
        .count()
        .get()
        .then(snap => snap.data().count)
    ]);

    const metrics = {
      totalUsers,
      activeRides,
      completedRides,
      totalRevenue,
      activeDrivers,
      waitingRequests,
      period,
      generatedAt: new Date().toISOString(),
    };

    logger.info('Dashboard metrics generated', {
      adminId: req.userId,
      period,
      metrics: {
        totalUsers,
        activeRides,
        completedRides,
        totalRevenue
      }
    });

    const response: ApiResponse = {
      success: true,
      data: metrics,
      timestamp: new Date().toISOString(),
    };

    res.json(response);
  } catch (error: any) {
    logger.error('Error getting dashboard metrics:', error);
    res.status(500).json({
      success: false,
      error: {
        code: 'DASHBOARD_METRICS_ERROR',
        message: 'Error obteniendo métricas del dashboard',
        details: process.env.NODE_ENV === 'development' ? error.message : undefined,
      },
      timestamp: new Date().toISOString(),
    });
  }
};

/**
 * Obtener estadísticas en tiempo real
 */
export const getRealtimeStats = async (req: Request, res: Response): Promise<void> => {
  try {
    const db = admin.firestore();
    const now = new Date();
    
    // Stats en tiempo real
    const [
      onlineDrivers,
      pendingRides,
      ridesInProgress,
      avgWaitTime,
      systemHealth
    ] = await Promise.all([
      // Conductores online
      db.collection('drivers')
        .where('status', '==', 'online')
        .where('lastHeartbeat', '>=', admin.firestore.Timestamp.fromDate(
          new Date(now.getTime() - 5 * 60 * 1000) // últimos 5 min
        ))
        .count()
        .get()
        .then(snap => snap.data().count),
        
      // Viajes pendientes
      db.collection('rides')
        .where('status', '==', 'pending')
        .count()
        .get()
        .then(snap => snap.data().count),
        
      // Viajes en progreso
      db.collection('rides')
        .where('status', 'in', ['accepted', 'in_progress', 'arrived'])
        .count()
        .get()
        .then(snap => snap.data().count),
        
      // Tiempo promedio de espera (últimos 100 viajes)
      db.collection('rides')
        .where('status', '==', 'completed')
        .orderBy('completedAt', 'desc')
        .limit(100)
        .get()
        .then(snap => {
          if (snap.empty) return 0;
          const waitTimes = snap.docs
            .map(doc => doc.data().waitTimeMinutes)
            .filter(time => typeof time === 'number');
          return waitTimes.length > 0 
            ? waitTimes.reduce((sum, time) => sum + time, 0) / waitTimes.length
            : 0;
        }),
        
      // Health del sistema
      Promise.resolve({
        status: 'healthy',
        uptime: process.uptime(),
        memory: process.memoryUsage(),
        timestamp: now.toISOString()
      })
    ]);

    const realtimeStats = {
      onlineDrivers,
      pendingRides,
      ridesInProgress,
      avgWaitTime: Math.round(avgWaitTime * 100) / 100, // 2 decimales
      supplyDemandRatio: onlineDrivers > 0 ? pendingRides / onlineDrivers : 0,
      systemHealth,
      timestamp: now.toISOString(),
    };

    const response: ApiResponse = {
      success: true,
      data: realtimeStats,
      timestamp: new Date().toISOString(),
    };

    res.json(response);
  } catch (error: any) {
    logger.error('Error getting realtime stats:', error);
    res.status(500).json({
      success: false,
      error: {
        code: 'REALTIME_STATS_ERROR',
        message: 'Error obteniendo estadísticas en tiempo real',
        details: process.env.NODE_ENV === 'development' ? error.message : undefined,
      },
      timestamp: new Date().toISOString(),
    });
  }
};

/**
 * Obtener alertas del sistema
 */
export const getSystemAlerts = async (req: Request, res: Response): Promise<void> => {
  try {
    const { severity, resolved } = req.query as {
      severity?: string;
      resolved?: boolean;
    };

    const db = admin.firestore();
    let query = db.collection('system_alerts');

    if (severity) {
      query = query.where('severity', '==', severity) as any;
    }

    if (resolved !== undefined) {
      query = query.where('resolved', '==', resolved) as any;
    }

    const alertsSnap = await query
      .orderBy('createdAt', 'desc')
      .limit(50)
      .get();

    const alerts = alertsSnap.docs.map(doc => ({
      id: doc.id,
      ...doc.data()
    }));

    const response: ApiResponse = {
      success: true,
      data: {
        alerts,
        total: alerts.length,
      },
      timestamp: new Date().toISOString(),
    };

    res.json(response);
  } catch (error: any) {
    logger.error('Error getting system alerts:', error);
    res.status(500).json({
      success: false,
      error: {
        code: 'SYSTEM_ALERTS_ERROR',
        message: 'Error obteniendo alertas del sistema',
        details: process.env.NODE_ENV === 'development' ? error.message : undefined,
      },
      timestamp: new Date().toISOString(),
    });
  }
};

/**
 * Resolver alerta
 */
export const resolveAlert = async (req: Request, res: Response): Promise<void> => {
  try {
    const { alertId } = req.params;
    const { resolution } = req.body;

    const db = admin.firestore();
    const alertRef = db.collection('system_alerts').doc(alertId);

    await alertRef.update({
      resolved: true,
      resolution,
      resolvedAt: admin.firestore.FieldValue.serverTimestamp(),
      resolvedBy: req.userId,
    });

    logger.info('System alert resolved', {
      alertId,
      resolvedBy: req.userId,
      resolution,
    });

    const response: ApiResponse = {
      success: true,
      data: { message: 'Alerta resuelta correctamente' },
      timestamp: new Date().toISOString(),
    };

    res.json(response);
  } catch (error: any) {
    logger.error('Error resolving alert:', error);
    res.status(500).json({
      success: false,
      error: {
        code: 'RESOLVE_ALERT_ERROR',
        message: 'Error resolviendo alerta',
        details: process.env.NODE_ENV === 'development' ? error.message : undefined,
      },
      timestamp: new Date().toISOString(),
    });
  }
};
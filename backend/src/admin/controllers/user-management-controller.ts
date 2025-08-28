import { Request, Response } from 'express';
import * as admin from 'firebase-admin';
import { logger } from '@shared/utils/logger';
import { ApiResponse } from '@shared/types';

/**
 * Buscar usuarios
 */
export const searchUsers = async (req: Request, res: Response): Promise<void> => {
  try {
    const {
      role,
      status,
      verified,
      search,
      page = '1',
      limit = '20',
      sortBy = 'createdAt',
      order = 'desc'
    } = req.query as Record<string, string>;

    const db = admin.firestore();
    let query = db.collection('users') as any;

    // Filtros
    if (role) {
      query = query.where('role', '==', role);
    }
    if (status) {
      query = query.where('status', '==', status);
    }
    if (verified !== undefined) {
      query = query.where('verified', '==', verified === 'true');
    }

    // Ordenamiento
    query = query.orderBy(sortBy, order);

    // Paginación
    const pageNum = parseInt(page, 10);
    const limitNum = parseInt(limit, 10);
    const offset = (pageNum - 1) * limitNum;

    query = query.limit(limitNum).offset(offset);

    const snapshot = await query.get();
    const users = snapshot.docs.map((doc: any) => ({
      id: doc.id,
      ...doc.data(),
      // No devolver información sensible
      password: undefined,
      refreshTokens: undefined,
    }));

    // Total de usuarios (sin filtros para simplicidad)
    const totalSnapshot = await db.collection('users').count().get();
    const total = totalSnapshot.data().count;

    const response: ApiResponse = {
      success: true,
      data: {
        users,
        pagination: {
          page: pageNum,
          limit: limitNum,
          total,
          totalPages: Math.ceil(total / limitNum),
        },
      },
      timestamp: new Date().toISOString(),
    };

    res.json(response);
  } catch (error: any) {
    logger.error('Error searching users:', error);
    res.status(500).json({
      success: false,
      error: {
        code: 'SEARCH_USERS_ERROR',
        message: 'Error buscando usuarios',
        details: process.env.NODE_ENV === 'development' ? error.message : undefined,
      },
      timestamp: new Date().toISOString(),
    });
  }
};

/**
 * Obtener detalles de usuario
 */
export const getUserDetails = async (req: Request, res: Response): Promise<void> => {
  try {
    const { userId } = req.params;

    const db = admin.firestore();
    const userDoc = await db.collection('users').doc(userId).get();

    if (!userDoc.exists) {
      res.status(404).json({
        success: false,
        error: {
          code: 'USER_NOT_FOUND',
          message: 'Usuario no encontrado',
        },
        timestamp: new Date().toISOString(),
      });
      return;
    }

    const userData = { id: userDoc.id, ...userDoc.data() };
    
    // Remover información sensible
    delete (userData as any).password;
    delete (userData as any).refreshTokens;

    // Obtener métricas adicionales si es conductor o pasajero
    const metrics: any = {};

    if ((userData as any).role === 'driver') {
      const [ridesCount, avgRating, totalEarnings] = await Promise.all([
        db.collection('rides')
          .where('driverId', '==', userId)
          .where('status', '==', 'completed')
          .count()
          .get()
          .then(snap => snap.data().count),
        
        db.collection('ratings')
          .where('driverId', '==', userId)
          .get()
          .then(snap => {
            if (snap.empty) return 0;
            const ratings = snap.docs.map(doc => doc.data().rating);
            return ratings.reduce((sum, rating) => sum + rating, 0) / ratings.length;
          }),
          
        db.collection('payments')
          .where('driverId', '==', userId)
          .where('status', '==', 'completed')
          .get()
          .then(snap => {
            return snap.docs.reduce((sum, doc) => {
              const data = doc.data();
              return sum + (data.driverEarnings || 0);
            }, 0);
          }),
      ]);

      metrics.ridesCompleted = ridesCount;
      metrics.averageRating = Math.round(avgRating * 100) / 100;
      metrics.totalEarnings = totalEarnings;
    }

    if ((userData as any).role === 'passenger') {
      const [ridesCount, totalSpent, avgRating] = await Promise.all([
        db.collection('rides')
          .where('passengerId', '==', userId)
          .where('status', '==', 'completed')
          .count()
          .get()
          .then(snap => snap.data().count),
        
        db.collection('payments')
          .where('passengerId', '==', userId)
          .where('status', '==', 'completed')
          .get()
          .then(snap => {
            return snap.docs.reduce((sum, doc) => {
              return sum + (doc.data().amount || 0);
            }, 0);
          }),
          
        db.collection('ratings')
          .where('passengerId', '==', userId)
          .get()
          .then(snap => {
            if (snap.empty) return 0;
            const ratings = snap.docs.map(doc => doc.data().passengerRating);
            return ratings.reduce((sum, rating) => sum + rating, 0) / ratings.length;
          }),
      ]);

      metrics.ridesCompleted = ridesCount;
      metrics.totalSpent = totalSpent;
      metrics.averageRating = Math.round(avgRating * 100) / 100;
    }

    const response: ApiResponse = {
      success: true,
      data: {
        user: userData,
        metrics,
      },
      timestamp: new Date().toISOString(),
    };

    res.json(response);
  } catch (error: any) {
    logger.error('Error getting user details:', error);
    res.status(500).json({
      success: false,
      error: {
        code: 'GET_USER_DETAILS_ERROR',
        message: 'Error obteniendo detalles del usuario',
        details: process.env.NODE_ENV === 'development' ? error.message : undefined,
      },
      timestamp: new Date().toISOString(),
    });
  }
};

/**
 * Actualizar usuario
 */
export const updateUser = async (req: Request, res: Response): Promise<void> => {
  try {
    const { userId } = req.params;
    const { status, verified, role, notes } = req.body;

    const db = admin.firestore();
    const userRef = db.collection('users').doc(userId);

    // Verificar que el usuario existe
    const userDoc = await userRef.get();
    if (!userDoc.exists) {
      res.status(404).json({
        success: false,
        error: {
          code: 'USER_NOT_FOUND',
          message: 'Usuario no encontrado',
        },
        timestamp: new Date().toISOString(),
      });
      return;
    }

    const updateData: any = {
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      updatedBy: req.userId,
    };

    if (status !== undefined) updateData.status = status;
    if (verified !== undefined) updateData.verified = verified;
    if (role !== undefined) updateData.role = role;
    if (notes !== undefined) updateData.adminNotes = notes;

    await userRef.update(updateData);

    logger.info('User updated by admin', {
      targetUserId: userId,
      adminId: req.userId,
      changes: updateData,
    });

    const response: ApiResponse = {
      success: true,
      data: { message: 'Usuario actualizado correctamente' },
      timestamp: new Date().toISOString(),
    };

    res.json(response);
  } catch (error: any) {
    logger.error('Error updating user:', error);
    res.status(500).json({
      success: false,
      error: {
        code: 'UPDATE_USER_ERROR',
        message: 'Error actualizando usuario',
        details: process.env.NODE_ENV === 'development' ? error.message : undefined,
      },
      timestamp: new Date().toISOString(),
    });
  }
};

/**
 * Suspender usuario
 */
export const suspendUser = async (req: Request, res: Response): Promise<void> => {
  try {
    const { userId } = req.params;
    const { reason, duration, notifyUser = true } = req.body;

    const db = admin.firestore();
    const userRef = db.collection('users').doc(userId);

    // Verificar que el usuario existe
    const userDoc = await userRef.get();
    if (!userDoc.exists) {
      res.status(404).json({
        success: false,
        error: {
          code: 'USER_NOT_FOUND',
          message: 'Usuario no encontrado',
        },
        timestamp: new Date().toISOString(),
      });
      return;
    }

    const suspendedUntil = duration 
      ? new Date(Date.now() + duration * 24 * 60 * 60 * 1000) 
      : null;

    await userRef.update({
      status: 'suspended',
      suspendedAt: admin.firestore.FieldValue.serverTimestamp(),
      suspendedBy: req.userId,
      suspensionReason: reason,
      suspendedUntil: suspendedUntil ? admin.firestore.Timestamp.fromDate(suspendedUntil) : null,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    // Log de auditoría
    await db.collection('admin_actions').add({
      adminId: req.userId,
      action: 'USER_SUSPENDED',
      targetUserId: userId,
      reason,
      duration,
      suspendedUntil,
      timestamp: admin.firestore.FieldValue.serverTimestamp(),
    });

    logger.info('User suspended', {
      targetUserId: userId,
      adminId: req.userId,
      reason,
      duration,
    });

    const response: ApiResponse = {
      success: true,
      data: { message: 'Usuario suspendido correctamente' },
      timestamp: new Date().toISOString(),
    };

    res.json(response);
  } catch (error: any) {
    logger.error('Error suspending user:', error);
    res.status(500).json({
      success: false,
      error: {
        code: 'SUSPEND_USER_ERROR',
        message: 'Error suspendiendo usuario',
        details: process.env.NODE_ENV === 'development' ? error.message : undefined,
      },
      timestamp: new Date().toISOString(),
    });
  }
};

/**
 * Banear usuario
 */
export const banUser = async (req: Request, res: Response): Promise<void> => {
  try {
    const { userId } = req.params;
    const { reason, permanent = false, notifyUser = true } = req.body;

    const db = admin.firestore();
    const userRef = db.collection('users').doc(userId);

    // Verificar que el usuario existe
    const userDoc = await userRef.get();
    if (!userDoc.exists) {
      res.status(404).json({
        success: false,
        error: {
          code: 'USER_NOT_FOUND',
          message: 'Usuario no encontrado',
        },
        timestamp: new Date().toISOString(),
      });
      return;
    }

    await userRef.update({
      status: 'banned',
      bannedAt: admin.firestore.FieldValue.serverTimestamp(),
      bannedBy: req.userId,
      banReason: reason,
      permanentBan: permanent,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    // También deshabilitar en Firebase Auth
    try {
      await admin.auth().updateUser(userId, { disabled: true });
    } catch (authError) {
      logger.warn('Error disabling user in Firebase Auth:', authError);
    }

    // Log de auditoría
    await db.collection('admin_actions').add({
      adminId: req.userId,
      action: 'USER_BANNED',
      targetUserId: userId,
      reason,
      permanent,
      timestamp: admin.firestore.FieldValue.serverTimestamp(),
    });

    logger.info('User banned', {
      targetUserId: userId,
      adminId: req.userId,
      reason,
      permanent,
    });

    const response: ApiResponse = {
      success: true,
      data: { message: 'Usuario baneado correctamente' },
      timestamp: new Date().toISOString(),
    };

    res.json(response);
  } catch (error: any) {
    logger.error('Error banning user:', error);
    res.status(500).json({
      success: false,
      error: {
        code: 'BAN_USER_ERROR',
        message: 'Error baneando usuario',
        details: process.env.NODE_ENV === 'development' ? error.message : undefined,
      },
      timestamp: new Date().toISOString(),
    });
  }
};

/**
 * Reactivar usuario
 */
export const reactivateUser = async (req: Request, res: Response): Promise<void> => {
  try {
    const { userId } = req.params;
    const { reason } = req.body;

    const db = admin.firestore();
    const userRef = db.collection('users').doc(userId);

    // Verificar que el usuario existe
    const userDoc = await userRef.get();
    if (!userDoc.exists) {
      res.status(404).json({
        success: false,
        error: {
          code: 'USER_NOT_FOUND',
          message: 'Usuario no encontrado',
        },
        timestamp: new Date().toISOString(),
      });
      return;
    }

    await userRef.update({
      status: 'active',
      reactivatedAt: admin.firestore.FieldValue.serverTimestamp(),
      reactivatedBy: req.userId,
      reactivationReason: reason,
      suspendedAt: admin.firestore.FieldValue.delete(),
      suspendedBy: admin.firestore.FieldValue.delete(),
      suspensionReason: admin.firestore.FieldValue.delete(),
      suspendedUntil: admin.firestore.FieldValue.delete(),
      bannedAt: admin.firestore.FieldValue.delete(),
      bannedBy: admin.firestore.FieldValue.delete(),
      banReason: admin.firestore.FieldValue.delete(),
      permanentBan: admin.firestore.FieldValue.delete(),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    // También rehabilitar en Firebase Auth
    try {
      await admin.auth().updateUser(userId, { disabled: false });
    } catch (authError) {
      logger.warn('Error enabling user in Firebase Auth:', authError);
    }

    // Log de auditoría
    await db.collection('admin_actions').add({
      adminId: req.userId,
      action: 'USER_REACTIVATED',
      targetUserId: userId,
      reason,
      timestamp: admin.firestore.FieldValue.serverTimestamp(),
    });

    logger.info('User reactivated', {
      targetUserId: userId,
      adminId: req.userId,
      reason,
    });

    const response: ApiResponse = {
      success: true,
      data: { message: 'Usuario reactivado correctamente' },
      timestamp: new Date().toISOString(),
    };

    res.json(response);
  } catch (error: any) {
    logger.error('Error reactivating user:', error);
    res.status(500).json({
      success: false,
      error: {
        code: 'REACTIVATE_USER_ERROR',
        message: 'Error reactivando usuario',
        details: process.env.NODE_ENV === 'development' ? error.message : undefined,
      },
      timestamp: new Date().toISOString(),
    });
  }
};

/**
 * Verificar conductor
 */
export const verifyDriver = async (req: Request, res: Response): Promise<void> => {
  try {
    const { driverId } = req.params;
    const { documents, notes } = req.body;

    const db = admin.firestore();
    const driverRef = db.collection('users').doc(driverId);

    // Verificar que el conductor existe
    const driverDoc = await driverRef.get();
    if (!driverDoc.exists || driverDoc.data()?.role !== 'driver') {
      res.status(404).json({
        success: false,
        error: {
          code: 'DRIVER_NOT_FOUND',
          message: 'Conductor no encontrado',
        },
        timestamp: new Date().toISOString(),
      });
      return;
    }

    await driverRef.update({
      verified: true,
      verifiedAt: admin.firestore.FieldValue.serverTimestamp(),
      verifiedBy: req.userId,
      documentsVerification: documents,
      verificationNotes: notes,
      status: 'active',
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    // Log de auditoría
    await db.collection('admin_actions').add({
      adminId: req.userId,
      action: 'DRIVER_VERIFIED',
      targetUserId: driverId,
      documents,
      notes,
      timestamp: admin.firestore.FieldValue.serverTimestamp(),
    });

    logger.info('Driver verified', {
      driverId,
      adminId: req.userId,
      documents,
    });

    const response: ApiResponse = {
      success: true,
      data: { message: 'Conductor verificado correctamente' },
      timestamp: new Date().toISOString(),
    };

    res.json(response);
  } catch (error: any) {
    logger.error('Error verifying driver:', error);
    res.status(500).json({
      success: false,
      error: {
        code: 'VERIFY_DRIVER_ERROR',
        message: 'Error verificando conductor',
        details: process.env.NODE_ENV === 'development' ? error.message : undefined,
      },
      timestamp: new Date().toISOString(),
    });
  }
};

/**
 * Rechazar verificación de conductor
 */
export const rejectDriverVerification = async (req: Request, res: Response): Promise<void> => {
  try {
    const { driverId } = req.params;
    const { reasons, canReapply = true, reapplyAfterDays = 30 } = req.body;

    const db = admin.firestore();
    const driverRef = db.collection('users').doc(driverId);

    // Verificar que el conductor existe
    const driverDoc = await driverRef.get();
    if (!driverDoc.exists || driverDoc.data()?.role !== 'driver') {
      res.status(404).json({
        success: false,
        error: {
          code: 'DRIVER_NOT_FOUND',
          message: 'Conductor no encontrado',
        },
        timestamp: new Date().toISOString(),
      });
      return;
    }

    const canReapplyDate = canReapply 
      ? new Date(Date.now() + reapplyAfterDays * 24 * 60 * 60 * 1000)
      : null;

    await driverRef.update({
      verified: false,
      verificationStatus: 'rejected',
      verificationRejectedAt: admin.firestore.FieldValue.serverTimestamp(),
      verificationRejectedBy: req.userId,
      rejectionReasons: reasons,
      canReapply,
      canReapplyAfter: canReapplyDate ? admin.firestore.Timestamp.fromDate(canReapplyDate) : null,
      status: 'pending_verification',
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    // Log de auditoría
    await db.collection('admin_actions').add({
      adminId: req.userId,
      action: 'DRIVER_VERIFICATION_REJECTED',
      targetUserId: driverId,
      rejectionReasons: reasons,
      canReapply,
      reapplyAfterDays,
      timestamp: admin.firestore.FieldValue.serverTimestamp(),
    });

    logger.info('Driver verification rejected', {
      driverId,
      adminId: req.userId,
      reasons,
      canReapply,
    });

    const response: ApiResponse = {
      success: true,
      data: { message: 'Verificación de conductor rechazada' },
      timestamp: new Date().toISOString(),
    };

    res.json(response);
  } catch (error: any) {
    logger.error('Error rejecting driver verification:', error);
    res.status(500).json({
      success: false,
      error: {
        code: 'REJECT_DRIVER_VERIFICATION_ERROR',
        message: 'Error rechazando verificación de conductor',
        details: process.env.NODE_ENV === 'development' ? error.message : undefined,
      },
      timestamp: new Date().toISOString(),
    });
  }
};

/**
 * Obtener historial de actividad del usuario
 */
export const getUserActivity = async (req: Request, res: Response): Promise<void> => {
  try {
    const { userId } = req.params;
    const { startDate, endDate, type = 'all' } = req.query as Record<string, string>;

    const db = admin.firestore();
    const activity: any[] = [];

    // Validar fechas
    const start = startDate ? new Date(startDate) : new Date(Date.now() - 30 * 24 * 60 * 60 * 1000);
    const end = endDate ? new Date(endDate) : new Date();

    // Obtener diferentes tipos de actividad según el filtro
    const promises = [];

    if (type === 'all' || type === 'rides') {
      promises.push(
        db.collection('rides')
          .where('passengerId', '==', userId)
          .where('createdAt', '>=', admin.firestore.Timestamp.fromDate(start))
          .where('createdAt', '<=', admin.firestore.Timestamp.fromDate(end))
          .orderBy('createdAt', 'desc')
          .get()
          .then(snap => snap.docs.map(doc => ({
            id: doc.id,
            type: 'ride_passenger',
            ...doc.data()
          }))),

        db.collection('rides')
          .where('driverId', '==', userId)
          .where('createdAt', '>=', admin.firestore.Timestamp.fromDate(start))
          .where('createdAt', '<=', admin.firestore.Timestamp.fromDate(end))
          .orderBy('createdAt', 'desc')
          .get()
          .then(snap => snap.docs.map(doc => ({
            id: doc.id,
            type: 'ride_driver',
            ...doc.data()
          })))
      );
    }

    if (type === 'all' || type === 'payments') {
      promises.push(
        db.collection('payments')
          .where('userId', '==', userId)
          .where('createdAt', '>=', admin.firestore.Timestamp.fromDate(start))
          .where('createdAt', '<=', admin.firestore.Timestamp.fromDate(end))
          .orderBy('createdAt', 'desc')
          .get()
          .then(snap => snap.docs.map(doc => ({
            id: doc.id,
            type: 'payment',
            ...doc.data()
          })))
      );
    }

    if (type === 'all' || type === 'support') {
      promises.push(
        db.collection('support_tickets')
          .where('userId', '==', userId)
          .where('createdAt', '>=', admin.firestore.Timestamp.fromDate(start))
          .where('createdAt', '<=', admin.firestore.Timestamp.fromDate(end))
          .orderBy('createdAt', 'desc')
          .get()
          .then(snap => snap.docs.map(doc => ({
            id: doc.id,
            type: 'support',
            ...doc.data()
          })))
      );
    }

    const results = await Promise.all(promises);
    
    // Combinar y ordenar todas las actividades
    const allActivity = results.flat()
      .sort((a: any, b: any) => {
        const aTime = a.createdAt?.toMillis ? a.createdAt.toMillis() : 0;
        const bTime = b.createdAt?.toMillis ? b.createdAt.toMillis() : 0;
        return bTime - aTime;
      });

    const response: ApiResponse = {
      success: true,
      data: {
        userId,
        activities: allActivity,
        period: { startDate: start, endDate: end },
        total: allActivity.length,
      },
      timestamp: new Date().toISOString(),
    };

    res.json(response);
  } catch (error: any) {
    logger.error('Error getting user activity:', error);
    res.status(500).json({
      success: false,
      error: {
        code: 'GET_USER_ACTIVITY_ERROR',
        message: 'Error obteniendo actividad del usuario',
        details: process.env.NODE_ENV === 'development' ? error.message : undefined,
      },
      timestamp: new Date().toISOString(),
    });
  }
};

/**
 * Obtener lista de administradores
 */
export const getAdmins = async (req: Request, res: Response): Promise<void> => {
  try {
    const { 
      status, 
      permissions, 
      page = '1', 
      limit = '20' 
    } = req.query as Record<string, string>;

    const db = admin.firestore();
    let query = db.collection('users').where('role', '==', 'admin') as any;

    // Filtros
    if (status) {
      query = query.where('status', '==', status);
    }

    // Paginación
    const pageNum = parseInt(page, 10);
    const limitNum = parseInt(limit, 10);
    const offset = (pageNum - 1) * limitNum;

    const snapshot = await query
      .orderBy('createdAt', 'desc')
      .limit(limitNum)
      .offset(offset)
      .get();

    const admins = snapshot.docs.map((doc: any) => {
      const data = doc.data();
      return {
        id: doc.id,
        firstName: data.firstName,
        lastName: data.lastName,
        email: data.email,
        status: data.status,
        permissions: data.permissions || [],
        createdAt: data.createdAt,
        lastActiveAt: data.lastActiveAt,
        createdBy: data.createdBy,
        verified: data.verified,
        // No devolver información sensible
        password: undefined,
        refreshTokens: undefined,
      };
    });

    // Contar total
    const totalSnapshot = await db.collection('users')
      .where('role', '==', 'admin')
      .count()
      .get();

    const response: ApiResponse = {
      success: true,
      data: {
        admins,
        pagination: {
          page: pageNum,
          limit: limitNum,
          total: totalSnapshot.data().count,
          totalPages: Math.ceil(totalSnapshot.data().count / limitNum),
        },
      },
      timestamp: new Date().toISOString(),
    };

    res.json(response);
  } catch (error: any) {
    logger.error('Error getting admins:', error);
    res.status(500).json({
      success: false,
      error: {
        code: 'GET_ADMINS_ERROR',
        message: 'Error obteniendo administradores',
        details: process.env.NODE_ENV === 'development' ? error.message : undefined,
      },
      timestamp: new Date().toISOString(),
    });
  }
};

/**
 * Crear nuevo administrador
 */
export const createAdmin = async (req: Request, res: Response): Promise<void> => {
  try {
    const {
      email,
      firstName,
      lastName,
      permissions = ['basic'],
      sendWelcomeEmail = true
    } = req.body;

    if (!email || !firstName || !lastName) {
      res.status(400).json({
        success: false,
        error: {
          code: 'MISSING_REQUIRED_FIELDS',
          message: 'Email, nombre y apellido son requeridos',
        },
        timestamp: new Date().toISOString(),
      });
      return;
    }

    const db = admin.firestore();

    // Verificar que el email no esté ya registrado
    const existingUser = await db.collection('users')
      .where('email', '==', email.toLowerCase())
      .limit(1)
      .get();

    if (!existingUser.empty) {
      res.status(409).json({
        success: false,
        error: {
          code: 'EMAIL_ALREADY_EXISTS',
          message: 'El email ya está registrado',
        },
        timestamp: new Date().toISOString(),
      });
      return;
    }

    // Generar contraseña temporal
    const temporaryPassword = Math.random().toString(36).slice(-12) + 'A1!';

    // Crear usuario en Firebase Auth
    const userRecord = await admin.auth().createUser({
      email: email.toLowerCase(),
      password: temporaryPassword,
      displayName: `${firstName} ${lastName}`,
      emailVerified: false,
    });

    // Crear perfil en Firestore
    const adminData = {
      email: email.toLowerCase(),
      firstName,
      lastName,
      role: 'admin',
      permissions,
      status: 'active',
      verified: true, // Los admins están verificados por defecto
      mustChangePassword: true,
      temporaryPassword, // En producción esto debería estar encriptado
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      createdBy: req.userId,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    };

    await db.collection('users').doc(userRecord.uid).set(adminData);

    // Log de auditoría
    await db.collection('admin_actions').add({
      adminId: req.userId,
      action: 'ADMIN_CREATED',
      targetUserId: userRecord.uid,
      adminEmail: email,
      permissions,
      timestamp: admin.firestore.FieldValue.serverTimestamp(),
    });

    logger.info('Admin created', {
      newAdminId: userRecord.uid,
      createdBy: req.userId,
      email,
      permissions,
    });

    const response: ApiResponse = {
      success: true,
      data: {
        adminId: userRecord.uid,
        email,
        temporaryPassword, // En producción enviar por email seguro
        message: 'Administrador creado exitosamente',
      },
      timestamp: new Date().toISOString(),
    };

    res.status(201).json(response);
  } catch (error: any) {
    logger.error('Error creating admin:', error);
    res.status(500).json({
      success: false,
      error: {
        code: 'CREATE_ADMIN_ERROR',
        message: 'Error creando administrador',
        details: process.env.NODE_ENV === 'development' ? error.message : undefined,
      },
      timestamp: new Date().toISOString(),
    });
  }
};

/**
 * Actualizar permisos de administrador
 */
export const updateAdminPermissions = async (req: Request, res: Response): Promise<void> => {
  try {
    const { adminId } = req.params;
    const { permissions, notes } = req.body;

    if (!permissions || !Array.isArray(permissions)) {
      res.status(400).json({
        success: false,
        error: {
          code: 'INVALID_PERMISSIONS',
          message: 'Permisos inválidos',
        },
        timestamp: new Date().toISOString(),
      });
      return;
    }

    const db = admin.firestore();
    const adminRef = db.collection('users').doc(adminId);

    // Verificar que es un administrador
    const adminDoc = await adminRef.get();
    if (!adminDoc.exists || adminDoc.data()?.role !== 'admin') {
      res.status(404).json({
        success: false,
        error: {
          code: 'ADMIN_NOT_FOUND',
          message: 'Administrador no encontrado',
        },
        timestamp: new Date().toISOString(),
      });
      return;
    }

    // Validar permisos permitidos
    const validPermissions = [
      'basic', 'user_management', 'driver_verification', 'financial_management',
      'system_configuration', 'analytics', 'support_management', 'super_admin'
    ];

    const invalidPermissions = permissions.filter((p: string) => !validPermissions.includes(p));
    if (invalidPermissions.length > 0) {
      res.status(400).json({
        success: false,
        error: {
          code: 'INVALID_PERMISSION_VALUES',
          message: `Permisos inválidos: ${invalidPermissions.join(', ')}`,
        },
        timestamp: new Date().toISOString(),
      });
      return;
    }

    const previousPermissions = adminDoc.data()?.permissions || [];

    await adminRef.update({
      permissions,
      permissionsUpdatedAt: admin.firestore.FieldValue.serverTimestamp(),
      permissionsUpdatedBy: req.userId,
      permissionNotes: notes,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    // Log de auditoría
    await db.collection('admin_actions').add({
      adminId: req.userId,
      action: 'ADMIN_PERMISSIONS_UPDATED',
      targetUserId: adminId,
      previousPermissions,
      newPermissions: permissions,
      notes,
      timestamp: admin.firestore.FieldValue.serverTimestamp(),
    });

    logger.info('Admin permissions updated', {
      targetAdminId: adminId,
      updatedBy: req.userId,
      previousPermissions,
      newPermissions: permissions,
    });

    const response: ApiResponse = {
      success: true,
      data: { message: 'Permisos actualizados correctamente' },
      timestamp: new Date().toISOString(),
    };

    res.json(response);
  } catch (error: any) {
    logger.error('Error updating admin permissions:', error);
    res.status(500).json({
      success: false,
      error: {
        code: 'UPDATE_ADMIN_PERMISSIONS_ERROR',
        message: 'Error actualizando permisos de administrador',
        details: process.env.NODE_ENV === 'development' ? error.message : undefined,
      },
      timestamp: new Date().toISOString(),
    });
  }
};

/**
 * Revocar acceso de administrador
 */
export const revokeAdminAccess = async (req: Request, res: Response): Promise<void> => {
  try {
    const { adminId } = req.params;
    const { reason, reassignRole = 'user' } = req.body;

    if (!reason) {
      res.status(400).json({
        success: false,
        error: {
          code: 'MISSING_REASON',
          message: 'Razón es requerida para revocar acceso',
        },
        timestamp: new Date().toISOString(),
      });
      return;
    }

    // No permitir auto-revocación
    if (adminId === req.userId) {
      res.status(403).json({
        success: false,
        error: {
          code: 'SELF_REVOCATION_NOT_ALLOWED',
          message: 'No puedes revocar tu propio acceso de administrador',
        },
        timestamp: new Date().toISOString(),
      });
      return;
    }

    const db = admin.firestore();
    const adminRef = db.collection('users').doc(adminId);

    // Verificar que es un administrador
    const adminDoc = await adminRef.get();
    if (!adminDoc.exists || adminDoc.data()?.role !== 'admin') {
      res.status(404).json({
        success: false,
        error: {
          code: 'ADMIN_NOT_FOUND',
          message: 'Administrador no encontrado',
        },
        timestamp: new Date().toISOString(),
      });
      return;
    }

    const previousRole = adminDoc.data()?.role;
    const previousPermissions = adminDoc.data()?.permissions || [];

    await adminRef.update({
      role: reassignRole,
      previousRole,
      permissions: [], // Limpiar permisos
      previousPermissions,
      accessRevokedAt: admin.firestore.FieldValue.serverTimestamp(),
      accessRevokedBy: req.userId,
      revocationReason: reason,
      status: 'active', // Mantener activo como usuario regular
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    // Log de auditoría
    await db.collection('admin_actions').add({
      adminId: req.userId,
      action: 'ADMIN_ACCESS_REVOKED',
      targetUserId: adminId,
      previousRole,
      newRole: reassignRole,
      previousPermissions,
      reason,
      timestamp: admin.firestore.FieldValue.serverTimestamp(),
    });

    logger.info('Admin access revoked', {
      targetAdminId: adminId,
      revokedBy: req.userId,
      reason,
      reassignedTo: reassignRole,
    });

    const response: ApiResponse = {
      success: true,
      data: { message: 'Acceso de administrador revocado correctamente' },
      timestamp: new Date().toISOString(),
    };

    res.json(response);
  } catch (error: any) {
    logger.error('Error revoking admin access:', error);
    res.status(500).json({
      success: false,
      error: {
        code: 'REVOKE_ADMIN_ACCESS_ERROR',
        message: 'Error revocando acceso de administrador',
        details: process.env.NODE_ENV === 'development' ? error.message : undefined,
      },
      timestamp: new Date().toISOString(),
    });
  }
};

/**
 * Obtener log de auditoría
 */
export const getAuditLog = async (req: Request, res: Response): Promise<void> => {
  try {
    const {
      adminId,
      action,
      targetUserId,
      startDate,
      endDate,
      page = '1',
      limit = '50'
    } = req.query as Record<string, string>;

    const db = admin.firestore();
    let query = db.collection('admin_actions') as any;

    // Filtros
    if (adminId) {
      query = query.where('adminId', '==', adminId);
    }
    if (action) {
      query = query.where('action', '==', action);
    }
    if (targetUserId) {
      query = query.where('targetUserId', '==', targetUserId);
    }
    if (startDate) {
      query = query.where('timestamp', '>=', admin.firestore.Timestamp.fromDate(new Date(startDate)));
    }
    if (endDate) {
      query = query.where('timestamp', '<=', admin.firestore.Timestamp.fromDate(new Date(endDate)));
    }

    // Ordenamiento y paginación
    const pageNum = parseInt(page, 10);
    const limitNum = parseInt(limit, 10);
    const offset = (pageNum - 1) * limitNum;

    const snapshot = await query
      .orderBy('timestamp', 'desc')
      .limit(limitNum)
      .offset(offset)
      .get();

    // Obtener información adicional de los administradores
    const adminIds = [...new Set(snapshot.docs.map((doc: any) => doc.data().adminId))];
    const adminsInfo = await Promise.all(
      adminIds.map(async (id) => {
        try {
          const adminDoc = await db.collection('users').doc(id as string).get();
          return {
            id,
            firstName: adminDoc.data()?.firstName,
            lastName: adminDoc.data()?.lastName,
            email: adminDoc.data()?.email,
          };
        } catch {
          return { id, firstName: 'Usuario', lastName: 'Eliminado', email: 'N/A' };
        }
      })
    );

    const adminMap = Object.fromEntries(adminsInfo.map(admin => [admin.id, admin]));

    const auditLogs = snapshot.docs.map((doc: any) => {
      const data = doc.data();
      const admin = adminMap[data.adminId] || { firstName: 'Usuario', lastName: 'Desconocido' };
      
      return {
        id: doc.id,
        action: data.action,
        adminId: data.adminId,
        adminName: `${admin.firstName} ${admin.lastName}`,
        adminEmail: admin.email,
        targetUserId: data.targetUserId,
        details: {
          reason: data.reason,
          previousRole: data.previousRole,
          newRole: data.newRole,
          permissions: data.permissions,
          previousPermissions: data.previousPermissions,
          newPermissions: data.newPermissions,
          // Agregar otros campos relevantes según la acción
          ...Object.fromEntries(
            Object.entries(data).filter(([key]) => 
              !['adminId', 'action', 'targetUserId', 'timestamp'].includes(key)
            )
          )
        },
        timestamp: data.timestamp,
      };
    });

    // Contar total (aproximado)
    const totalSnapshot = await db.collection('admin_actions').count().get();

    const response: ApiResponse = {
      success: true,
      data: {
        auditLogs,
        pagination: {
          page: pageNum,
          limit: limitNum,
          total: totalSnapshot.data().count,
          totalPages: Math.ceil(totalSnapshot.data().count / limitNum),
        },
        summary: {
          totalActions: totalSnapshot.data().count,
          uniqueAdmins: adminIds.length,
          period: {
            startDate: startDate || 'N/A',
            endDate: endDate || 'N/A',
          }
        }
      },
      timestamp: new Date().toISOString(),
    };

    res.json(response);
  } catch (error: any) {
    logger.error('Error getting audit log:', error);
    res.status(500).json({
      success: false,
      error: {
        code: 'GET_AUDIT_LOG_ERROR',
        message: 'Error obteniendo log de auditoría',
        details: process.env.NODE_ENV === 'development' ? error.message : undefined,
      },
      timestamp: new Date().toISOString(),
    });
  }
};
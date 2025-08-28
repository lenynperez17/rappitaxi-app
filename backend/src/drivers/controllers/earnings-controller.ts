import { Request, Response } from 'express';
import * as admin from 'firebase-admin';

// Obtener ganancias actuales del conductor
export const getEarnings = async (req: Request, res: Response): Promise<void> => {
  try {
    const driverId = req.user?.uid;
    if (!driverId) {
      res.status(401).json({
        success: false,
        error: { code: 'UNAUTHORIZED', message: 'Conductor no autenticado' }
      });
      return;
    }

    const { period = 'week' } = req.query; // today, week, month, year

    let startDate = new Date();
    const endDate = new Date();

    switch (period) {
      case 'today':
        startDate.setHours(0, 0, 0, 0);
        break;
      case 'week':
        startDate.setDate(startDate.getDate() - 7);
        break;
      case 'month':
        startDate.setMonth(startDate.getMonth() - 1);
        break;
      case 'year':
        startDate.setFullYear(startDate.getFullYear() - 1);
        break;
    }

    // Obtener viajes completados del período
    const ridesSnapshot = await admin.firestore()
      .collection('rides')
      .where('driverId', '==', driverId)
      .where('status', '==', 'completed')
      .where('completedAt', '>=', startDate)
      .where('completedAt', '<=', endDate)
      .get();

    let totalGrossEarnings = 0;
    let totalTips = 0;
    let totalCommission = 0;
    let totalBonuses = 0;
    let totalRides = ridesSnapshot.size;
    
    const rideDetails = [];

    ridesSnapshot.docs.forEach(doc => {
      const ride = doc.data();
      const grossAmount = ride.finalPrice || ride.estimatedPrice || 0;
      const tip = ride.tip || 0;
      const commission = grossAmount * 0.20; // 20% comisión por defecto
      const bonus = ride.bonus || 0;
      const netAmount = grossAmount - commission + tip + bonus;

      totalGrossEarnings += grossAmount;
      totalTips += tip;
      totalCommission += commission;
      totalBonuses += bonus;

      rideDetails.push({
        rideId: doc.id,
        date: ride.completedAt,
        origin: ride.pickup.address,
        destination: ride.destination.address,
        grossAmount: Math.round(grossAmount * 100) / 100,
        commission: Math.round(commission * 100) / 100,
        tip: Math.round(tip * 100) / 100,
        bonus: Math.round(bonus * 100) / 100,
        netAmount: Math.round(netAmount * 100) / 100
      });
    });

    const totalNetEarnings = totalGrossEarnings - totalCommission + totalTips + totalBonuses;
    
    // Obtener balance actual del conductor
    const driverDoc = await admin.firestore().collection('drivers').doc(driverId).get();
    const driverData = driverDoc.data();
    const availableBalance = driverData?.availableBalance || 0;
    const pendingBalance = driverData?.pendingBalance || 0;

    const earningsData = {
      period: period as string,
      summary: {
        totalRides,
        totalGrossEarnings: Math.round(totalGrossEarnings * 100) / 100,
        totalCommission: Math.round(totalCommission * 100) / 100,
        totalTips: Math.round(totalTips * 100) / 100,
        totalBonuses: Math.round(totalBonuses * 100) / 100,
        totalNetEarnings: Math.round(totalNetEarnings * 100) / 100,
        averageEarningsPerRide: totalRides > 0 ? 
          Math.round((totalNetEarnings / totalRides) * 100) / 100 : 0,
        commissionRate: '20%'
      },
      balance: {
        available: Math.round(availableBalance * 100) / 100,
        pending: Math.round(pendingBalance * 100) / 100,
        total: Math.round((availableBalance + pendingBalance) * 100) / 100
      },
      rides: rideDetails.sort((a, b) => 
        new Date(b.date).getTime() - new Date(a.date).getTime()
      )
    };

    res.status(200).json({
      success: true,
      data: earningsData,
      message: 'Ganancias obtenidas exitosamente'
    });
  } catch (error) {
    console.error('Error al obtener ganancias:', error);
    res.status(500).json({
      success: false,
      error: { code: 'INTERNAL_ERROR', message: 'Error interno del servidor' }
    });
  }
};

// Obtener historial de ganancias
export const getEarningsHistory = async (req: Request, res: Response): Promise<void> => {
  try {
    const driverId = req.user?.uid;
    if (!driverId) {
      res.status(401).json({
        success: false,
        error: { code: 'UNAUTHORIZED', message: 'Conductor no autenticado' }
      });
      return;
    }

    const { page = 1, limit = 20, startDate, endDate } = req.query;
    const pageNum = parseInt(page as string);
    const limitNum = parseInt(limit as string);
    const offset = (pageNum - 1) * limitNum;

    let query = admin.firestore()
      .collection('rides')
      .where('driverId', '==', driverId)
      .where('status', '==', 'completed')
      .orderBy('completedAt', 'desc');

    if (startDate) {
      query = query.where('completedAt', '>=', new Date(startDate as string));
    }
    if (endDate) {
      query = query.where('completedAt', '<=', new Date(endDate as string));
    }

    const ridesSnapshot = await query.limit(limitNum).offset(offset).get();
    const totalSnapshot = await query.get(); // Para contar total

    const earnings = ridesSnapshot.docs.map(doc => {
      const ride = doc.data();
      const grossAmount = ride.finalPrice || ride.estimatedPrice || 0;
      const tip = ride.tip || 0;
      const commission = grossAmount * 0.20;
      const bonus = ride.bonus || 0;
      const netAmount = grossAmount - commission + tip + bonus;

      return {
        rideId: doc.id,
        date: ride.completedAt,
        passengerName: `${ride.passengerFirstName || ''} ${ride.passengerLastName || ''}`.trim(),
        origin: ride.pickup.address,
        destination: ride.destination.address,
        distance: ride.distance || 0,
        duration: ride.duration || 0,
        grossAmount: Math.round(grossAmount * 100) / 100,
        commission: Math.round(commission * 100) / 100,
        tip: Math.round(tip * 100) / 100,
        bonus: Math.round(bonus * 100) / 100,
        netAmount: Math.round(netAmount * 100) / 100,
        paymentMethod: ride.paymentMethod,
        rating: ride.driverRating
      };
    });

    res.status(200).json({
      success: true,
      data: {
        earnings,
        pagination: {
          currentPage: pageNum,
          totalPages: Math.ceil(totalSnapshot.size / limitNum),
          totalItems: totalSnapshot.size,
          itemsPerPage: limitNum,
          hasNextPage: pageNum * limitNum < totalSnapshot.size,
          hasPrevPage: pageNum > 1
        }
      },
      message: 'Historial de ganancias obtenido exitosamente'
    });
  } catch (error) {
    console.error('Error al obtener historial de ganancias:', error);
    res.status(500).json({
      success: false,
      error: { code: 'INTERNAL_ERROR', message: 'Error interno del servidor' }
    });
  }
};

// Obtener ganancias semanales
export const getWeeklyEarnings = async (req: Request, res: Response): Promise<void> => {
  try {
    const driverId = req.user?.uid;
    if (!driverId) {
      res.status(401).json({
        success: false,
        error: { code: 'UNAUTHORIZED', message: 'Conductor no autenticado' }
      });
      return;
    }

    const { weeks = 4 } = req.query; // Número de semanas hacia atrás
    const weeksNum = parseInt(weeks as string);
    
    const weeklyData = [];
    
    for (let i = 0; i < weeksNum; i++) {
      const endDate = new Date();
      endDate.setDate(endDate.getDate() - (i * 7));
      endDate.setHours(23, 59, 59, 999);
      
      const startDate = new Date(endDate);
      startDate.setDate(startDate.getDate() - 6);
      startDate.setHours(0, 0, 0, 0);

      const ridesSnapshot = await admin.firestore()
        .collection('rides')
        .where('driverId', '==', driverId)
        .where('status', '==', 'completed')
        .where('completedAt', '>=', startDate)
        .where('completedAt', '<=', endDate)
        .get();

      let grossEarnings = 0;
      let tips = 0;
      let bonuses = 0;

      ridesSnapshot.docs.forEach(doc => {
        const ride = doc.data();
        grossEarnings += ride.finalPrice || ride.estimatedPrice || 0;
        tips += ride.tip || 0;
        bonuses += ride.bonus || 0;
      });

      const commission = grossEarnings * 0.20;
      const netEarnings = grossEarnings - commission + tips + bonuses;

      weeklyData.push({
        weekNumber: weeksNum - i,
        startDate: startDate.toISOString(),
        endDate: endDate.toISOString(),
        totalRides: ridesSnapshot.size,
        grossEarnings: Math.round(grossEarnings * 100) / 100,
        commission: Math.round(commission * 100) / 100,
        tips: Math.round(tips * 100) / 100,
        bonuses: Math.round(bonuses * 100) / 100,
        netEarnings: Math.round(netEarnings * 100) / 100,
        averagePerRide: ridesSnapshot.size > 0 ? 
          Math.round((netEarnings / ridesSnapshot.size) * 100) / 100 : 0
      });
    }

    // Calcular totales
    const totals = weeklyData.reduce((acc, week) => ({
      totalRides: acc.totalRides + week.totalRides,
      totalGrossEarnings: acc.totalGrossEarnings + week.grossEarnings,
      totalCommission: acc.totalCommission + week.commission,
      totalTips: acc.totalTips + week.tips,
      totalBonuses: acc.totalBonuses + week.bonuses,
      totalNetEarnings: acc.totalNetEarnings + week.netEarnings
    }), {
      totalRides: 0,
      totalGrossEarnings: 0,
      totalCommission: 0,
      totalTips: 0,
      totalBonuses: 0,
      totalNetEarnings: 0
    });

    res.status(200).json({
      success: true,
      data: {
        weekly: weeklyData.reverse(), // Orden cronológico
        summary: {
          ...totals,
          averageWeeklyEarnings: weeksNum > 0 ? 
            Math.round((totals.totalNetEarnings / weeksNum) * 100) / 100 : 0,
          averageRidesPerWeek: weeksNum > 0 ? 
            Math.round(totals.totalRides / weeksNum) : 0
        }
      },
      message: 'Ganancias semanales obtenidas exitosamente'
    });
  } catch (error) {
    console.error('Error al obtener ganancias semanales:', error);
    res.status(500).json({
      success: false,
      error: { code: 'INTERNAL_ERROR', message: 'Error interno del servidor' }
    });
  }
};

// Obtener ganancias mensuales
export const getMonthlyEarnings = async (req: Request, res: Response): Promise<void> => {
  try {
    const driverId = req.user?.uid;
    if (!driverId) {
      res.status(401).json({
        success: false,
        error: { code: 'UNAUTHORIZED', message: 'Conductor no autenticado' }
      });
      return;
    }

    const { months = 6 } = req.query; // Número de meses hacia atrás
    const monthsNum = parseInt(months as string);
    
    const monthlyData = [];
    
    for (let i = 0; i < monthsNum; i++) {
      const endDate = new Date();
      endDate.setMonth(endDate.getMonth() - i);
      endDate.setDate(0); // Último día del mes
      endDate.setHours(23, 59, 59, 999);
      
      const startDate = new Date(endDate);
      startDate.setDate(1); // Primer día del mes
      startDate.setHours(0, 0, 0, 0);

      const ridesSnapshot = await admin.firestore()
        .collection('rides')
        .where('driverId', '==', driverId)
        .where('status', '==', 'completed')
        .where('completedAt', '>=', startDate)
        .where('completedAt', '<=', endDate)
        .get();

      let grossEarnings = 0;
      let tips = 0;
      let bonuses = 0;

      ridesSnapshot.docs.forEach(doc => {
        const ride = doc.data();
        grossEarnings += ride.finalPrice || ride.estimatedPrice || 0;
        tips += ride.tip || 0;
        bonuses += ride.bonus || 0;
      });

      const commission = grossEarnings * 0.20;
      const netEarnings = grossEarnings - commission + tips + bonuses;

      monthlyData.push({
        month: startDate.toISOString().substring(0, 7), // YYYY-MM
        monthName: startDate.toLocaleDateString('es-ES', { month: 'long', year: 'numeric' }),
        startDate: startDate.toISOString(),
        endDate: endDate.toISOString(),
        totalRides: ridesSnapshot.size,
        grossEarnings: Math.round(grossEarnings * 100) / 100,
        commission: Math.round(commission * 100) / 100,
        tips: Math.round(tips * 100) / 100,
        bonuses: Math.round(bonuses * 100) / 100,
        netEarnings: Math.round(netEarnings * 100) / 100,
        averagePerRide: ridesSnapshot.size > 0 ? 
          Math.round((netEarnings / ridesSnapshot.size) * 100) / 100 : 0,
        averagePerDay: Math.round((netEarnings / endDate.getDate()) * 100) / 100
      });
    }

    // Calcular totales
    const totals = monthlyData.reduce((acc, month) => ({
      totalRides: acc.totalRides + month.totalRides,
      totalGrossEarnings: acc.totalGrossEarnings + month.grossEarnings,
      totalCommission: acc.totalCommission + month.commission,
      totalTips: acc.totalTips + month.tips,
      totalBonuses: acc.totalBonuses + month.bonuses,
      totalNetEarnings: acc.totalNetEarnings + month.netEarnings
    }), {
      totalRides: 0,
      totalGrossEarnings: 0,
      totalCommission: 0,
      totalTips: 0,
      totalBonuses: 0,
      totalNetEarnings: 0
    });

    res.status(200).json({
      success: true,
      data: {
        monthly: monthlyData.reverse(), // Orden cronológico
        summary: {
          ...totals,
          averageMonthlyEarnings: monthsNum > 0 ? 
            Math.round((totals.totalNetEarnings / monthsNum) * 100) / 100 : 0,
          averageRidesPerMonth: monthsNum > 0 ? 
            Math.round(totals.totalRides / monthsNum) : 0
        }
      },
      message: 'Ganancias mensuales obtenidas exitosamente'
    });
  } catch (error) {
    console.error('Error al obtener ganancias mensuales:', error);
    res.status(500).json({
      success: false,
      error: { code: 'INTERNAL_ERROR', message: 'Error interno del servidor' }
    });
  }
};

// Solicitar retiro de ganancias
export const requestWithdrawal = async (req: Request, res: Response): Promise<void> => {
  try {
    const driverId = req.user?.uid;
    if (!driverId) {
      res.status(401).json({
        success: false,
        error: { code: 'UNAUTHORIZED', message: 'Conductor no autenticado' }
      });
      return;
    }

    const { amount, method = 'mercadopago', accountDetails } = req.body;

    if (!amount || amount <= 0) {
      res.status(400).json({
        success: false,
        error: { code: 'INVALID_AMOUNT', message: 'Monto inválido' }
      });
      return;
    }

    if (!accountDetails) {
      res.status(400).json({
        success: false,
        error: { code: 'MISSING_ACCOUNT_DETAILS', message: 'Detalles de cuenta requeridos' }
      });
      return;
    }

    // Verificar balance disponible
    const driverDoc = await admin.firestore().collection('drivers').doc(driverId).get();
    if (!driverDoc.exists) {
      res.status(404).json({
        success: false,
        error: { code: 'DRIVER_NOT_FOUND', message: 'Conductor no encontrado' }
      });
      return;
    }

    const driverData = driverDoc.data();
    const availableBalance = driverData?.availableBalance || 0;

    if (amount > availableBalance) {
      res.status(400).json({
        success: false,
        error: { 
          code: 'INSUFFICIENT_BALANCE', 
          message: `Balance insuficiente. Disponible: S/ ${availableBalance}` 
        }
      });
      return;
    }

    // Verificar límites de retiro
    const minWithdrawal = 10.00; // Mínimo S/ 10
    const maxWithdrawal = 5000.00; // Máximo S/ 5000

    if (amount < minWithdrawal) {
      res.status(400).json({
        success: false,
        error: { 
          code: 'AMOUNT_TOO_LOW', 
          message: `Monto mínimo de retiro: S/ ${minWithdrawal}` 
        }
      });
      return;
    }

    if (amount > maxWithdrawal) {
      res.status(400).json({
        success: false,
        error: { 
          code: 'AMOUNT_TOO_HIGH', 
          message: `Monto máximo de retiro: S/ ${maxWithdrawal}` 
        }
      });
      return;
    }

    // Crear solicitud de retiro
    const withdrawalData = {
      driverId,
      amount: parseFloat(amount.toString()),
      method,
      accountDetails,
      status: 'pending', // pending, processing, completed, failed
      requestedAt: admin.firestore.FieldValue.serverTimestamp(),
      processingFee: Math.round(amount * 0.02 * 100) / 100, // 2% fee
      netAmount: Math.round((amount * 0.98) * 100) / 100,
      estimatedArrival: new Date(Date.now() + 24 * 60 * 60 * 1000), // 24 horas
      transactionId: `WD_${driverId}_${Date.now()}`
    };

    const withdrawalRef = await admin.firestore()
      .collection('withdrawals')
      .add(withdrawalData);

    // Actualizar balance del conductor
    await admin.firestore().collection('drivers').doc(driverId).update({
      availableBalance: admin.firestore.FieldValue.increment(-amount),
      pendingWithdrawals: admin.firestore.FieldValue.increment(amount),
      lastWithdrawalAt: admin.firestore.FieldValue.serverTimestamp()
    });

    res.status(201).json({
      success: true,
      data: {
        withdrawalId: withdrawalRef.id,
        transactionId: withdrawalData.transactionId,
        amount: withdrawalData.amount,
        processingFee: withdrawalData.processingFee,
        netAmount: withdrawalData.netAmount,
        method: withdrawalData.method,
        status: withdrawalData.status,
        estimatedArrival: withdrawalData.estimatedArrival
      },
      message: 'Solicitud de retiro creada exitosamente'
    });
  } catch (error) {
    console.error('Error al solicitar retiro:', error);
    res.status(500).json({
      success: false,
      error: { code: 'INTERNAL_ERROR', message: 'Error interno del servidor' }
    });
  }
};

// Obtener historial de retiros
export const getWithdrawalsHistory = async (req: Request, res: Response): Promise<void> => {
  try {
    const driverId = req.user?.uid;
    if (!driverId) {
      res.status(401).json({
        success: false,
        error: { code: 'UNAUTHORIZED', message: 'Conductor no autenticado' }
      });
      return;
    }

    const { page = 1, limit = 10, status } = req.query;
    const pageNum = parseInt(page as string);
    const limitNum = parseInt(limit as string);

    let query = admin.firestore()
      .collection('withdrawals')
      .where('driverId', '==', driverId)
      .orderBy('requestedAt', 'desc');

    if (status) {
      query = query.where('status', '==', status);
    }

    const withdrawalsSnapshot = await query.limit(limitNum).offset((pageNum - 1) * limitNum).get();

    const withdrawals = withdrawalsSnapshot.docs.map(doc => {
      const withdrawal = doc.data();
      return {
        id: doc.id,
        transactionId: withdrawal.transactionId,
        amount: withdrawal.amount,
        processingFee: withdrawal.processingFee,
        netAmount: withdrawal.netAmount,
        method: withdrawal.method,
        status: withdrawal.status,
        requestedAt: withdrawal.requestedAt,
        completedAt: withdrawal.completedAt,
        estimatedArrival: withdrawal.estimatedArrival,
        accountDetails: withdrawal.accountDetails
      };
    });

    res.status(200).json({
      success: true,
      data: {
        withdrawals,
        pagination: {
          currentPage: pageNum,
          itemsPerPage: limitNum,
          hasNextPage: withdrawalsSnapshot.size === limitNum
        }
      },
      message: 'Historial de retiros obtenido exitosamente'
    });
  } catch (error) {
    console.error('Error al obtener historial de retiros:', error);
    res.status(500).json({
      success: false,
      error: { code: 'INTERNAL_ERROR', message: 'Error interno del servidor' }
    });
  }
};

// Obtener resumen financiero del conductor
export const getFinancialSummary = async (req: Request, res: Response): Promise<void> => {
  try {
    const driverId = req.user?.uid;
    if (!driverId) {
      res.status(401).json({
        success: false,
        error: { code: 'UNAUTHORIZED', message: 'Conductor no autenticado' }
      });
      return;
    }

    // Obtener información del conductor
    const driverDoc = await admin.firestore().collection('drivers').doc(driverId).get();
    const driverData = driverDoc.data();

    // Obtener ganancias del mes actual
    const currentMonth = new Date();
    const startOfMonth = new Date(currentMonth.getFullYear(), currentMonth.getMonth(), 1);
    
    const monthlyRides = await admin.firestore()
      .collection('rides')
      .where('driverId', '==', driverId)
      .where('status', '==', 'completed')
      .where('completedAt', '>=', startOfMonth)
      .get();

    let monthlyGross = 0;
    let monthlyTips = 0;
    monthlyRides.docs.forEach(doc => {
      const ride = doc.data();
      monthlyGross += ride.finalPrice || ride.estimatedPrice || 0;
      monthlyTips += ride.tip || 0;
    });

    const monthlyCommission = monthlyGross * 0.20;
    const monthlyNet = monthlyGross - monthlyCommission + monthlyTips;

    // Obtener retiros pendientes
    const pendingWithdrawals = await admin.firestore()
      .collection('withdrawals')
      .where('driverId', '==', driverId)
      .where('status', 'in', ['pending', 'processing'])
      .get();

    const pendingAmount = pendingWithdrawals.docs.reduce((total, doc) => {
      return total + (doc.data().amount || 0);
    }, 0);

    const summary = {
      balance: {
        available: driverData?.availableBalance || 0,
        pending: driverData?.pendingBalance || 0,
        pendingWithdrawals: Math.round(pendingAmount * 100) / 100
      },
      thisMonth: {
        totalRides: monthlyRides.size,
        grossEarnings: Math.round(monthlyGross * 100) / 100,
        commission: Math.round(monthlyCommission * 100) / 100,
        tips: Math.round(monthlyTips * 100) / 100,
        netEarnings: Math.round(monthlyNet * 100) / 100,
        averagePerRide: monthlyRides.size > 0 ? 
          Math.round((monthlyNet / monthlyRides.size) * 100) / 100 : 0
      },
      settings: {
        commissionRate: '20%',
        withdrawalFee: '2%',
        minWithdrawal: 10.00,
        maxWithdrawal: 5000.00
      }
    };

    res.status(200).json({
      success: true,
      data: summary,
      message: 'Resumen financiero obtenido exitosamente'
    });
  } catch (error) {
    console.error('Error al obtener resumen financiero:', error);
    res.status(500).json({
      success: false,
      error: { code: 'INTERNAL_ERROR', message: 'Error interno del servidor' }
    });
  }
};
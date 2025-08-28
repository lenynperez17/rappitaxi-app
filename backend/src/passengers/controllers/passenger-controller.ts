import { Request, Response } from 'express';
import * as admin from 'firebase-admin';

// =========================================
// PERFIL DE PASAJERO
// =========================================

export const getProfile = async (req: Request, res: Response): Promise<void> => {
  try {
    const userId = req.user?.uid;
    if (!userId) {
      res.status(401).json({ success: false, error: { code: 'UNAUTHORIZED', message: 'Usuario no autenticado' }});
      return;
    }

    const userDoc = await admin.firestore().collection('users').doc(userId).get();
    if (!userDoc.exists) {
      res.status(404).json({ success: false, error: { code: 'USER_NOT_FOUND', message: 'Usuario no encontrado' }});
      return;
    }

    const userData = userDoc.data();
    res.status(200).json({
      success: true,
      data: {
        id: userId,
        firstName: userData?.firstName || '',
        lastName: userData?.lastName || '',
        email: userData?.email || '',
        phone: userData?.phoneNumber || '',
        profileImage: userData?.profileImage || '',
        rating: userData?.rating || 0,
        totalRides: userData?.totalRides || 0,
        memberSince: userData?.createdAt
      },
      message: 'Perfil obtenido exitosamente'
    });
  } catch (error) {
    res.status(500).json({ success: false, error: { code: 'INTERNAL_ERROR', message: error.message }});
  }
};

export const updateProfile = async (req: Request, res: Response): Promise<void> => {
  try {
    const userId = req.user?.uid;
    if (!userId) {
      res.status(401).json({ success: false, error: { code: 'UNAUTHORIZED', message: 'Usuario no autenticado' }});
      return;
    }

    const { firstName, lastName, phone, profileImage } = req.body;
    
    const updateData = {
      ...(firstName && { firstName }),
      ...(lastName && { lastName }),
      ...(phone && { phoneNumber: phone }),
      ...(profileImage && { profileImage }),
      updatedAt: admin.firestore.FieldValue.serverTimestamp()
    };

    await admin.firestore().collection('users').doc(userId).update(updateData);

    res.status(200).json({
      success: true,
      data: { id: userId, ...updateData },
      message: 'Perfil actualizado exitosamente'
    });
  } catch (error) {
    res.status(500).json({ success: false, error: { code: 'INTERNAL_ERROR', message: error.message }});
  }
};

export const deleteAccount = async (req: Request, res: Response): Promise<void> => {
  try {
    const userId = req.user?.uid;
    if (!userId) {
      res.status(401).json({ success: false, error: { code: 'UNAUTHORIZED', message: 'Usuario no autenticado' }});
      return;
    }

    // Marcar cuenta como inactiva en lugar de eliminar completamente
    await admin.firestore().collection('users').doc(userId).update({
      isActive: false,
      deletedAt: admin.firestore.FieldValue.serverTimestamp()
    });

    res.status(200).json({
      success: true,
      message: 'Cuenta eliminada exitosamente'
    });
  } catch (error) {
    res.status(500).json({ success: false, error: { code: 'INTERNAL_ERROR', message: error.message }});
  }
};

// =========================================
// PROMOCIONES Y CUPONES
// =========================================

export const getPromotions = async (req: Request, res: Response): Promise<void> => {
  try {
    const userId = req.user?.uid;
    if (!userId) {
      res.status(401).json({ success: false, error: { code: 'UNAUTHORIZED', message: 'Usuario no autenticado' }});
      return;
    }

    // Promociones mock realistas
    const promotions = [
      {
        id: 'promo_001',
        title: 'Primera vez',
        description: 'Descuento de S/ 10 en tu primer viaje',
        discount: 10,
        type: 'fixed',
        validUntil: new Date(Date.now() + 30 * 24 * 60 * 60 * 1000),
        isActive: true
      },
      {
        id: 'promo_002', 
        title: 'Viernes de descuento',
        description: '20% de descuento todos los viernes',
        discount: 20,
        type: 'percentage',
        validUntil: new Date(Date.now() + 7 * 24 * 60 * 60 * 1000),
        isActive: true
      }
    ];

    res.status(200).json({
      success: true,
      data: promotions,
      message: 'Promociones obtenidas exitosamente'
    });
  } catch (error) {
    res.status(500).json({ success: false, error: { code: 'INTERNAL_ERROR', message: error.message }});
  }
};

export const applyCoupon = async (req: Request, res: Response): Promise<void> => {
  try {
    const userId = req.user?.uid;
    const { couponCode } = req.body;

    if (!userId) {
      res.status(401).json({ success: false, error: { code: 'UNAUTHORIZED', message: 'Usuario no autenticado' }});
      return;
    }

    if (!couponCode) {
      res.status(400).json({ success: false, error: { code: 'INVALID_INPUT', message: 'Código de cupón requerido' }});
      return;
    }

    // Simulación de validación de cupón
    const validCoupons = ['RAPPI10', 'PRIMERA_VEZ', 'VIERNES20'];
    
    if (!validCoupons.includes(couponCode.toUpperCase())) {
      res.status(404).json({ success: false, error: { code: 'INVALID_COUPON', message: 'Cupón no válido o expirado' }});
      return;
    }

    const discountValue = couponCode.includes('20') ? 20 : 10;
    
    res.status(200).json({
      success: true,
      data: {
        couponCode,
        discount: discountValue,
        type: couponCode.includes('20') ? 'percentage' : 'fixed',
        appliedAt: new Date()
      },
      message: 'Cupón aplicado exitosamente'
    });
  } catch (error) {
    res.status(500).json({ success: false, error: { code: 'INTERNAL_ERROR', message: error.message }});
  }
};

export const getActiveCoupons = async (req: Request, res: Response): Promise<void> => {
  try {
    const userId = req.user?.uid;
    if (!userId) {
      res.status(401).json({ success: false, error: { code: 'UNAUTHORIZED', message: 'Usuario no autenticado' }});
      return;
    }

    const activeCoupons = [
      {
        id: 'coupon_001',
        code: 'RAPPI10',
        description: 'S/ 10 de descuento',
        discount: 10,
        type: 'fixed',
        validUntil: new Date(Date.now() + 15 * 24 * 60 * 60 * 1000),
        isUsed: false
      },
      {
        id: 'coupon_002',
        code: 'VIERNES20',
        description: '20% de descuento',
        discount: 20,
        type: 'percentage',
        validUntil: new Date(Date.now() + 7 * 24 * 60 * 60 * 1000),
        isUsed: false
      }
    ];

    res.status(200).json({
      success: true,
      data: activeCoupons,
      message: 'Cupones activos obtenidos exitosamente'
    });
  } catch (error) {
    res.status(500).json({ success: false, error: { code: 'INTERNAL_ERROR', message: error.message }});
  }
};

// =========================================
// SISTEMA DE REFERIDOS
// =========================================

export const getReferralCode = async (req: Request, res: Response): Promise<void> => {
  try {
    const userId = req.user?.uid;
    if (!userId) {
      res.status(401).json({ success: false, error: { code: 'UNAUTHORIZED', message: 'Usuario no autenticado' }});
      return;
    }

    // Generar código de referido único
    const referralCode = `RAPPI${userId.substr(0, 8).toUpperCase()}`;

    res.status(200).json({
      success: true,
      data: {
        referralCode,
        shareUrl: `https://rappitaxi.com/ref/${referralCode}`,
        reward: 15, // Soles por referido exitoso
        description: 'Invita a tus amigos y gana S/ 15 por cada registro exitoso'
      },
      message: 'Código de referido obtenido exitosamente'
    });
  } catch (error) {
    res.status(500).json({ success: false, error: { code: 'INTERNAL_ERROR', message: error.message }});
  }
};

export const getReferralStats = async (req: Request, res: Response): Promise<void> => {
  try {
    const userId = req.user?.uid;
    if (!userId) {
      res.status(401).json({ success: false, error: { code: 'UNAUTHORIZED', message: 'Usuario no autenticado' }});
      return;
    }

    // Stats mock realistas
    const stats = {
      totalReferrals: 3,
      successfulReferrals: 2,
      pendingReferrals: 1,
      totalEarned: 30, // 2 * 15 soles
      currentMonthReferrals: 1,
      referralHistory: [
        {
          id: 'ref_001',
          referredUser: 'Ana García',
          status: 'completed',
          earnedAmount: 15,
          completedAt: new Date(Date.now() - 5 * 24 * 60 * 60 * 1000)
        },
        {
          id: 'ref_002',
          referredUser: 'Carlos López', 
          status: 'completed',
          earnedAmount: 15,
          completedAt: new Date(Date.now() - 10 * 24 * 60 * 60 * 1000)
        },
        {
          id: 'ref_003',
          referredUser: 'María Torres',
          status: 'pending',
          earnedAmount: 0,
          createdAt: new Date(Date.now() - 2 * 24 * 60 * 60 * 1000)
        }
      ]
    };

    res.status(200).json({
      success: true,
      data: stats,
      message: 'Estadísticas de referidos obtenidas exitosamente'
    });
  } catch (error) {
    res.status(500).json({ success: false, error: { code: 'INTERNAL_ERROR', message: error.message }});
  }
};

export const inviteFriends = async (req: Request, res: Response): Promise<void> => {
  try {
    const userId = req.user?.uid;
    const { contacts, method } = req.body; // contacts: string[], method: 'sms' | 'email' | 'whatsapp'

    if (!userId) {
      res.status(401).json({ success: false, error: { code: 'UNAUTHORIZED', message: 'Usuario no autenticado' }});
      return;
    }

    if (!contacts || !Array.isArray(contacts) || contacts.length === 0) {
      res.status(400).json({ success: false, error: { code: 'INVALID_INPUT', message: 'Lista de contactos requerida' }});
      return;
    }

    const referralCode = `RAPPI${userId.substr(0, 8).toUpperCase()}`;
    const shareUrl = `https://rappitaxi.com/ref/${referralCode}`;
    
    // Simular envío de invitaciones
    const invitations = contacts.map((contact: string, index: number) => ({
      id: `inv_${Date.now()}_${index}`,
      contact,
      method: method || 'sms',
      referralCode,
      shareUrl,
      sentAt: new Date(),
      status: 'sent'
    }));

    res.status(200).json({
      success: true,
      data: {
        invitationsSent: contacts.length,
        invitations,
        referralCode
      },
      message: `${contacts.length} invitaciones enviadas exitosamente`
    });
  } catch (error) {
    res.status(500).json({ success: false, error: { code: 'INTERNAL_ERROR', message: error.message }});
  }
};

// =========================================
// SOPORTE AL CLIENTE
// =========================================

export const createSupportTicket = async (req: Request, res: Response): Promise<void> => {
  try {
    const userId = req.user?.uid;
    const { subject, category, description, priority, rideId } = req.body;

    if (!userId) {
      res.status(401).json({ success: false, error: { code: 'UNAUTHORIZED', message: 'Usuario no autenticado' }});
      return;
    }

    if (!subject || !category || !description) {
      res.status(400).json({ success: false, error: { code: 'INVALID_INPUT', message: 'Campos obligatorios: subject, category, description' }});
      return;
    }

    const ticketId = `ticket_${Date.now()}`;
    const ticket = {
      id: ticketId,
      userId,
      subject,
      category,
      description,
      priority: priority || 'medium',
      status: 'open',
      rideId: rideId || null,
      createdAt: new Date(),
      messages: [
        {
          id: `msg_${Date.now()}`,
          sender: 'user',
          message: description,
          timestamp: new Date()
        }
      ]
    };

    // Guardar en Firestore
    await admin.firestore().collection('support_tickets').doc(ticketId).set(ticket);

    res.status(201).json({
      success: true,
      data: ticket,
      message: 'Ticket de soporte creado exitosamente'
    });
  } catch (error) {
    res.status(500).json({ success: false, error: { code: 'INTERNAL_ERROR', message: error.message }});
  }
};

export const getSupportTickets = async (req: Request, res: Response): Promise<void> => {
  try {
    const userId = req.user?.uid;
    const { page = 1, limit = 10, status } = req.query;

    if (!userId) {
      res.status(401).json({ success: false, error: { code: 'UNAUTHORIZED', message: 'Usuario no autenticado' }});
      return;
    }

    let query = admin.firestore().collection('support_tickets')
      .where('userId', '==', userId)
      .orderBy('createdAt', 'desc');

    if (status) {
      query = query.where('status', '==', status);
    }

    const snapshot = await query.limit(Number(limit)).get();
    const tickets = snapshot.docs.map(doc => ({ id: doc.id, ...doc.data() }));

    res.status(200).json({
      success: true,
      data: {
        tickets,
        pagination: {
          page: Number(page),
          limit: Number(limit),
          total: tickets.length
        }
      },
      message: 'Tickets de soporte obtenidos exitosamente'
    });
  } catch (error) {
    res.status(500).json({ success: false, error: { code: 'INTERNAL_ERROR', message: error.message }});
  }
};

export const getTicketDetails = async (req: Request, res: Response): Promise<void> => {
  try {
    const userId = req.user?.uid;
    const { ticketId } = req.params;

    if (!userId) {
      res.status(401).json({ success: false, error: { code: 'UNAUTHORIZED', message: 'Usuario no autenticado' }});
      return;
    }

    const ticketDoc = await admin.firestore().collection('support_tickets').doc(ticketId).get();
    
    if (!ticketDoc.exists) {
      res.status(404).json({ success: false, error: { code: 'TICKET_NOT_FOUND', message: 'Ticket no encontrado' }});
      return;
    }

    const ticketData = ticketDoc.data();
    
    if (ticketData?.userId !== userId) {
      res.status(403).json({ success: false, error: { code: 'FORBIDDEN', message: 'No tienes permiso para ver este ticket' }});
      return;
    }

    res.status(200).json({
      success: true,
      data: { id: ticketId, ...ticketData },
      message: 'Detalles del ticket obtenidos exitosamente'
    });
  } catch (error) {
    res.status(500).json({ success: false, error: { code: 'INTERNAL_ERROR', message: error.message }});
  }
};

export const replyToTicket = async (req: Request, res: Response): Promise<void> => {
  try {
    const userId = req.user?.uid;
    const { ticketId } = req.params;
    const { message } = req.body;

    if (!userId) {
      res.status(401).json({ success: false, error: { code: 'UNAUTHORIZED', message: 'Usuario no autenticado' }});
      return;
    }

    if (!message) {
      res.status(400).json({ success: false, error: { code: 'INVALID_INPUT', message: 'Mensaje requerido' }});
      return;
    }

    const newMessage = {
      id: `msg_${Date.now()}`,
      sender: 'user',
      message,
      timestamp: new Date()
    };

    await admin.firestore().collection('support_tickets').doc(ticketId).update({
      messages: admin.firestore.FieldValue.arrayUnion(newMessage),
      status: 'awaiting_response',
      updatedAt: admin.firestore.FieldValue.serverTimestamp()
    });

    res.status(200).json({
      success: true,
      data: newMessage,
      message: 'Respuesta enviada exitosamente'
    });
  } catch (error) {
    res.status(500).json({ success: false, error: { code: 'INTERNAL_ERROR', message: error.message }});
  }
};

export const rateSupportTicket = async (req: Request, res: Response): Promise<void> => {
  try {
    const userId = req.user?.uid;
    const { ticketId } = req.params;
    const { rating, feedback } = req.body;

    if (!userId) {
      res.status(401).json({ success: false, error: { code: 'UNAUTHORIZED', message: 'Usuario no autenticado' }});
      return;
    }

    if (!rating || rating < 1 || rating > 5) {
      res.status(400).json({ success: false, error: { code: 'INVALID_INPUT', message: 'Rating debe ser entre 1 y 5' }});
      return;
    }

    await admin.firestore().collection('support_tickets').doc(ticketId).update({
      rating,
      feedback: feedback || '',
      ratedAt: admin.firestore.FieldValue.serverTimestamp(),
      status: 'closed'
    });

    res.status(200).json({
      success: true,
      message: 'Ticket calificado exitosamente'
    });
  } catch (error) {
    res.status(500).json({ success: false, error: { code: 'INTERNAL_ERROR', message: error.message }});
  }
};

// =========================================
// FAQ Y AYUDA
// =========================================

export const getFAQs = async (req: Request, res: Response): Promise<void> => {
  try {
    const { category } = req.query;

    const faqs = [
      {
        id: 'faq_001',
        question: '¿Cómo solicitar un viaje?',
        answer: 'Ingresa tu destino, selecciona el tipo de vehículo y confirma tu solicitud.',
        category: 'rides',
        order: 1
      },
      {
        id: 'faq_002',
        question: '¿Cómo funciona la negociación de precios?',
        answer: 'Los conductores pueden hacer ofertas por tu viaje. Puedes aceptar la mejor oferta o hacer contraofertas.',
        category: 'pricing',
        order: 1
      },
      {
        id: 'faq_003',
        question: '¿Qué métodos de pago aceptan?',
        answer: 'Aceptamos efectivo, tarjetas de crédito/débito y billetera digital.',
        category: 'payment',
        order: 1
      },
      {
        id: 'faq_004',
        question: '¿Cómo cancelar un viaje?',
        answer: 'Puedes cancelar desde la pantalla de seguimiento antes de que el conductor llegue.',
        category: 'rides',
        order: 2
      }
    ];

    const filteredFaqs = category ? faqs.filter(faq => faq.category === category) : faqs;

    res.status(200).json({
      success: true,
      data: filteredFaqs.sort((a, b) => a.order - b.order),
      message: 'FAQs obtenidas exitosamente'
    });
  } catch (error) {
    res.status(500).json({ success: false, error: { code: 'INTERNAL_ERROR', message: error.message }});
  }
};

// =========================================
// FUNCIONES HEREDADAS (COMPATIBILIDAD)
// =========================================

export const getPassengerProfile = getProfile;
export const updatePassengerProfile = updateProfile;

export const requestRide = async (req: Request, res: Response): Promise<void> => {
  res.status(501).json({ success: false, error: { code: 'NOT_IMPLEMENTED', message: 'Usar booking controller' }});
};

export const cancelRide = async (req: Request, res: Response): Promise<void> => {
  res.status(501).json({ success: false, error: { code: 'NOT_IMPLEMENTED', message: 'Usar booking controller' }});
};
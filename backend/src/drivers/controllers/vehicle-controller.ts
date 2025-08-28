import { Request, Response } from 'express';
import * as admin from 'firebase-admin';

// Obtener información del vehículo del conductor
export const getVehicleInfo = async (req: Request, res: Response): Promise<void> => {
  try {
    const driverId = req.user?.uid;
    if (!driverId) {
      res.status(401).json({
        success: false,
        error: { code: 'UNAUTHORIZED', message: 'Conductor no autenticado' }
      });
      return;
    }

    const vehicleDoc = await admin.firestore()
      .collection('vehicles')
      .where('driverId', '==', driverId)
      .where('isActive', '==', true)
      .limit(1)
      .get();

    if (vehicleDoc.empty) {
      res.status(404).json({
        success: false,
        error: { code: 'VEHICLE_NOT_FOUND', message: 'Vehículo no encontrado' }
      });
      return;
    }

    const vehicleData = vehicleDoc.docs[0].data();
    const vehicleId = vehicleDoc.docs[0].id;

    // Obtener documentos del vehículo
    const documentsSnapshot = await admin.firestore()
      .collection('vehicle_documents')
      .where('vehicleId', '==', vehicleId)
      .get();

    const documents = documentsSnapshot.docs.map(doc => ({
      id: doc.id,
      type: doc.data().type,
      number: doc.data().number,
      expiryDate: doc.data().expiryDate,
      status: doc.data().status,
      verifiedAt: doc.data().verifiedAt,
      imageUrl: doc.data().imageUrl
    }));

    const vehicleInfo = {
      id: vehicleId,
      make: vehicleData.make,
      model: vehicleData.model,
      year: vehicleData.year,
      color: vehicleData.color,
      licensePlate: vehicleData.licensePlate,
      vehicleType: vehicleData.vehicleType || 'standard', // economic, standard, premium, luxury
      capacity: vehicleData.capacity || 4,
      features: vehicleData.features || [],
      isVerified: vehicleData.isVerified || false,
      isActive: vehicleData.isActive || false,
      createdAt: vehicleData.createdAt,
      updatedAt: vehicleData.updatedAt,
      documents: documents,
      verification: {
        status: vehicleData.verificationStatus || 'pending', // pending, approved, rejected
        comments: vehicleData.verificationComments,
        verifiedAt: vehicleData.verifiedAt,
        verifiedBy: vehicleData.verifiedBy
      }
    };

    res.status(200).json({
      success: true,
      data: { vehicle: vehicleInfo },
      message: 'Información del vehículo obtenida exitosamente'
    });
  } catch (error) {
    console.error('Error al obtener información del vehículo:', error);
    res.status(500).json({
      success: false,
      error: { code: 'INTERNAL_ERROR', message: 'Error interno del servidor' }
    });
  }
};

// Actualizar información del vehículo
export const updateVehicleInfo = async (req: Request, res: Response): Promise<void> => {
  try {
    const driverId = req.user?.uid;
    if (!driverId) {
      res.status(401).json({
        success: false,
        error: { code: 'UNAUTHORIZED', message: 'Conductor no autenticado' }
      });
      return;
    }

    const {
      make,
      model,
      year,
      color,
      licensePlate,
      vehicleType,
      capacity,
      features
    } = req.body;

    // Buscar vehículo activo del conductor
    const vehicleQuery = await admin.firestore()
      .collection('vehicles')
      .where('driverId', '==', driverId)
      .where('isActive', '==', true)
      .limit(1)
      .get();

    if (vehicleQuery.empty) {
      res.status(404).json({
        success: false,
        error: { code: 'VEHICLE_NOT_FOUND', message: 'Vehículo no encontrado' }
      });
      return;
    }

    const vehicleRef = vehicleQuery.docs[0].ref;
    const updateData: any = {
      updatedAt: admin.firestore.FieldValue.serverTimestamp()
    };

    if (make) updateData.make = make;
    if (model) updateData.model = model;
    if (year) updateData.year = parseInt(year);
    if (color) updateData.color = color;
    if (licensePlate) {
      // Verificar que la placa no esté en uso por otro vehículo
      const existingPlate = await admin.firestore()
        .collection('vehicles')
        .where('licensePlate', '==', licensePlate.toUpperCase())
        .where('isActive', '==', true)
        .get();

      const currentVehicleId = vehicleQuery.docs[0].id;
      const duplicateVehicle = existingPlate.docs.find(doc => doc.id !== currentVehicleId);

      if (duplicateVehicle) {
        res.status(409).json({
          success: false,
          error: { code: 'DUPLICATE_LICENSE_PLATE', message: 'Placa ya registrada por otro vehículo' }
        });
        return;
      }

      updateData.licensePlate = licensePlate.toUpperCase();
    }
    if (vehicleType) updateData.vehicleType = vehicleType;
    if (capacity) updateData.capacity = parseInt(capacity);
    if (features) updateData.features = features;

    // Si se cambian datos importantes, requerir nueva verificación
    if (make || model || year || licensePlate) {
      updateData.isVerified = false;
      updateData.verificationStatus = 'pending';
      updateData.verificationComments = 'Requiere verificación por cambios en información del vehículo';
    }

    await vehicleRef.update(updateData);

    res.status(200).json({
      success: true,
      data: { 
        vehicleId: vehicleQuery.docs[0].id,
        updatedFields: Object.keys(updateData).filter(key => key !== 'updatedAt')
      },
      message: 'Información del vehículo actualizada exitosamente'
    });
  } catch (error) {
    console.error('Error al actualizar información del vehículo:', error);
    res.status(500).json({
      success: false,
      error: { code: 'INTERNAL_ERROR', message: 'Error interno del servidor' }
    });
  }
};

// Agregar nuevo vehículo
export const addVehicle = async (req: Request, res: Response): Promise<void> => {
  try {
    const driverId = req.user?.uid;
    if (!driverId) {
      res.status(401).json({
        success: false,
        error: { code: 'UNAUTHORIZED', message: 'Conductor no autenticado' }
      });
      return;
    }

    const {
      make,
      model,
      year,
      color,
      licensePlate,
      vehicleType = 'standard',
      capacity = 4,
      features = [],
      documents = []
    } = req.body;

    // Validaciones requeridas
    if (!make || !model || !year || !color || !licensePlate) {
      res.status(400).json({
        success: false,
        error: { code: 'MISSING_REQUIRED_FIELDS', message: 'Marca, modelo, año, color y placa son requeridos' }
      });
      return;
    }

    // Validar año del vehículo
    const currentYear = new Date().getFullYear();
    const vehicleYear = parseInt(year);
    
    if (vehicleYear < 2000 || vehicleYear > currentYear + 1) {
      res.status(400).json({
        success: false,
        error: { code: 'INVALID_YEAR', message: 'Año del vehículo debe estar entre 2000 y ' + (currentYear + 1) }
      });
      return;
    }

    // Verificar que la placa no esté registrada
    const existingPlate = await admin.firestore()
      .collection('vehicles')
      .where('licensePlate', '==', licensePlate.toUpperCase())
      .where('isActive', '==', true)
      .get();

    if (!existingPlate.empty) {
      res.status(409).json({
        success: false,
        error: { code: 'DUPLICATE_LICENSE_PLATE', message: 'Placa ya registrada' }
      });
      return;
    }

    // Verificar límite de vehículos por conductor (máximo 1 activo)
    const existingVehicles = await admin.firestore()
      .collection('vehicles')
      .where('driverId', '==', driverId)
      .where('isActive', '==', true)
      .get();

    if (existingVehicles.size >= 1) {
      res.status(400).json({
        success: false,
        error: { code: 'VEHICLE_LIMIT_EXCEEDED', message: 'Solo se permite un vehículo activo por conductor' }
      });
      return;
    }

    const vehicleData = {
      driverId,
      make: make.trim(),
      model: model.trim(),
      year: vehicleYear,
      color: color.trim(),
      licensePlate: licensePlate.toUpperCase().trim(),
      vehicleType,
      capacity: parseInt(capacity),
      features: features || [],
      isActive: true,
      isVerified: false,
      verificationStatus: 'pending',
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      updatedAt: admin.firestore.FieldValue.serverTimestamp()
    };

    const vehicleRef = await admin.firestore().collection('vehicles').add(vehicleData);

    // Agregar documentos si se proporcionan
    if (documents && documents.length > 0) {
      const batch = admin.firestore().batch();
      
      documents.forEach((doc: any) => {
        const docRef = admin.firestore().collection('vehicle_documents').doc();
        batch.set(docRef, {
          vehicleId: vehicleRef.id,
          driverId,
          type: doc.type, // soat, technical_inspection, circulation_permit
          number: doc.number,
          expiryDate: doc.expiryDate ? new Date(doc.expiryDate) : null,
          imageUrl: doc.imageUrl || null,
          status: 'pending', // pending, approved, rejected
          createdAt: admin.firestore.FieldValue.serverTimestamp()
        });
      });

      await batch.commit();
    }

    res.status(201).json({
      success: true,
      data: { 
        vehicleId: vehicleRef.id,
        vehicle: vehicleData,
        documentsUploaded: documents.length
      },
      message: 'Vehículo registrado exitosamente'
    });
  } catch (error) {
    console.error('Error al agregar vehículo:', error);
    res.status(500).json({
      success: false,
      error: { code: 'INTERNAL_ERROR', message: 'Error interno del servidor' }
    });
  }
};

// Desactivar vehículo (no eliminar completamente)
export const removeVehicle = async (req: Request, res: Response): Promise<void> => {
  try {
    const driverId = req.user?.uid;
    const { vehicleId } = req.params;
    const { reason } = req.body;

    if (!driverId) {
      res.status(401).json({
        success: false,
        error: { code: 'UNAUTHORIZED', message: 'Conductor no autenticado' }
      });
      return;
    }

    if (!vehicleId) {
      res.status(400).json({
        success: false,
        error: { code: 'MISSING_VEHICLE_ID', message: 'ID del vehículo requerido' }
      });
      return;
    }

    const vehicleRef = admin.firestore().collection('vehicles').doc(vehicleId);
    const vehicleDoc = await vehicleRef.get();

    if (!vehicleDoc.exists) {
      res.status(404).json({
        success: false,
        error: { code: 'VEHICLE_NOT_FOUND', message: 'Vehículo no encontrado' }
      });
      return;
    }

    const vehicleData = vehicleDoc.data();

    // Verificar que el vehículo pertenece al conductor
    if (vehicleData?.driverId !== driverId) {
      res.status(403).json({
        success: false,
        error: { code: 'FORBIDDEN', message: 'No autorizado para modificar este vehículo' }
      });
      return;
    }

    // Verificar que no hay viajes activos
    const activeRides = await admin.firestore()
      .collection('rides')
      .where('driverId', '==', driverId)
      .where('status', 'in', ['accepted', 'on_way', 'arrived', 'in_progress'])
      .limit(1)
      .get();

    if (!activeRides.empty) {
      res.status(400).json({
        success: false,
        error: { code: 'ACTIVE_RIDES_EXIST', message: 'No se puede desactivar vehículo con viajes activos' }
      });
      return;
    }

    // Desactivar vehículo (soft delete)
    await vehicleRef.update({
      isActive: false,
      deactivatedAt: admin.firestore.FieldValue.serverTimestamp(),
      deactivationReason: reason || 'Desactivado por el conductor',
      updatedAt: admin.firestore.FieldValue.serverTimestamp()
    });

    // También desactivar al conductor si no tiene otros vehículos
    const otherActiveVehicles = await admin.firestore()
      .collection('vehicles')
      .where('driverId', '==', driverId)
      .where('isActive', '==', true)
      .get();

    if (otherActiveVehicles.empty) {
      await admin.firestore().collection('drivers').doc(driverId).update({
        status: 'offline',
        canAcceptRides: false,
        updatedAt: admin.firestore.FieldValue.serverTimestamp()
      });
    }

    res.status(200).json({
      success: true,
      data: { vehicleId },
      message: 'Vehículo desactivado exitosamente'
    });
  } catch (error) {
    console.error('Error al desactivar vehículo:', error);
    res.status(500).json({
      success: false,
      error: { code: 'INTERNAL_ERROR', message: 'Error interno del servidor' }
    });
  }
};

// Subir documentos del vehículo
export const uploadVehicleDocuments = async (req: Request, res: Response): Promise<void> => {
  try {
    const driverId = req.user?.uid;
    const { vehicleId } = req.params;
    const { documents } = req.body;

    if (!driverId) {
      res.status(401).json({
        success: false,
        error: { code: 'UNAUTHORIZED', message: 'Conductor no autenticado' }
      });
      return;
    }

    if (!documents || !Array.isArray(documents) || documents.length === 0) {
      res.status(400).json({
        success: false,
        error: { code: 'MISSING_DOCUMENTS', message: 'Se requiere al menos un documento' }
      });
      return;
    }

    // Verificar que el vehículo existe y pertenece al conductor
    const vehicleDoc = await admin.firestore().collection('vehicles').doc(vehicleId).get();
    
    if (!vehicleDoc.exists || vehicleDoc.data()?.driverId !== driverId) {
      res.status(404).json({
        success: false,
        error: { code: 'VEHICLE_NOT_FOUND', message: 'Vehículo no encontrado o no autorizado' }
      });
      return;
    }

    const batch = admin.firestore().batch();
    const uploadedDocs = [];

    for (const doc of documents) {
      const { type, number, expiryDate, imageUrl } = doc;

      if (!type || !number || !imageUrl) {
        res.status(400).json({
          success: false,
          error: { code: 'INVALID_DOCUMENT', message: 'Tipo, número e imagen son requeridos para cada documento' }
        });
        return;
      }

      // Validar tipos de documento permitidos
      const validTypes = ['soat', 'technical_inspection', 'circulation_permit', 'driver_license'];
      if (!validTypes.includes(type)) {
        res.status(400).json({
          success: false,
          error: { code: 'INVALID_DOCUMENT_TYPE', message: `Tipo de documento inválido: ${type}` }
        });
        return;
      }

      const docRef = admin.firestore().collection('vehicle_documents').doc();
      const docData = {
        vehicleId,
        driverId,
        type,
        number: number.toString().trim(),
        expiryDate: expiryDate ? new Date(expiryDate) : null,
        imageUrl,
        status: 'pending', // pending, approved, rejected
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
        updatedAt: admin.firestore.FieldValue.serverTimestamp()
      };

      batch.set(docRef, docData);
      uploadedDocs.push({
        id: docRef.id,
        ...docData
      });
    }

    await batch.commit();

    // Actualizar estado del vehículo
    await admin.firestore().collection('vehicles').doc(vehicleId).update({
      documentsUploaded: true,
      verificationStatus: 'pending',
      updatedAt: admin.firestore.FieldValue.serverTimestamp()
    });

    res.status(201).json({
      success: true,
      data: { 
        vehicleId,
        documentsUploaded: uploadedDocs.length,
        documents: uploadedDocs
      },
      message: 'Documentos del vehículo subidos exitosamente'
    });
  } catch (error) {
    console.error('Error al subir documentos del vehículo:', error);
    res.status(500).json({
      success: false,
      error: { code: 'INTERNAL_ERROR', message: 'Error interno del servidor' }
    });
  }
};

// Obtener historial de vehículos del conductor
export const getVehicleHistory = async (req: Request, res: Response): Promise<void> => {
  try {
    const driverId = req.user?.uid;
    if (!driverId) {
      res.status(401).json({
        success: false,
        error: { code: 'UNAUTHORIZED', message: 'Conductor no autenticado' }
      });
      return;
    }

    const vehiclesSnapshot = await admin.firestore()
      .collection('vehicles')
      .where('driverId', '==', driverId)
      .orderBy('createdAt', 'desc')
      .get();

    const vehicles = vehiclesSnapshot.docs.map(doc => {
      const data = doc.data();
      return {
        id: doc.id,
        make: data.make,
        model: data.model,
        year: data.year,
        color: data.color,
        licensePlate: data.licensePlate,
        vehicleType: data.vehicleType,
        isActive: data.isActive,
        isVerified: data.isVerified,
        verificationStatus: data.verificationStatus,
        createdAt: data.createdAt,
        deactivatedAt: data.deactivatedAt,
        deactivationReason: data.deactivationReason
      };
    });

    res.status(200).json({
      success: true,
      data: { 
        vehicles,
        totalCount: vehicles.length,
        activeCount: vehicles.filter(v => v.isActive).length
      },
      message: 'Historial de vehículos obtenido exitosamente'
    });
  } catch (error) {
    console.error('Error al obtener historial de vehículos:', error);
    res.status(500).json({
      success: false,
      error: { code: 'INTERNAL_ERROR', message: 'Error interno del servidor' }
    });
  }
};
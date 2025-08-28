import { Request, Response } from 'express';
import * as admin from 'firebase-admin';

// Obtener lugares favoritos del pasajero
export const getFavorites = async (req: Request, res: Response): Promise<void> => {
  try {
    const userId = req.user?.uid;
    if (!userId) {
      res.status(401).json({
        success: false,
        error: { code: 'UNAUTHORIZED', message: 'Usuario no autenticado' }
      });
      return;
    }

    const favoritesSnapshot = await admin.firestore()
      .collection('favorites')
      .where('userId', '==', userId)
      .orderBy('createdAt', 'desc')
      .get();

    const favorites = favoritesSnapshot.docs.map(doc => ({
      id: doc.id,
      ...doc.data()
    }));

    res.status(200).json({
      success: true,
      data: { favorites },
      message: 'Lugares favoritos obtenidos exitosamente'
    });
  } catch (error) {
    console.error('Error al obtener favoritos:', error);
    res.status(500).json({
      success: false,
      error: { code: 'INTERNAL_ERROR', message: 'Error interno del servidor' }
    });
  }
};

// Agregar lugar favorito
export const addFavorite = async (req: Request, res: Response): Promise<void> => {
  try {
    const userId = req.user?.uid;
    if (!userId) {
      res.status(401).json({
        success: false,
        error: { code: 'UNAUTHORIZED', message: 'Usuario no autenticado' }
      });
      return;
    }

    const { name, address, latitude, longitude, type = 'custom' } = req.body;

    if (!name || !address || !latitude || !longitude) {
      res.status(400).json({
        success: false,
        error: { code: 'INVALID_INPUT', message: 'Faltan campos requeridos' }
      });
      return;
    }

    // Verificar si ya existe un favorito con la misma ubicación
    const existingFavorite = await admin.firestore()
      .collection('favorites')
      .where('userId', '==', userId)
      .where('latitude', '==', latitude)
      .where('longitude', '==', longitude)
      .get();

    if (!existingFavorite.empty) {
      res.status(409).json({
        success: false,
        error: { code: 'DUPLICATE_FAVORITE', message: 'Este lugar ya está en favoritos' }
      });
      return;
    }

    // Limitar máximo de favoritos por usuario
    const favoritesCount = await admin.firestore()
      .collection('favorites')
      .where('userId', '==', userId)
      .get();

    if (favoritesCount.size >= 20) {
      res.status(400).json({
        success: false,
        error: { code: 'LIMIT_EXCEEDED', message: 'Máximo de 20 lugares favoritos alcanzado' }
      });
      return;
    }

    const favoriteData = {
      userId,
      name,
      address,
      latitude: parseFloat(latitude.toString()),
      longitude: parseFloat(longitude.toString()),
      type, // home, work, custom
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      updatedAt: admin.firestore.FieldValue.serverTimestamp()
    };

    const favoriteRef = await admin.firestore().collection('favorites').add(favoriteData);

    res.status(201).json({
      success: true,
      data: { favoriteId: favoriteRef.id, favorite: favoriteData },
      message: 'Lugar favorito agregado exitosamente'
    });
  } catch (error) {
    console.error('Error al agregar favorito:', error);
    res.status(500).json({
      success: false,
      error: { code: 'INTERNAL_ERROR', message: 'Error interno del servidor' }
    });
  }
};

// Actualizar lugar favorito
export const updateFavorite = async (req: Request, res: Response): Promise<void> => {
  try {
    const userId = req.user?.uid;
    const { favoriteId } = req.params;
    const { name, address, type } = req.body;

    if (!userId) {
      res.status(401).json({
        success: false,
        error: { code: 'UNAUTHORIZED', message: 'Usuario no autenticado' }
      });
      return;
    }

    const favoriteRef = admin.firestore().collection('favorites').doc(favoriteId);
    const favoriteDoc = await favoriteRef.get();

    if (!favoriteDoc.exists) {
      res.status(404).json({
        success: false,
        error: { code: 'FAVORITE_NOT_FOUND', message: 'Lugar favorito no encontrado' }
      });
      return;
    }

    const favoriteData = favoriteDoc.data();
    if (favoriteData?.userId !== userId) {
      res.status(403).json({
        success: false,
        error: { code: 'FORBIDDEN', message: 'No autorizado para modificar este favorito' }
      });
      return;
    }

    const updateData: any = {
      updatedAt: admin.firestore.FieldValue.serverTimestamp()
    };

    if (name) updateData.name = name;
    if (address) updateData.address = address;
    if (type) updateData.type = type;

    await favoriteRef.update(updateData);

    res.status(200).json({
      success: true,
      data: { favoriteId, updatedFields: updateData },
      message: 'Lugar favorito actualizado exitosamente'
    });
  } catch (error) {
    console.error('Error al actualizar favorito:', error);
    res.status(500).json({
      success: false,
      error: { code: 'INTERNAL_ERROR', message: 'Error interno del servidor' }
    });
  }
};

// Eliminar lugar favorito
export const deleteFavorite = async (req: Request, res: Response): Promise<void> => {
  try {
    const userId = req.user?.uid;
    const { favoriteId } = req.params;

    if (!userId) {
      res.status(401).json({
        success: false,
        error: { code: 'UNAUTHORIZED', message: 'Usuario no autenticado' }
      });
      return;
    }

    const favoriteRef = admin.firestore().collection('favorites').doc(favoriteId);
    const favoriteDoc = await favoriteRef.get();

    if (!favoriteDoc.exists) {
      res.status(404).json({
        success: false,
        error: { code: 'FAVORITE_NOT_FOUND', message: 'Lugar favorito no encontrado' }
      });
      return;
    }

    const favoriteData = favoriteDoc.data();
    if (favoriteData?.userId !== userId) {
      res.status(403).json({
        success: false,
        error: { code: 'FORBIDDEN', message: 'No autorizado para eliminar este favorito' }
      });
      return;
    }

    await favoriteRef.delete();

    res.status(200).json({
      success: true,
      message: 'Lugar favorito eliminado exitosamente'
    });
  } catch (error) {
    console.error('Error al eliminar favorito:', error);
    res.status(500).json({
      success: false,
      error: { code: 'INTERNAL_ERROR', message: 'Error interno del servidor' }
    });
  }
};

// Obtener sugerencias de lugares basados en favoritos e historial
export const getFavoriteSuggestions = async (req: Request, res: Response): Promise<void> => {
  try {
    const userId = req.user?.uid;
    if (!userId) {
      res.status(401).json({
        success: false,
        error: { code: 'UNAUTHORIZED', message: 'Usuario no autenticado' }
      });
      return;
    }

    // Obtener favoritos del usuario
    const favoritesSnapshot = await admin.firestore()
      .collection('favorites')
      .where('userId', '==', userId)
      .limit(5)
      .get();

    // Obtener destinos frecuentes del historial de viajes
    const ridesSnapshot = await admin.firestore()
      .collection('rides')
      .where('passengerId', '==', userId)
      .where('status', '==', 'completed')
      .orderBy('createdAt', 'desc')
      .limit(50)
      .get();

    const destinationCounts: { [key: string]: any } = {};
    
    ridesSnapshot.docs.forEach(doc => {
      const ride = doc.data();
      const destination = ride.destination;
      if (destination) {
        const key = `${destination.latitude},${destination.longitude}`;
        if (destinationCounts[key]) {
          destinationCounts[key].count += 1;
        } else {
          destinationCounts[key] = {
            address: destination.address,
            latitude: destination.latitude,
            longitude: destination.longitude,
            count: 1
          };
        }
      }
    });

    // Ordenar por frecuencia
    const frequentDestinations = Object.values(destinationCounts)
      .sort((a: any, b: any) => b.count - a.count)
      .slice(0, 5);

    const favorites = favoritesSnapshot.docs.map(doc => ({
      id: doc.id,
      ...doc.data()
    }));

    res.status(200).json({
      success: true,
      data: { 
        favorites,
        frequentDestinations
      },
      message: 'Sugerencias obtenidas exitosamente'
    });
  } catch (error) {
    console.error('Error al obtener sugerencias:', error);
    res.status(500).json({
      success: false,
      error: { code: 'INTERNAL_ERROR', message: 'Error interno del servidor' }
    });
  }
};
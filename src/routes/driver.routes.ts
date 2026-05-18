import { Router } from 'express';
import { logger } from '../utils/logger';

const router = Router();

// GET /api/v1/drivers
router.get('/', async (req, res) => {
  try {
    logger.info('🚘 Get drivers');
    
    res.json({
      success: true,
      message: 'Drivers endpoint funcionando',
      data: []
    });
  } catch (error) {
    res.status(500).json({
      success: false,
      message: 'Error obteniendo conductores'
    });
  }
});

export default router;
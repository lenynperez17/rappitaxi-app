import { Router } from 'express';
import { logger } from '../utils/logger';

const router = Router();

// GET /api/v1/admin/dashboard
router.get('/dashboard', async (req, res) => {
  try {
    logger.info('📊 Admin dashboard');
    
    res.json({
      success: true,
      message: 'Admin dashboard endpoint funcionando',
      data: {}
    });
  } catch (error) {
    res.status(500).json({
      success: false,
      message: 'Error en dashboard admin'
    });
  }
});

export default router;
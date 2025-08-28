import { Router } from 'express';

const router = Router();

// Ratings routes placeholder - implementación pendiente
router.get('/health', (req, res) => {
  res.json({ success: true, message: 'Ratings service operational' });
});

export default router;
import { Router } from 'express';

const router = Router();

// Tracking routes placeholder - implementación pendiente
router.get('/health', (req, res) => {
  res.json({ success: true, message: 'Tracking service operational' });
});

export default router;
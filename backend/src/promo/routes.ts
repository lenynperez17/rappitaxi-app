import { Router } from 'express';

const router = Router();

// Promo routes placeholder - implementación pendiente
router.get('/health', (req, res) => {
  res.json({ success: true, message: 'Promo service operational' });
});

export default router;
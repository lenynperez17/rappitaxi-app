import { Router } from 'express';

const router = Router();

// Analytics routes placeholder - implementación pendiente
router.get('/health', (req, res) => {
  res.json({ success: true, message: 'Analytics service operational' });
});

export default router;
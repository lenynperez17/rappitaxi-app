import { Router } from 'express';

const router = Router();

// Support routes placeholder - implementación pendiente
router.get('/health', (req, res) => {
  res.json({ success: true, message: 'Support service operational' });
});

export default router;
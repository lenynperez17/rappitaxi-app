import { Router } from 'express';

const router = Router();

// Wallet routes placeholder - implementación pendiente
router.get('/health', (req, res) => {
  res.json({ success: true, message: 'Wallet service operational' });
});

export default router;
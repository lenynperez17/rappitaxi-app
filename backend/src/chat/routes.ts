import { Router } from 'express';

const router = Router();

// Chat routes placeholder - implementación pendiente
router.get('/health', (req, res) => {
  res.json({ success: true, message: 'Chat service operational' });
});

export default router;
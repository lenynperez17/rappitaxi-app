import { Router } from 'express';

const router = Router();

// Negotiation routes placeholder - implementación pendiente
router.get('/health', (req, res) => {
  res.json({ success: true, message: 'Negotiation service operational' });
});

export default router;
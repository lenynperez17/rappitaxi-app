-- Configuración persistente del sistema (accedida desde /settings en el panel admin)
INSERT INTO schema_migrations (version, description)
VALUES ('012', 'app_settings')
ON CONFLICT DO NOTHING;

CREATE TABLE IF NOT EXISTS app_settings (
  key         TEXT PRIMARY KEY,
  value       JSONB NOT NULL,
  description TEXT,
  updated_by  TEXT REFERENCES users(id) ON DELETE SET NULL,
  updated_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);

INSERT INTO app_settings (key, value, description) VALUES
  ('company.name',       '"Rapi Team"'::jsonb,                      'Nombre comercial de la empresa'),
  ('company.ruc',        '"20612945790"'::jsonb,                    'RUC de la empresa (SUNAT)'),
  ('company.address',    '"Lima, Perú"'::jsonb,                     'Dirección fiscal'),
  ('company.support_email', '"facturacion.rapiteam@gmail.com"'::jsonb, 'Correo de soporte al cliente'),
  ('rides.commission_percent', '20'::jsonb,                          'Comisión de la plataforma sobre cada viaje (%)'),
  ('rides.min_fare',      '5'::jsonb,                                 'Tarifa mínima en soles'),
  ('rides.max_distance_km', '50'::jsonb,                              'Distancia máxima permitida por viaje (km)'),
  ('rides.negotiable',    'true'::jsonb,                              '¿Permitir negociación de precio (InDrive style)?'),
  ('wallet.min_recharge', '5'::jsonb,                                 'Recarga mínima al wallet (S/)'),
  ('wallet.min_withdrawal', '20'::jsonb,                              'Retiro mínimo del wallet (S/)'),
  ('wallet.withdrawal_fee', '2'::jsonb,                               'Cargo fijo por retiro (S/)'),
  ('maintenance_mode',    'false'::jsonb,                             'Bloquear la app móvil por mantenimiento'),
  ('registration.driver_enabled', 'true'::jsonb,                      '¿Permitir registro de nuevos conductores?'),
  ('registration.passenger_enabled', 'true'::jsonb,                   '¿Permitir registro de nuevos pasajeros?')
ON CONFLICT (key) DO NOTHING;

-- Ronda 279 · Catálogo de documentos del conductor
--
-- CÓMO SE APLICA
-- --------------
-- La parte del ALTER TABLE exige ser dueño de `driver_documents`, y el dueño
-- es `postgres`, no el usuario de la aplicación:
--
--     sudo -u postgres psql -d rapi_team_api -v ON_ERROR_STOP=1 -f 024_...sql
--     sudo -u postgres psql -d rapi_team_api \
--       -c "GRANT SELECT, INSERT, UPDATE, DELETE ON driver_document_types TO rapi_team_user;"
--
-- POR QUÉ
-- -------
-- El dueño pidió poder activar y desactivar desde el panel qué documentos se
-- le piden al conductor. Hoy esa lista está escrita a mano en catorce sitios
-- repartidos por las tres capas, y el subconjunto de "obligatorios para quedar
-- verificado" tiene TRES representaciones independientes que hay que mantener
-- sincronizadas de memoria — incluida un literal dentro de una consulta:
--
--     AND dd.doc_type = ANY(ARRAY['dni_front',...,'soat']::text[]) ) = 5
--
-- Ese `= 5` es una bomba de relojería: el día que se desactive un documento y
-- nadie se acuerde de bajar el número, NINGÚN conductor vuelve a verificarse,
-- y en silencio. Por eso esto no se resuelve con un ajuste suelto: hace falta
-- una única fuente de verdad, y ésta es la tabla.
--
-- LA RESTRICCIÓN CHECK SE CONVIERTE EN CLAVE FORÁNEA
-- --------------------------------------------------
-- `driver_documents.doc_type` tenía un CHECK con diez valores escritos a mano.
-- Añadir un tipo obligaba a una migración de esquema. Pasa a ser FK contra
-- este catálogo: añadir un documento es insertar una fila.
--
-- LA COLISIÓN DE 'other'
-- ----------------------
-- `upgrade_to_driver_screen.dart` subía DOS documentos distintos con la misma
-- clave 'other': antecedentes penales y revisión técnica. Con
-- UNIQUE(driver_id, doc_type) y una subida que hace UPSERT, el segundo
-- machacaba al primero. El conductor subía los dos y solo quedaba uno, sin
-- aviso. Aquí nacen sus códigos propios.

CREATE TABLE IF NOT EXISTS driver_document_types (
  code        TEXT PRIMARY KEY,
  label       TEXT NOT NULL,
  description TEXT NOT NULL DEFAULT '',
  -- ¿Se le pide al conductor? Desactivado = ni siquiera aparece en la app.
  enabled     BOOLEAN NOT NULL DEFAULT true,
  -- ¿Hace falta para quedar verificado? Opcional = se puede subir, pero no
  -- bloquea la verificación.
  required    BOOLEAN NOT NULL DEFAULT false,
  sort_order  INTEGER NOT NULL DEFAULT 100,
  created_at  TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Los tipos de hoy, con los valores de hoy: al desplegar, nada cambia de
-- comportamiento. Los cinco obligatorios son exactamente los cinco que estaban
-- escritos en el literal SQL.
INSERT INTO driver_document_types (code, label, description, enabled, required, sort_order) VALUES
  ('dni_front',         'DNI (frente)',                   'Documento Nacional de Identidad — cara frontal',   true,  true,  10),
  ('dni_back',          'DNI (reverso)',                  'Documento Nacional de Identidad — cara posterior', true,  true,  20),
  ('license_front',     'Licencia (frente)',              'Licencia de conducir vigente — cara frontal',      true,  true,  30),
  ('license_back',      'Licencia (reverso)',             'Licencia de conducir vigente — cara posterior',    true,  true,  40),
  ('soat',              'SOAT vigente',                   'Seguro Obligatorio de Accidentes de Tránsito',     true,  true,  50),
  ('tarjeta_propiedad', 'Tarjeta de propiedad (frente)',  'Registro vehicular — cara frontal',                true,  false, 60),
  ('ownership',         'Tarjeta de propiedad (reverso)', 'Registro vehicular — cara posterior',              true,  false, 70),
  ('selfie',            'Selfie del conductor',           'Foto de rostro para verificación',                 true,  false, 80),
  ('vehicle_photo',     'Foto del vehículo',              'Foto del vehículo que usarás',                     true,  false, 90),
  -- Los dos que compartían la clave 'other'. Nacen desactivados: hoy solo los
  -- pide la pantalla de alta rápida y con el código equivocado; se activan
  -- desde el panel cuando la app que los sabe subir esté en las tiendas.
  ('criminal_record',   'Antecedentes penales',           'Certificado de antecedentes penales vigente',      false, false, 100),
  ('technical_review',  'Revisión técnica',               'Certificado de inspección técnica vehicular',      false, false, 110),
  -- 'other' se conserva porque hay filas históricas que podrían apuntar a él y
  -- porque la FK de abajo lo exige. Desactivado: ya no se le pide a nadie.
  ('other',             'Otro documento',                 'Documento sin categoría específica',               false, false, 900)
ON CONFLICT (code) DO NOTHING;

-- El CHECK escrito a mano se sustituye por la FK contra el catálogo.
-- Se hace en dos pasos y con IF EXISTS para que la migración sea repetible.
ALTER TABLE driver_documents DROP CONSTRAINT IF EXISTS driver_documents_doc_type_check;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint WHERE conname = 'driver_documents_doc_type_fkey'
  ) THEN
    ALTER TABLE driver_documents
      ADD CONSTRAINT driver_documents_doc_type_fkey
      FOREIGN KEY (doc_type) REFERENCES driver_document_types(code)
      -- RESTRICT y no CASCADE: borrar un tipo del catálogo teniendo documentos
      -- subidos de ese tipo debe fallar ruidosamente, no llevarse los
      -- documentos de los conductores por delante.
      ON UPDATE CASCADE ON DELETE RESTRICT;
  END IF;
END $$;

CREATE INDEX IF NOT EXISTS idx_driver_document_types_enabled
  ON driver_document_types(enabled, sort_order);

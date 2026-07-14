-- 017: Constraint CHECK en users.user_type para prevenir enum drift.
--
-- HIGH: sin este constraint, un typo ('driver ', 'Driver') o valor arbitrario
-- inserta silenciosamente y admin/stats no lo cuenta en ningún bucket,
-- creando inconsistencia entre "total_users" y "passengers+drivers+dual+admins".
--
-- Antes de agregar el constraint, limpiar cualquier fila con valor inválido
-- histórico (defaultear a 'passenger' si existe).

-- Paso 1: normalizar valores existentes rotos
UPDATE users
   SET user_type = 'passenger'
 WHERE user_type IS NULL
    OR user_type NOT IN ('passenger', 'driver', 'dual', 'admin');

-- Paso 2: agregar la constraint
ALTER TABLE users
  ADD CONSTRAINT users_type_valid
  CHECK (user_type IN ('passenger', 'driver', 'dual', 'admin'));

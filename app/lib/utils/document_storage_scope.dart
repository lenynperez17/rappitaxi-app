/// Ronda 237: mapea el `docType` interno del driver (dni_front, soat,
/// vehicle_photo, etc.) al `scope` que /api/storage/upload acepta.
///
/// El backend valida contra una whitelist (ALLOWED_SCOPES) — pasar
/// `document` o `documents` devuelve 400 `invalid_scope` y bloquea la
/// subida. Este helper garantiza el mapping correcto en un solo lugar.
String storageScopeForDocType(String docType) {
  switch (docType) {
    case 'dni_front':
      return 'identity_front';
    case 'dni_back':
      return 'identity_back';
    case 'license_front':
    case 'license_back':
      return 'driver_license';
    case 'soat':
      return 'soat';
    case 'tarjeta_propiedad':
    case 'ownership':
      return 'vehicle_registration';
    case 'selfie':
      return 'profile_photo';
    case 'vehicle_photo':
      return 'vehicle_photo';
    default:
      return 'misc';
  }
}

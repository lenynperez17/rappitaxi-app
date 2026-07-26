/// Ronda 247: normalización de fecha de nacimiento.
///
/// El backend exige estrictamente `YYYY-MM-DD` (`/^\d{4}-\d{2}-\d{2}$/`), pero
/// el cliente construía la fecha como `'${day}/${month}/${year}'` → `15/3/1990`.
/// Resultado: CUALQUIER intento de guardar el perfil con fecha de nacimiento
/// devolvía 400 y, como el nombre viaja en el mismo PATCH, **no se guardaba
/// nada** — ni siquiera un cambio de nombre. Y ocurría aunque el usuario no
/// tocara la fecha, porque el GET la devuelve como ISO completo
/// (`1990-03-15T00:00:00.000Z`) y se reenviaba tal cual.
library;

/// Convierte cualquier variante razonable a `YYYY-MM-DD`.
/// Devuelve null si no se puede interpretar (mejor no enviar el campo que
/// tumbar el guardado entero).
String? normalizeBirthDate(String? raw) {
  if (raw == null) return null;
  final v = raw.trim();
  if (v.isEmpty) return null;

  // Ya viene correcto.
  final iso = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$');
  if (iso.hasMatch(v)) return v;

  // ISO completo con hora: 1990-03-15T00:00:00.000Z
  if (v.length >= 10 && iso.hasMatch(v.substring(0, 10))) {
    return v.substring(0, 10);
  }

  // D/M/YYYY o DD/MM/YYYY (formato local peruano).
  final slash = RegExp(r'^(\d{1,2})/(\d{1,2})/(\d{4})$').firstMatch(v);
  if (slash != null) {
    final d = slash.group(1)!.padLeft(2, '0');
    final m = slash.group(2)!.padLeft(2, '0');
    return '${slash.group(3)}-$m-$d';
  }

  // Último recurso: que lo intente DateTime.
  final parsed = DateTime.tryParse(v);
  if (parsed != null) {
    final m = parsed.month.toString().padLeft(2, '0');
    final d = parsed.day.toString().padLeft(2, '0');
    return '${parsed.year}-$m-$d';
  }
  return null;
}

/// Para mostrar en pantalla: `YYYY-MM-DD` → `DD/MM/YYYY`.
String formatBirthDateForDisplay(String? raw) {
  final norm = normalizeBirthDate(raw);
  if (norm == null) return '';
  final p = norm.split('-');
  return '${p[2]}/${p[1]}/${p[0]}';
}

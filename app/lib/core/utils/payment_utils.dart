/// Centralized payment method label formatter.
/// Converts raw Firestore values (cash, yape, plin, card, wallet)
/// to user-friendly Spanish labels (Efectivo, Yape, Plin, Tarjeta, Billetera).
String formatPaymentMethodLabel(String? method) {
  switch (method?.toLowerCase()) {
    case 'cash':
    case 'efectivo':
      return 'Efectivo';
    case 'yape':
      return 'Yape';
    case 'plin':
      return 'Plin';
    case 'card':
    case 'tarjeta':
      return 'Tarjeta';
    case 'wallet':
    case 'billetera':
      return 'Billetera';
    default:
      return method ?? 'Efectivo';
  }
}

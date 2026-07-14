/// Centralized translation strings for driver screens.
/// Uses locale code ('es' or 'en') to return the correct string.
/// This avoids modifying generated .arb files for driver-specific UI strings.
class DriverStrings {
  final String _lang;
  DriverStrings(String langCode) : _lang = langCode;

  bool get _en => _lang == 'en';

  // ── General / Shared ──────────────────────────────
  String get next => _en ? 'Next' : 'Siguiente';
  String get understood => _en ? 'Understood' : 'Entendido';
  String get close => _en ? 'Close' : 'Cerrar';
  String get save => _en ? 'Save' : 'Guardar';
  String get cancel => _en ? 'Cancel' : 'Cancelar';
  String get delete => _en ? 'Delete' : 'Eliminar';
  String get search => _en ? 'Search' : 'Buscar';
  String get accept => _en ? 'Accept' : 'Aceptar';
  String get send => _en ? 'Send' : 'Enviar';
  String get back => _en ? 'Back' : 'Volver';
  String get all => _en ? 'All' : 'Todos';
  String get active => _en ? 'Active' : 'Activas';
  String get loading => _en ? 'Loading...' : 'Cargando...';
  String get error => _en ? 'Error' : 'Error';
  String get writeYourMessage => _en ? 'Write your message' : 'Escribe tu mensaje';

  // ── Security Screen ───────────────────────────────
  String get security => _en ? 'Security' : 'Seguridad';
  String get support => _en ? 'Support' : 'Soporte';
  String get emergencyContacts => _en ? 'Emergency\ncontacts' : 'Contactos de\nemergencia';
  String get emergencyContactsTitle => _en ? 'Emergency contacts' : 'Contactos de emergencia';
  String get call105 => _en ? 'Call 105' : 'Llamar 105';
  String get howYouAreProtected => _en ? 'How you are protected' : 'Cómo estás protegido';
  String get tripReview => _en ? 'Trip\nreview' : 'Revisión\ndel viaje';
  String get passengerVerification => _en ? 'Passenger\nverification' : 'Verificación\nde pasajeros';
  String get protectPrivacy => _en ? 'Protect\nprivacy' : 'Proteger la\nprivacidad';
  String get safetyAllTrips => _en ? 'Safety in\nall trips' : 'Seguridad en\ntodos los viajes';
  String get accidentsSteps => _en ? 'Accidents:\nsteps to follow' : 'Accidentes:\npasos a seguir';

  // Safety carousel
  String get tripReviewTitle => _en ? 'Trip Review' : 'Revisión del viaje';
  String get tripReviewDesc => _en
      ? 'You will receive a notification if we notice an unusual route or a prolonged stop. Confirm that you are safe or request help in the app.'
      : 'Recibirás una notificación si notamos una ruta inusual o una parada prolongada. Confirma que estás a salvo o solicita ayuda en la aplicación.';
  String get passengerVerificationTitle => _en ? 'Passenger Verification' : 'Verificación de pasajeros';
  String get passengerVerificationDesc => _en
      ? 'All passengers verify their identity with a phone number. You can see the rating and trip history before accepting.'
      : 'Todos los pasajeros verifican su identidad con número de teléfono. Puedes ver la calificación y el historial de viajes antes de aceptar.';
  String get protectPrivacyTitle => _en ? 'Protect Privacy' : 'Proteger la privacidad';
  String get protectPrivacyDesc => _en
      ? 'Your personal phone number is never shared with passengers. Calls and messages are made through the app.'
      : 'Tu número de teléfono personal nunca se comparte con los pasajeros. Las llamadas y mensajes se realizan a través de la aplicación.';
  String get safetyAllTripsTitle => _en ? 'Safety in All Trips' : 'Seguridad en todos los viajes';
  String get safetyAllTripsDesc => _en
      ? 'Every trip is monitored with real-time GPS. If we detect something unusual, we will contact you to verify you are okay.'
      : 'Cada viaje es monitoreado con GPS en tiempo real. Si detectamos algo inusual, te contactaremos para verificar que estés bien.';
  String get accidentsTitle => _en ? 'Accidents: Steps to Follow' : 'Accidentes: pasos a seguir';
  String get accidentsDesc => _en
      ? 'In case of an accident, use the SOS button to alert emergencies and your contacts. Document the incident with photos and report in the app.'
      : 'En caso de accidente, usa el botón SOS para alertar a emergencias y tus contactos. Documenta el incidente con fotos y reporta en la app.';

  // Emergency contacts
  String get addUpTo5Contacts => _en
      ? 'Add up to 5 emergency contacts. We will contact them in case of an emergency.'
      : 'Agregue hasta 5 contactos de emergencia. Nos comunicaremos con ellos en caso de una emergencia.';
  String get addContact => _en ? 'Add contact' : 'Agregar contacto';
  String get newContact => _en ? 'New contact' : 'Nuevo contacto';
  String get contactNameHint => _en ? 'Contact person name' : 'Nombre de la persona de contacto';
  String get changesOnlySavedInApp => _en
      ? 'Changes will only be saved in the Rappi Team application and will not affect your device\'s contact list'
      : 'Los cambios solo se guardarán en la aplicación Rappi Team y no afectarán a la lista de contactos de tu dispositivo';
  String get enterContactName => _en ? 'Enter the contact name' : 'Ingresa el nombre del contacto';
  String get enterValidPhone => _en ? 'Enter a valid phone number' : 'Ingresa un número de teléfono válido';
  String contactAdded(String name) => _en ? '$name added as emergency contact' : '$name agregado como contacto de emergencia';
  String get errorSavingContact => _en ? 'Error saving contact' : 'Error al guardar el contacto';
  String get deleteContact => _en ? 'Delete contact' : 'Eliminar contacto';
  String deleteContactConfirm(String name) => _en ? 'Remove $name from your emergency contacts?' : '¿Eliminar a $name de tus contactos de emergencia?';
  String get primary => _en ? 'Primary' : 'Principal';

  // Support chat
  String get selectService => _en ? 'Select the service' : 'Selecciona el servicio';
  String get cityTrips => _en ? 'City trips' : 'Viajes en la ciudad';
  String get intercityTrips => _en ? 'Intercity trips' : 'Viajes entre ciudades';
  String get freightDelivery => _en ? 'Freight delivery' : 'Entrega con fletes';
  String get courierDelivery => _en ? 'Courier delivery' : 'Entrega con repartidor';
  String get creditOptions => _en ? 'Credit options' : 'Opciones de crédito';
  String get marketplace => _en ? 'Marketplace' : 'Mercado';
  String get selectYourRole => _en ? 'Select your role' : 'Selecciona tu rol';
  String get passenger => _en ? 'Passenger' : 'Pasajero';
  String get driverRole => _en ? 'Driver' : 'Conductor';
  String get howCanWeHelp => _en ? 'How can we help you?' : '¿En qué podemos ayudarte?';
  String get tripProblem => _en ? 'Problem with a trip' : 'Problema con un viaje';
  String get paymentProblem => _en ? 'Problem with payment' : 'Problema con el pago';
  String get reportIncident => _en ? 'Report an incident' : 'Reportar un incidente';
  String get accountAndProfile => _en ? 'Account and profile' : 'Cuenta y perfil';
  String get otherTopic => _en ? 'Other topic' : 'Otro tema';
  String get incorrectCharge => _en ? 'Incorrect charge' : 'Cobro incorrecto';
  String get incorrectRoute => _en ? 'Incorrect route' : 'Ruta incorrecta';
  String get noShow => _en ? 'Driver/passenger did not show up' : 'Conductor/pasajero no se presentó';
  String get lostItem => _en ? 'Lost item' : 'Objeto olvidado';
  String get other => _en ? 'Other' : 'Otro';
  String get paymentNotProcessed => _en ? 'Payment not processed' : 'No se procesó el pago';
  String get doubleCharge => _en ? 'Double charge' : 'Cobro doble';
  String get requestRefund => _en ? 'Request refund' : 'Solicitar reembolso';
  String get walletProblem => _en ? 'Wallet problem' : 'Problema con cartera';
  String get inappropriateBehavior => _en ? 'Inappropriate behavior' : 'Comportamiento inapropiado';
  String get accident => _en ? 'Accident' : 'Accidente';
  String get safetyProblem => _en ? 'Safety problem' : 'Problema de seguridad';
  String get changePersonalData => _en ? 'Change personal data' : 'Cambiar datos personales';
  String get verificationProblems => _en ? 'Verification problems' : 'Problemas con verificación';
  String get deleteMyAccount => _en ? 'Delete account' : 'Eliminar cuenta';
  String get describeProblem => _en
      ? 'Describe your problem and a support agent will assist you soon. You can also write us on WhatsApp.'
      : 'Describe tu problema y un agente de soporte te atenderá pronto. También puedes escribirnos por WhatsApp.';
  String agentWillReview(String topic, String service, String role) => _en
      ? 'Got it. An agent will review your case about "$topic" in $service as $role. Write more details if you wish, or we will contact you soon.'
      : 'Entendido. Un agente revisará tu caso sobre "$topic" en $service como $role. Escribe más detalles si lo deseas, o te contactaremos pronto.';
  String get thankYouInfo => _en
      ? 'Thank you for the information. A support agent will contact you soon. If it\'s urgent, you can call 105 or write us on WhatsApp.'
      : 'Gracias por la información. Un agente de soporte se pondrá en contacto contigo pronto. Si es urgente, puedes llamar al 105 o escribirnos por WhatsApp.';
  String get selectProblemType => _en ? 'Select the type of problem:' : 'Selecciona el tipo de problema:';
  String get selectIncidentType => _en ? 'Select the type of incident:' : 'Selecciona el tipo de incidente:';
  String get whatDoYouNeed => _en ? 'What do you need?' : '¿Qué necesitas?';

  // ── Config Screen (Ride Config) ───────────────────
  String get configuration => _en ? 'Configuration' : 'Configuración';
  String get rates => _en ? 'Rates' : 'Tarifas';
  String get requests => _en ? 'Requests' : 'Solicitudes';
  String get trips2 => _en ? 'Trips' : 'Viajes';
  String get trip => _en ? 'Trip' : 'Viaje';
  String get comfort => _en ? 'Comfort' : 'Confort';
  String get xl => 'XL';
  String get xlNotAvailable => _en ? 'Not available for your vehicle...' : 'No está disponible para tu vehíc...';
  String get deliveries => _en ? 'Deliveries' : 'Entregas';
  String get packageDelivery => _en ? 'Package delivery' : 'Entrega de paquetes';
  String get thermalBag => _en ? 'Thermal bag for food' : 'Bolsa térmica para alimentos';
  String get basicTrip => _en ? 'Basic trip type, suitable for all vehicles' : 'Tipo de viaje básico, adecuado para todos los vehículos';
  String get comfortDesc => _en
      ? 'Rates are higher than Trip rate. Follow the service rules, keep the car clean and verify that the air conditioning is on.'
      : 'Las tarifas son más altas que la tarifa de Viaje. Sigue las reglas de servicio, mantén el auto limpio y verifica que el aire acondicionado esté encendido.';
  String get comfortRules => _en ? 'Comfort trip rules' : 'Reglas de los viajes Confort';
  String get comfortRequirements => _en ? 'Comfort requirements' : 'Requisitos de Confort';
  String get vehicle6Passengers => _en ? '6-passenger vehicle' : 'Vehículo de 6 pasajeros';
  String get vehicle6Desc => _en
      ? 'Transport large groups or passengers with extra luggage. Your car must have at least 6 seats'
      : 'Transporte grupos grandes o pasajeros con equipaje extra. Tu auto debe tener al menos 6 asientos';
  String get change => _en ? 'Change' : 'Cambiar';
  String get contactSupportToChange => _en ? 'Contact support to change your vehicle' : 'Contacta soporte para cambiar tu vehículo';
  String get darkMode => _en ? 'Dark mode' : 'Modo oscuro';
  String get disable => _en ? 'Disable' : 'Desactivar';
  String get enable => _en ? 'Enable' : 'Activar';
  String get rideSounds => _en ? 'Ride request sounds' : 'Sonidos de las solicitudes de viaje';
  String get rideSoundsDesc => _en ? 'Receive notifications of new trips in the request list' : 'Recibe notificaciones de viajes nuevos en la lista de solicitudes';
  String get requestChain => _en ? 'Request chain' : 'Cadena de solicitudes';
  String get requestChainDesc => _en
      ? 'When you finish a trip, you will automatically receive the next nearby request without having to wait.'
      : 'Cuando termines un viaje, recibirás automáticamente la siguiente solicitud cercana sin tener que esperar.';
  String get navigator => _en ? 'Navigator' : 'Navegador';

  // ── Drawer Menu ───────────────────────────────────
  String get performance => _en ? 'Performance' : 'Rendimiento';
  String get intercity => _en ? 'Intercity' : 'Ciudad a ciudad';
  String get freight => _en ? 'Freight' : 'Flete';
  String get help => _en ? 'Help' : 'Ayuda';

  // ── Freight Screen ────────────────────────────────
  String get requestWall => _en ? 'Request wall' : 'Muro de solicitudes';
  String get myRequests => _en ? 'My requests' : 'Mis solicitudes';
  String get ratingTab => _en ? 'Rating' : 'Calificación';
  String get busy => _en ? 'Busy' : 'Ocupado';
  String get available => _en ? 'Available' : 'Disponible';
  String get waitingResponse => _en ? 'Waiting for response' : 'Esperando respuesta';
  String get activeRequests => _en ? 'Active requests' : 'Solicitudes activas';
  String get noRequestsYet => _en ? 'No requests yet' : 'Aún no tienes solicitudes';
  String get searchRequest => _en ? 'Search a request' : 'Buscar una solicitud';
  String get makeOffer => _en ? 'Make an offer' : 'Hacer una oferta';
  String get yourOffer => _en ? 'Your offer' : 'Tu oferta';
  String get sendOffer => _en ? 'Send offer' : 'Enviar oferta';
  String get sendComplaint => _en ? 'Send a complaint' : 'Envía una queja';
  String get normal => _en ? 'Normal' : 'Normal';
  String get averageRating => _en ? 'Average rating' : 'Calificación promedio';
  String get frequency => _en ? 'Frequency' : 'Frecuencia';
  String get cancellationRate => _en ? 'Cancellation rate' : 'Tasa de cancelación';
  String get tripsCount => _en ? 'Trips' : 'Viajes';
  String get reviews => _en ? 'Reviews' : 'Reseñas';
  String get balance => _en ? 'Balance' : 'Saldo';
  String get noReviewsYet => _en ? 'No reviews yet' : 'Aún no tienes reseñas';

  // ── Intercity Screen ──────────────────────────────
  String get tripRequests => _en ? 'Trip requests' : 'Solicitudes de viaje';
  String get myTrips => _en ? 'My trips' : 'Mis viajes';
  String get origin => _en ? 'Origin' : 'Origen';
  String get destination => _en ? 'Destination' : 'Destino';
  String get date => _en ? 'Date' : 'Fecha';
  String get accepted => _en ? 'Accepted' : 'Aceptadas';
  String get pending => _en ? 'Pending' : 'Pendientes';
  String get archived => _en ? 'Archived' : 'Archivadas';
  String get unlimitedRequests => _en ? 'Unlimited requests' : 'Solicitudes ilimitadas';
  String get notifyNewRequests => _en ? 'Notify new requests' : 'Notificar nuevas solicitudes';
  String get selectCity => _en ? 'Select city' : 'Selecciona ciudad';
  String get searchCity => _en ? 'Search city...' : 'Buscar ciudad...';

  // ── Comfort Rules Screen ──────────────────────────
  String get welcome => _en ? 'Welcome' : 'Bienvenida';
  String get airConditioning => _en ? 'Air conditioning' : 'Aire acondicionado';
  String get cleanCar => _en ? 'Clean car' : 'Auto limpio';
  String get water => _en ? 'Water' : 'Agua';
  String get music => _en ? 'Music' : 'Música';
  String get ratingLabel => _en ? 'Rating' : 'Calificación';

  // ── Earnings / Performance ────────────────────────
  String get todayEarnings => _en ? "Today's earnings" : 'Ingresos de hoy';
  String get bonuses => _en ? 'Bonuses' : 'Bonificaciones';
  String get inviteFriends => _en ? 'Invite friends' : 'Invita amigos';
  String get achievements => _en ? 'Achievements' : 'Logros';
  String get day => _en ? 'Day' : 'Día';
  String get week => _en ? 'Week' : 'Semana';
  String get month => _en ? 'Month' : 'Mes';
  String get earningsPlan => _en ? 'Earnings plan' : 'Plan de ingresos';
  String get requestHistory => _en ? 'Request history' : 'Historial de solicitudes';
  String get completed => _en ? 'Completed' : 'Completado';
  String get expired => _en ? 'Expired' : 'Expirado';

  // ── Notifications Screen ────────────────────────
  String get notifications => _en ? 'Notifications' : 'Notificaciones';
  String get loginToSeeNotifications => _en ? 'Log in to see notifications' : 'Inicia sesión para ver notificaciones';
  String get noNotifications => _en ? 'You have no notifications' : 'No tienes notificaciones';

  // ── Order History Screen ────────────────────────
  String get noRequestHistory => _en ? 'No request history' : 'Sin historial de solicitudes';
  String get allRequestsShownIn24h => _en
      ? 'All your previous requests will be shown here within 24 hours'
      : 'Todas tus solicitudes anteriores se mostrarán aquí dentro de 24 horas';
  String get rides => _en ? 'Rides' : 'Viajes';
  String get tripDetail => _en ? 'Trip detail' : 'Detalle del viaje';
  String get fare => _en ? 'Fare' : 'Tarifa';
  String get completedAt => _en ? 'Completed' : 'Completado';
  String get pickup => _en ? 'Pickup' : 'Recogida';

  // ── Month abbreviations ─────────────────────────
  List<String> get monthAbbreviations => _en
      ? ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec']
      : ['ene', 'feb', 'mar', 'abr', 'may', 'jun', 'jul', 'ago', 'sep', 'oct', 'nov', 'dic'];
  List<String> get monthNames => _en
      ? ['January', 'February', 'March', 'April', 'May', 'June', 'July', 'August', 'September', 'October', 'November', 'December']
      : ['enero', 'febrero', 'marzo', 'abril', 'mayo', 'junio', 'julio', 'agosto', 'septiembre', 'octubre', 'noviembre', 'diciembre'];

  // ── Benefits Screen ─────────────────────────────
  String get basic => _en ? 'Basic' : 'Básico';
  String get platinum => _en ? 'Platinum' : 'Platino';
  String get locked => _en ? 'Locked' : 'Bloqueado';
  String yourLevelUntil(String date) => _en ? 'Your level until $date' : 'Tu nivel hasta $date';
  String get wantPlatinum => _en ? 'Want to get\nPlatinum status?' : '¿Quieres obtener el\nestado Platino?';
  String complete60TripsBy(String date) => _en ? 'Complete 60 trips before $date' : 'Completa 60 viajes antes de $date';
  String tripsRemaining(int n) => _en ? '$n trips remaining' : '$n viajes restantes';
  String get keepRating480 => _en ? 'Keep rating 4.80' : 'Mantén la calificación 4.80';
  String yourRatingIs(String r) => _en ? 'Your rating is $r' : 'Tu calificación es $r';
  String get yourBenefits => _en ? 'Your benefits' : 'Tus beneficios';
  String get lowServicePayments => _en ? 'Low service payments' : 'Pagos por el servicio bajos';
  String get lowServicePaymentsDesc => _en ? 'Keep the majority of what you earn' : 'Conservas la mayor parte de lo que ganas';
  String get getMoreWithPlatinum => _en ? 'Get more income with\nPlatinum benefits' : 'Obtén más ingresos con los\nbeneficios Platino';
  String get firstToGetRequests => _en ? 'First to get requests' : 'Primero en obtener solicitudes';
  String get firstToGetRequestsDesc => _en
      ? 'See passenger requests before other drivers, 20% more requests'
      : 'Ver las solicitudes de pasajeros antes que otros conductores, 20% más solicitudes';
  String get highPrioritySupport => _en ? 'High priority support' : 'Soporte con prioridad alta';
  String get highPrioritySupportDesc => _en ? 'Faster help with any problem' : 'Ayuda más rápida con cualquier problema';
  String get autoAcceptRequests => _en ? 'Auto-accept requests' : 'Aceptación automática de solicitudes';
  String get autoAcceptRequestsDesc => _en ? 'Automatically accept the best requests' : 'Acepta automáticamente las mejores solicitudes';
  String get featuredProfile => _en ? 'Featured profile' : 'Perfil destacado';
  String get featuredProfileDesc => _en
      ? 'Passengers choose these drivers 15% more often'
      : 'Los pasajeros eligen a tales conductores un 15% más a menudo';
  String get partnerBonus => _en ? 'Partner bonus' : 'Bonus de socios';
  String get partnerBonusDesc => _en ? 'Enjoy discounts from our partners' : 'Disfruta descuentos de nuestros socios';
  String unlockPlatinumTrips(int n) => _en
      ? 'Unlock Platinum benefits — $n trips remaining'
      : 'Desbloquea beneficios Platino — faltan $n viajes';
  String get goToRequestList => _en ? 'Go to request list' : 'Ir a la lista de solicitudes';
  String get aboutRappiTeamLevels => _en ? 'About Rappi Team levels' : 'Acerca de los niveles de Rappi Team';
  String get viewBenefits => _en ? 'View benefits' : 'Ver beneficios';

  // ── Benefit Detail Screen ───────────────────────
  String get lowServicePaymentsDetailDesc => _en
      ? 'Keep the majority of what you earn. Our service payments are kept as low as possible for everyone, regardless of level'
      : 'Mantén la mayor parte de lo que ganas. Nuestros pagos de servicio se mantienen lo más bajos posible para todos, sin importar el nivel';
  String get firstToGetRequestsDetailDesc => _en
      ? 'See passenger requests before other drivers and get more trip opportunities'
      : 'Ve las solicitudes de los pasajeros antes que otros conductores y obtén más oportunidades de viajes';
  String get highPrioritySupportDetailDesc => _en
      ? 'Get faster help with any problem to minimize downtime and maintain productivity'
      : 'Obtén ayuda más rápida para cualquier problema y así minimizar el tiempo de inactividad y mantener la productividad';
  String get autoAcceptRequestsDetailDesc => _en
      ? 'Save time and focus on driving, the app will accept requests for you. You can enable or disable Auto-accept at any time'
      : 'Ahorra tiempo y concéntrate en conducir, la aplicación aceptará las solicitudes por ti. Puedes activar o desactivar la Aceptación automática en cualquier momento';
  String get featuredProfileDetailDesc => _en
      ? 'Increase your visibility to passengers and improve your chances of being selected for trips'
      : 'Aumenta tu visibilidad ante los pasajeros y mejora tus posibilidades de ser seleccionado para viajes';
  String get partnerBonusDetailDesc => _en
      ? 'Unlock exclusive discounts from our partners to reduce your costs and increase your income'
      : 'Desbloquea descuentos exclusivos de nuestros socios para reducir tus costos y aumentar tus ingresos';

  // ── Achievements Screen ─────────────────────────
  String get noAchievementsYet => _en ? 'No achievements yet' : 'Aún no tienes logros';
  String get completeTripsToUnlock => _en ? 'Complete trips to unlock bonuses' : 'Completa viajes para desbloquear bonificaciones';
  String bonusAmount(int amount) => _en ? 'S/$amount bonus' : 'S/$amount de bonificación';
  String get bonusObtained => _en ? 'Bonus obtained!' : '¡Bonificación obtenida!';
  String get bonusExpired => _en ? 'Bonus expired' : 'Bonificación expirada';
  String get tripsCompleted => _en ? 'Trips completed' : 'Viajes completados';
  String get completedRequiredTrips => _en
      ? 'You completed the required trips and earned the bonus.'
      : 'Completaste los viajes requeridos y obtuviste la bonificación.';
  String get didNotCompleteTrips => _en
      ? 'You did not complete the required trips before the deadline.'
      : 'No completaste los viajes requeridos antes de la fecha límite.';

  // ── Earnings Detail Screen ──────────────────────
  String get dailyIncomePlan => _en ? 'Daily income plan' : 'Plan de ingresos diarios';
  String remaining(int amount, int trips) => _en
      ? 'S/ $amount remaining (~$trips trips)'
      : 'S/ $amount restantes (~$trips viajes)';
  String get noCompletedRequests => _en ? 'No completed requests' : 'Solicitudes sin completar';
  String tripsCompletedCount(int n) => _en
      ? '$n trip${n == 1 ? '' : 's'} completed'
      : '$n viaje${n == 1 ? '' : 's'} completado${n == 1 ? '' : 's'}';
  String get requestHistoryShort => _en ? 'Ride request history...' : 'Historial de solicitudes de via...';
  String get objective => _en ? 'Objective' : 'Objetivo';

  // ── Performance Screen ──────────────────────────
  String get yourLevelThisWeek => _en ? 'Your level this week' : 'Tu nivel esta semana';
  String tripsToPlatinum(int n) => _en ? '$n trips to Platinum' : '$n viajes a Platino';
  String get keepRating480Plus => _en ? 'Keep rating 4.80+' : 'Mantén la calificación 4.80+';
  String get walletBalance => _en ? 'Wallet balance' : 'Saldo de la cartera';
  String get recharge => _en ? 'Recharge' : 'Recarga';
  String get bonifications => _en ? 'Bonuses' : 'Bonificaciones';
  String get inviteFriendsTitle => _en ? 'Invite friends to Rappi Team' : 'Invita amigos a Rappi Team';
  String get inviteFriendsDesc => _en
      ? 'Share your invitation code and get S/100 for each friend who registers as a driver.'
      : 'Comparte tu código de invitación y obtén S/100 por cada amigo que se registre como conductor.';
  String get invitationCodeCopied => _en ? 'Invitation code copied to clipboard' : 'Código de invitación copiado al portapapeles';
  String get shareCode => _en ? 'Share code' : 'Compartir código';
  String get getS100Each => _en ? 'get S/100 for each one' : 'obtén S/100 por cada uno';

  // ── Wallet Simple Screen ────────────────────────
  String get serviceCommission => _en ? 'Service commission' : 'Comisión del servicio';
  String serviceCommissionDesc(String rate) => _en
      ? 'Rappi Team charges a commission of $rate% per completed trip. This commission is automatically deducted from your balance.\n\nThis fee allows us to maintain the platform, provide support and continuously improve the service.'
      : 'Rappi Team cobra una comisión del $rate% por cada viaje completado. Esta comisión se descuenta automáticamente de tu saldo.\n\nEsta tarifa nos permite mantener la plataforma, brindar soporte y mejorar continuamente el servicio.';
  String serviceRateFair(String rate) => _en
      ? '$rate% — Rappi Team service payment is fair'
      : '$rate% — el pago por el servicio de Rappi Team es justo';
  String get walletBalanceTitle => _en ? 'Wallet balance' : 'Saldo de la cartera';
  String walletBalanceDesc(String _) => _en
      ? 'Your balance is the available credit to receive ride requests. Each time you complete a trip, the service commission is deducted from your balance.\n\nWhen your balance reaches S/ 0.00, you will not be able to receive new requests until you recharge.'
      : 'Tu saldo es el crédito disponible para recibir solicitudes de viaje. Cada vez que completas un viaje, se descuenta la comisión del servicio de tu saldo.\n\nCuando tu saldo llegue a S/ 0.00, no podrás recibir nuevas solicitudes hasta que recargues.';
  String get paymentMethods => _en ? 'Payment methods' : 'Métodos de pago';
  String get paymentMethodsDesc => _en
      ? 'Rappi Team accepts recharges through MercadoPago, which includes:\n\n• Credit and debit cards (Visa, Mastercard)\n• Yape\n• Bank transfers\n• PagoEfectivo (Tambo+, agents)'
      : 'Rappi Team acepta recargas a través de MercadoPago, que incluye:\n\n• Tarjetas de crédito y débito (Visa, Mastercard)\n• Yape\n• Transferencias bancarias\n• PagoEfectivo (Tambo+, agentes)';
  String get transactionHistory => _en ? 'Transaction history' : 'Historial de transacciones';
  String get transactionHistoryDesc => _en
      ? 'Here you can see the details of all your recharges and commission deductions for trips.\n\nEach transaction includes date, amount and type (recharge or commission deduction).'
      : 'Aquí podrás ver el detalle de todas tus recargas y descuentos por comisión de viajes.\n\nCada transacción incluye fecha, monto y tipo (recarga o descuento por comisión).';

  // ── Recharge Screen ─────────────────────────────
  String get paymentMethod => _en ? 'Payment method' : 'Método de pago';
  String get enterAmount => _en ? 'Enter amount' : 'Ingresa el monto';
  String approxTrips(int n) => _en ? '~$n trips' : '~$n viajes';
  String get tripCountApproximate => _en ? 'Trip count is approximate' : 'El número de viajes es aproximado';
  String get rechargeSafely => _en ? 'Recharge safely' : 'Recargar de manera segura';
  String get enterValidAmount => _en ? 'Enter a valid amount' : 'Ingresa un monto válido';
  String rechargeSuccess(int amount) => _en
      ? 'Recharge of S/ $amount successful. Your balance will update shortly.'
      : 'Recarga de S/ $amount exitosa. Tu saldo se actualizará en breve.';
  String get paymentPendingMsg => _en ? 'Payment pending. Your balance will update when confirmed.' : 'Pago pendiente. Tu saldo se actualizará cuando se confirme.';
  String get paymentNotApproved => _en ? 'Payment was not approved. Try again.' : 'El pago no fue aprobado. Intenta de nuevo.';
  String payAmount(int amount) => _en ? 'Pay S/ $amount' : 'Pagar S/ $amount';

  // ── Comfort Rules Screen (full content) ─────────
  String get comfortWelcomeTitle => _en ? 'Welcome\nto Comfort class!' : '¡Bienvenido\na la clase Confort!';
  String get comfortWelcomeDesc => _en
      ? 'Congratulations! Your car\'s brand, model and year meet Comfort class standards. Complete this training and a test to access lucrative requests in this category.'
      : '¡Felicidades! La marca, modelo y año de tu auto cumplen con los estándares de la clase Confort. Completa este entrenamiento y una prueba para acceder a solicitudes lucrativas en esta categoría.';
  String get comfortWelcomeSubtitle => _en ? 'It will take you 15 minutes or less' : 'Te tomará 15 minutos o menos';
  String get comfortAcTitle => _en ? 'Air conditioning\nalways on' : 'Aire acondicionado\nsiempre encendido';
  String get comfortAcDesc => _en
      ? 'On Comfort trips, the air conditioning must be on during the entire ride. Adjust the temperature according to the passenger\'s preference.'
      : 'En los viajes Confort, el aire acondicionado debe estar encendido durante todo el trayecto. Ajusta la temperatura según la preferencia del pasajero.';
  String get comfortCleanTitle => _en ? 'Clean car\ninside and out' : 'Auto limpio\npor dentro y fuera';
  String get comfortCleanDesc => _en
      ? 'Keep your vehicle spotless. Comfort passengers expect a clean car, no trash, pleasant scent and seats in good condition.'
      : 'Mantén tu vehículo impecable. Los pasajeros Confort esperan un auto limpio, sin basura, con buen aroma y asientos en buen estado.';
  String get comfortWaterTitle => _en ? 'Offer water\nto your passengers' : 'Ofrece agua\na tus pasajeros';
  String get comfortWaterDesc => _en
      ? 'Having a water bottle available for your passengers is a detail that makes a difference and improves your rating.'
      : 'Tener una botella de agua disponible para tus pasajeros es un detalle que marca la diferencia y mejora tu calificación.';
  String get comfortMusicTitle => _en ? 'Soft music\nor silence' : 'Música suave\no silencio';
  String get comfortMusicDesc => _en
      ? 'Ask the passenger if they want music. If you play it, keep the volume low. Many passengers prefer a quiet and peaceful ride.'
      : 'Pregunta al pasajero si desea música. Si la pones, que sea a volumen bajo. Muchos pasajeros prefieren un viaje silencioso y tranquilo.';
  String get comfortRatingTitle => _en ? 'Maintain a\nhigh rating' : 'Mantén una\ncalificación alta';
  String get comfortRatingDesc => _en
      ? 'To keep receiving Comfort requests, you need to maintain a rating of 4.80 or higher. Premium passengers expect exceptional service.'
      : 'Para seguir recibiendo solicitudes Confort, necesitas mantener una calificación de 4.80 o superior. Los pasajeros premium esperan un servicio excepcional.';
  String get comfortVehicleTitle => _en ? 'Vehicle\nrequirements' : 'Requisitos\ndel vehículo';
  String get comfortVehicleDesc => _en
      ? 'Your car must be no more than 5 years old, in excellent mechanical condition and have functional air conditioning.'
      : 'Tu auto debe tener máximo 5 años de antigüedad, estar en excelentes condiciones mecánicas y tener aire acondicionado funcional.';
  String get comfortDocsTitle => _en ? 'Documents\nup to date' : 'Documentos\nal día';
  String get comfortDocsDesc => _en
      ? 'Valid SOAT, approved technical inspection, category A-IIb driver\'s license and property card in your name or owner authorization.'
      : 'SOAT vigente, revisión técnica aprobada, licencia de conducir categoría A-IIb y tarjeta de propiedad a tu nombre o autorización del propietario.';
  String get comfortPresentationTitle => _en ? 'Personal\npresentation' : 'Presentación\npersonal';
  String get comfortPresentationDesc => _en
      ? 'Dress presentably. No uniform required, but clean and well-kept clothing. Your image is part of the Comfort experience.'
      : 'Viste de manera presentable. No se requiere uniforme, pero sí ropa limpia y en buen estado. Tu imagen es parte de la experiencia Confort.';
  String get comfortReadyTitle => _en ? 'Ready to\nget started!' : '¡Listo para\nempezar!';
  String get comfortReadyDesc => _en
      ? 'If you meet all these requirements, you can activate the Comfort service from your settings and start receiving better-paid requests.'
      : 'Si cumples con todos estos requisitos, ya puedes activar el servicio Confort desde tu configuración y comenzar a recibir solicitudes mejor pagadas.';

  // ── Communication Screen (hardcoded parts) ──────
  String get reportProblem => _en ? 'Report problem' : 'Reportar problema';
  String get aggressivePassenger => _en ? 'Aggressive passenger' : 'Pasajero agresivo';
  String get incorrectAddress => _en ? 'Incorrect address' : 'Dirección incorrecta';
  String get otherProblem => _en ? 'Other problem' : 'Otro problema';
  String get reportSent => _en ? 'Report sent. Thank you for letting us know.' : 'Reporte enviado. Gracias por informarnos.';
  String get blockUser => _en ? 'Block user' : 'Bloquear usuario';
  String blockUserConfirm(String name) => _en
      ? 'Are you sure you want to block $name? You will not receive more requests from this passenger.'
      : '¿Estás seguro de que quieres bloquear a $name? No recibirás más solicitudes de este pasajero.';
  String get block => _en ? 'Block' : 'Bloquear';
  String get userBlocked => _en ? 'User blocked' : 'Usuario bloqueado';
  String get numericKeypadNotAvailable => _en ? 'Numeric keypad not available in simulated calls' : 'Teclado numérico no disponible en llamadas simuladas';

  // ── Driver Home Screen ──────────────────────────
  String get city => _en ? 'City' : 'Ciudad';
  String get wallet => _en ? 'Wallet' : 'Cartera';
  // busy is defined in Freight section
  String get free => _en ? 'Free' : 'Libre';
  String get offline => _en ? 'Offline' : 'Fuera de línea';
  String get searchingRequests => _en ? 'Searching requests...' : 'Buscando solicitudes...';
  String get rideRequestsWillAppear => _en ? 'Ride requests will appear here' : 'Las solicitudes de viaje aparecerán aquí';
  String get youAreOffline => _en ? 'You are offline' : 'Estás fuera de línea';
  String get activateToReceive => _en ? 'Activate your status to receive requests' : 'Activa tu estado para recibir solicitudes';
  String get connect => _en ? 'Connect' : 'Conectarse';
  String get rideRequests => _en ? 'Ride requests' : 'Solicitudes de viaje';
  String get performanceTab => _en ? 'Performance' : 'Desempeño';
  String get pendingVerification => _en ? 'Pending Verification' : 'Verificación Pendiente';
  String get solveProblems => _en
      ? 'Solve these problems to avoid losing the best requests'
      : 'Resuelve estos problemas para evitar perder las mejores solicitudes';
  String get hide => _en ? 'Hide' : 'Ocultar';
  String get complaint => _en ? 'Complaint' : 'Queja';
  String get complaintSent => _en ? 'Complaint sent' : 'Queja enviada';
  String get fairPrice => _en ? 'Fair price' : 'Precio justo';
  String get rideRequest => _en ? 'Ride request' : 'Solicitud de viaje';
  String get offerYourFare => _en ? 'Offer your fare' : 'Ofrece tu tarifa';
  String get acceptFor => _en ? 'Accept for' : 'Aceptar por';
  String get skip => _en ? 'Skip' : 'Omitir';
  String get selectOnMap => _en ? 'Select on\nmap' : 'Seleccionar en\nel mapa';
  String get negotiate => _en ? 'Negotiate' : 'Negociar';
  String get makeCounterOffer => _en ? 'Make counter-offer' : 'Hacer contra-oferta';
  String passengerPrice(String price) => _en ? 'Passenger price: S/ $price' : 'Precio del pasajero: S/ $price';
  String get yourOffer2 => _en ? 'Your offer' : 'Tu oferta';
  String get counterOffer => _en ? 'Counter-offer' : 'Contraoferta';
  String get reject => _en ? 'Reject' : 'Rechazar';
  String acceptPrice(String price) => _en ? 'Accept S/ $price' : 'Aceptar S/ $price';
  String get invalidPrice => _en ? 'Invalid price' : 'Precio inválido';
  String get rechargeWallet => _en ? 'Recharge your wallet to continue operating.' : 'Recarga tu billetera para continuar operando.';
  String get goToWallet => _en ? 'Go to Wallet' : 'Ir a Billetera';
  String get nowLabel => _en ? 'Now' : 'Ahora\nmismo';
  String get cash => _en ? 'Cash' : 'Efectivo';
  String get card => _en ? 'Card' : 'Tarjeta';
  String get walletPay => _en ? 'Wallet' : 'Billetera';
  String get insufficientBalance => _en ? 'Insufficient balance' : 'Saldo insuficiente';
  String minimumBalanceRequired(String symbol, String amount) => _en
      ? 'You need a minimum balance of $symbol $amount to accept trips.'
      : 'Necesitas un saldo mínimo de $symbol $amount para poder aceptar viajes.';

  // ── Offering overlay ──────────────────────────────
  String get offeringYourFare => _en ? 'Offering your fare' : 'Ofreciendo tu tarifa';
  String get waitForResponse => _en ? 'Wait for the passenger\'s response' : 'Espera la respuesta del pasajero';
  String get offerSent => _en ? 'Offer sent' : 'Oferta enviada';
  String get cancelOffer => _en ? 'Cancel offer' : 'Cancelar oferta';
  String get passengerAccepted => _en ? 'Passenger accepted your offer!' : '¡El pasajero aceptó tu oferta!';
  String get passengerDeclined => _en ? 'Passenger declined your offer' : 'El pasajero rechazó tu oferta';
}

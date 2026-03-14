/// State machine for the passenger ride flow.
/// Replaces the multiple boolean flags (_isWaitingForDriver,
/// _showPriceNegotiation, _showDriverOffers, _isAdjustingPickup)
/// ensuring only one state is active at a time.
enum PassengerFlowState {
  /// Default: showing search bar, services, favorites
  idle,

  /// User is typing/selecting origin and destination
  searchingRoute,

  /// User is dragging the map to fine-tune pickup location
  adjustingPickup,

  /// Route confirmed, user is setting price
  confirmingPrice,

  /// Ride request sent, waiting for driver offers
  searchingDrivers,

  /// One or more driver offers have arrived
  viewingOffers,

  /// A driver accepted and is on the way
  driverAccepted,
}

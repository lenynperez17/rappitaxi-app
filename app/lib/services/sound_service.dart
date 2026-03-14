import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';

enum AppSound {
  rideRequest,
  rideAccepted,
  driverArrived,
  chatMessage,
  timerExpired,
  tripCompleted,
  emergency,
}

class SoundService {
  static final SoundService _instance = SoundService._internal();
  factory SoundService() => _instance;
  SoundService._internal();

  final AudioPlayer _player = AudioPlayer();
  bool _enabled = true;

  static const Map<AppSound, String> _soundFiles = {
    AppSound.rideRequest: 'sounds/ride_request.wav',
    AppSound.rideAccepted: 'sounds/ride_accepted.wav',
    AppSound.driverArrived: 'sounds/driver_arrived.wav',
    AppSound.chatMessage: 'sounds/chat_message.wav',
    AppSound.timerExpired: 'sounds/timer_expired.wav',
    AppSound.tripCompleted: 'sounds/trip_completed.wav',
    AppSound.emergency: 'sounds/emergency_alert.wav',
  };

  bool get enabled => _enabled;

  void setEnabled(bool value) {
    _enabled = value;
  }

  Future<void> play(AppSound sound) async {
    if (!_enabled) return;

    try {
      final file = _soundFiles[sound];
      if (file == null) return;

      await _player.stop();
      await _player.play(AssetSource(file));

      // Haptic feedback for important events
      switch (sound) {
        case AppSound.rideRequest:
        case AppSound.emergency:
          HapticFeedback.heavyImpact();
          break;
        case AppSound.rideAccepted:
        case AppSound.tripCompleted:
          HapticFeedback.mediumImpact();
          break;
        case AppSound.driverArrived:
        case AppSound.timerExpired:
          HapticFeedback.lightImpact();
          break;
        case AppSound.chatMessage:
          HapticFeedback.selectionClick();
          break;
      }
    } catch (e) {
      debugPrint('SoundService error: $e');
      // Fallback to haptic only
      HapticFeedback.mediumImpact();
    }
  }

  Future<void> dispose() async {
    await _player.dispose();
  }
}

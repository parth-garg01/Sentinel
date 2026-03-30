import 'package:geolocator/geolocator.dart';

/// Service for obtaining device GPS coordinates.
///
/// Handles permission negotiation transparently.
/// Always returns null instead of throwing on failure — evidence capture
/// must never be blocked by a location error.
class LocationService {
  /// Attempt to get the device's current position.
  ///
  /// Returns a [Position] on success, or null if:
  ///   - Permission is denied permanently
  ///   - Location services are disabled
  ///   - Timeout exceeded (8s)
  static Future<Position?> getCurrentPosition() async {
    try {
      // Check if location services are enabled at the OS level
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return null;

      // Check and request permission
      LocationPermission permission = await Geolocator.checkPermission();

      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) return null;
      }

      if (permission == LocationPermission.deniedForever) return null;

      // Fetch position with a sensible timeout
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium, // Faster + sufficient for mapping
          timeLimit: Duration(seconds: 8),
        ),
      );

      return position;
    } catch (_) {
      // Swallow all errors — location is best-effort, not blocking
      return null;
    }
  }

  /// Quick helper: returns just lat/lon as a readable string.
  static String formatPosition(Position position) {
    return '${position.latitude.toStringAsFixed(5)}, '
        '${position.longitude.toStringAsFixed(5)}';
  }
}

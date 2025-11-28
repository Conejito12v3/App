import 'dart:async';
import 'package:geolocator/geolocator.dart';
import 'package:app_g/utils/logger.dart';

class GeoService {
  /// Obtiene la ubicación inmediata sin iniciar un rastreo continuo.
  static Future<Position?> getImmediateLocation() async {
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied ||
            permission == LocationPermission.deniedForever) {
          logger.w("Permiso de ubicación denegado.");
          return null;
        }
      }

      try {
        // Intento principal
        return await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.bestForNavigation,
          timeLimit: const Duration(seconds: 10),
        );
      } on TimeoutException {
        logger.w("⚠️ Timeout al obtener posición, usando la última conocida.");
        // Fallback a la última ubicación conocida
        return await Geolocator.getLastKnownPosition();
      }
    } catch (e) {
      logger.e("❌ Error obteniendo ubicación inmediata: $e");
      return null;
    }
  }

  static double calcularDistancia(
      double startLat,
      double startLon,
      double endLat,
      double endLon,
  ) {
    try {
      final distance = Geolocator.distanceBetween(
        startLat,
        startLon,
        endLat,
        endLon,
      );
      return distance; // en metros
    } catch (e) {
      logger.e("Error calculando distancia: $e");
      return -1;
    }
  }
}

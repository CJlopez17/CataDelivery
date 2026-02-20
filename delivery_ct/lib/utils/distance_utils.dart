import 'dart:math';

/// Utilidades para cálculos de distancia geográfica y delivery fee
class DistanceUtils {
  /// Calcula la distancia en kilómetros entre dos puntos geográficos
  /// usando la fórmula de Haversine.
  ///
  /// Parámetros:
  ///   - lat1: Latitud del primer punto
  ///   - lon1: Longitud del primer punto
  ///   - lat2: Latitud del segundo punto
  ///   - lon2: Longitud del segundo punto
  ///
  /// Retorna:
  ///   Distancia en kilómetros (double)
  static double haversineDistance(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    // Radio de la Tierra en kilómetros
    const double earthRadius = 6371.0;

    // Convertir grados a radianes
    final lat1Rad = _degreesToRadians(lat1);
    final lon1Rad = _degreesToRadians(lon1);
    final lat2Rad = _degreesToRadians(lat2);
    final lon2Rad = _degreesToRadians(lon2);

    // Diferencias
    final dLat = lat2Rad - lat1Rad;
    final dLon = lon2Rad - lon1Rad;

    // Fórmula de Haversine
    final a = pow(sin(dLat / 2), 2) +
        cos(lat1Rad) * cos(lat2Rad) * pow(sin(dLon / 2), 2);
    final c = 2 * atan2(sqrt(a), sqrt(1 - a));

    final distance = earthRadius * c;
    return distance;
  }

  /// Calcula el costo de envío (delivery fee) basándose en la distancia
  /// entre el local comercial y la dirección de entrega.
  ///
  /// Regla de negocio: $0.10 USD por cada 100 metros recorridos.
  ///
  /// Parámetros:
  ///   - storeLat: Latitud del local comercial
  ///   - storeLon: Longitud del local comercial
  ///   - deliveryLat: Latitud de la dirección de entrega
  ///   - deliveryLon: Longitud de la dirección de entrega
  ///
  /// Retorna:
  ///   Costo de envío en USD (double)
  ///
  /// Ejemplo:
  ///   - Distancia: 2.5 km = 2500 metros
  ///   - 2500 metros / 100 = 25 segmentos
  ///   - 25 segmentos * $0.10 = $2.50 USD
  static double calculateDeliveryFee(
    double storeLat,
    double storeLon,
    double deliveryLat,
    double deliveryLon,
  ) {
    // Calcular distancia en kilómetros
    final distanceKm = haversineDistance(
      storeLat,
      storeLon,
      deliveryLat,
      deliveryLon,
    );

    // Convertir a metros y calcular segmentos de 100 metros
    final distanceMeters = distanceKm * 1000;
    final segments = distanceMeters / 100;

    // Calcular costo: $0.10 por cada segmento de 100 metros
    final deliveryFee = segments * 0.10;

    // Redondear a 2 decimales
    return double.parse(deliveryFee.toStringAsFixed(2));
  }

  /// Convierte grados a radianes
  static double _degreesToRadians(double degrees) {
    return degrees * pi / 180.0;
  }

  /// Formatea la distancia para mostrarla al usuario
  ///
  /// Parámetros:
  ///   - distanceKm: Distancia en kilómetros
  ///
  /// Retorna:
  ///   String formateado (ej: "2.5 km" o "850 m")
  static String formatDistance(double distanceKm) {
    if (distanceKm < 1.0) {
      final meters = (distanceKm * 1000).round();
      return "$meters m";
    } else {
      return "${distanceKm.toStringAsFixed(1)} km";
    }
  }

  /// Formatea el precio en USD
  ///
  /// Parámetros:
  ///   - price: Precio en USD
  ///
  /// Retorna:
  ///   String formateado (ej: "$2.50")
  static String formatPrice(double price) {
    return "\$${price.toStringAsFixed(2)}";
  }
}

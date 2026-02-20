import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:delivery_ct_admin/config/env.dart';

/// Servicio para obtener y enviar la ubicación del repartidor al backend
/// Se ejecuta periódicamente para mantener actualizada la posición GPS
class LocationService {
  static final LocationService _instance = LocationService._internal();
  factory LocationService() => _instance;
  LocationService._internal();

  Timer? _locationTimer;
  bool _isRunning = false;
  Position? _lastPosition;
  DateTime? _lastUpdateTime;

  /// Duración entre actualizaciones de ubicación (3 minutos)
  static const Duration updateInterval = Duration(minutes: 3);

  /// Precisión mínima requerida (en metros)
  static const double minAccuracy = 100.0;

  /// Indica si el servicio está actualmente enviando actualizaciones
  bool get isRunning => _isRunning;

  /// Última posición conocida
  Position? get lastPosition => _lastPosition;

  /// Hora de la última actualización exitosa
  DateTime? get lastUpdateTime => _lastUpdateTime;

  /// Inicia el servicio de actualización periódica de ubicación
  ///
  /// Parámetros:
  ///   - immediate: Si es true, envía la ubicación inmediatamente antes de iniciar el timer
  Future<bool> startLocationUpdates({bool immediate = true}) async {
    if (_isRunning) {
      debugPrint('📍 [LocationService] El servicio ya está en ejecución');
      return true;
    }

    // Verificar permisos antes de iniciar
    final hasPermission = await _checkLocationPermission();
    if (!hasPermission) {
      debugPrint('❌ [LocationService] No hay permisos de ubicación');
      return false;
    }

    debugPrint('🚀 [LocationService] Iniciando servicio de actualización de ubicación');
    _isRunning = true;

    // Enviar ubicación inmediatamente si se solicita
    if (immediate) {
      await updateLocation();
    }

    // Configurar timer para actualizaciones periódicas
    _locationTimer = Timer.periodic(updateInterval, (timer) async {
      await updateLocation();
    });

    debugPrint('✅ [LocationService] Servicio iniciado. Actualizaciones cada ${updateInterval.inMinutes} minutos');
    return true;
  }

  /// Detiene el servicio de actualización periódica
  void stopLocationUpdates() {
    if (!_isRunning) {
      debugPrint('⚠️ [LocationService] El servicio no está en ejecución');
      return;
    }

    debugPrint('🛑 [LocationService] Deteniendo servicio de actualización de ubicación');
    _locationTimer?.cancel();
    _locationTimer = null;
    _isRunning = false;
    debugPrint('✅ [LocationService] Servicio detenido');
  }

  /// Obtiene la ubicación actual y la envía al backend
  ///
  /// Retorna true si la actualización fue exitosa, false en caso contrario
  Future<bool> updateLocation() async {
    try {
      debugPrint('📡 [LocationService] Obteniendo ubicación GPS...');

      // Obtener posición actual
      final position = await _getCurrentPosition();
      if (position == null) {
        debugPrint('❌ [LocationService] No se pudo obtener la posición GPS');
        return false;
      }

      _lastPosition = position;

      // Validar precisión
      if (position.accuracy > minAccuracy) {
        debugPrint(
          '⚠️ [LocationService] Precisión insuficiente: ${position.accuracy.toStringAsFixed(1)}m (mín: ${minAccuracy}m)',
        );
        // Aún así enviar, pero registrar advertencia
      }

      debugPrint(
        '📍 [LocationService] Ubicación obtenida: (${position.latitude.toStringAsFixed(6)}, ${position.longitude.toStringAsFixed(6)}) ±${position.accuracy.toStringAsFixed(1)}m',
      );

      // Enviar al backend
      final success = await _sendLocationToBackend(position);

      if (success) {
        _lastUpdateTime = DateTime.now();
        debugPrint('✅ [LocationService] Ubicación actualizada exitosamente en el servidor');
      } else {
        debugPrint('❌ [LocationService] Error al actualizar ubicación en el servidor');
      }

      return success;
    } catch (e, stackTrace) {
      debugPrint('❌ [LocationService] Error al actualizar ubicación: $e');
      debugPrint('Stack trace: $stackTrace');
      return false;
    }
  }

  /// Verifica si el usuario tiene permisos de ubicación
  Future<bool> _checkLocationPermission() async {
    // Verificar si el servicio de ubicación está habilitado
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      debugPrint('❌ [LocationService] Servicio de ubicación deshabilitado');
      return false;
    }

    // Verificar permisos
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        debugPrint('❌ [LocationService] Permisos de ubicación denegados');
        return false;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      debugPrint('❌ [LocationService] Permisos de ubicación denegados permanentemente');
      return false;
    }

    return true;
  }

  /// Obtiene la posición GPS actual del dispositivo
  Future<Position?> _getCurrentPosition() async {
    try {
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: 10, // Actualizar solo si se mueve al menos 10 metros
        ),
      );
      return position;
    } catch (e) {
      debugPrint('❌ [LocationService] Error obteniendo posición: $e');
      return null;
    }
  }

  /// Envía la ubicación al endpoint del backend
  Future<bool> _sendLocationToBackend(Position position) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString("accessToken");

      if (token == null) {
        debugPrint('❌ [LocationService] No hay token de autenticación');
        return false;
      }

      final url = Uri.parse("${ENV.API_URL}/api/users/update_location/");

      debugPrint('🌐 [LocationService] Enviando a: $url');
      debugPrint('📤 [LocationService] Datos: lat=${position.latitude}, lon=${position.longitude}');

      final response = await http
          .post(
            url,
            headers: {"Content-Type": "application/json", "Authorization": "Bearer $token"},
            body: jsonEncode({"latitude": position.latitude, "longitude": position.longitude}),
          )
          .timeout(
            const Duration(seconds: 10),
            onTimeout: () {
              throw TimeoutException('Request timeout');
            },
          );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        debugPrint('✅ [LocationService] Respuesta del servidor: ${data['detail']}');
        return true;
      } else {
        debugPrint('❌ [LocationService] Error del servidor: ${response.statusCode}');
        debugPrint('Response body: ${response.body}');
        return false;
      }
    } catch (e) {
      debugPrint('❌ [LocationService] Error en request HTTP: $e');
      return false;
    }
  }

  /// Reinicia el servicio (útil al cambiar estado de disponibilidad)
  Future<bool> restart() async {
    stopLocationUpdates();
    return await startLocationUpdates(immediate: true);
  }
}

class TimeoutException implements Exception {
  final String message;
  TimeoutException(this.message);

  @override
  String toString() => message;
}

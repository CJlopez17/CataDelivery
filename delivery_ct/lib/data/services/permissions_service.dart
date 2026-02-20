import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// Estados posibles del permiso de ubicación
enum LocationPermissionStatus {
  granted,
  denied,
  permanentlyDenied,
  serviceDisabled,
}

/// Resultado de la verificación de permisos
class PermissionCheckResult {
  final bool locationGranted;
  final bool notificationGranted;
  final bool userDenied; // true si el usuario rechazó el diálogo educativo

  PermissionCheckResult({
    required this.locationGranted,
    required this.notificationGranted,
    this.userDenied = false,
  });
}

/// Servicio completo para manejar permisos de ubicación y notificaciones
class PermissionsService {
  static const String _firstLaunchKey = 'permissions_first_launch_completed';
  static const String _lastWarningKey = 'permissions_last_warning_timestamp';
  static const Duration _warningCooldown = Duration(hours: 1);

  final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();

  // ========== PRIMER LANZAMIENTO ==========

  /// Verifica si es el primer lanzamiento de la app después del login
  Future<bool> isFirstLaunch() async {
    final prefs = await SharedPreferences.getInstance();
    return !(prefs.getBool(_firstLaunchKey) ?? false);
  }

  /// Marca el primer lanzamiento como completado
  Future<void> markFirstLaunchCompleted() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_firstLaunchKey, true);
  }

  /// Resetea el estado de primer lanzamiento (útil para logout)
  Future<void> resetFirstLaunch() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_firstLaunchKey);
    await prefs.remove(_lastWarningKey);
  }

  // ========== VERIFICACIÓN DE PERMISOS ==========

  /// Verifica el estado del permiso de ubicación
  Future<LocationPermissionStatus> checkLocationPermission() async {
    // Verificar si el servicio de ubicación está habilitado
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return LocationPermissionStatus.serviceDisabled;
    }

    // Verificar el permiso
    final permission = await Geolocator.checkPermission();

    switch (permission) {
      case LocationPermission.always:
      case LocationPermission.whileInUse:
        return LocationPermissionStatus.granted;
      case LocationPermission.deniedForever:
        return LocationPermissionStatus.permanentlyDenied;
      case LocationPermission.denied:
      case LocationPermission.unableToDetermine:
        return LocationPermissionStatus.denied;
    }
  }

  /// Verifica si se debe mostrar la advertencia de ubicación desactivada
  Future<bool> shouldShowLocationWarning() async {
    // Verificar estado de ubicación
    final status = await checkLocationPermission();
    if (status == LocationPermissionStatus.granted) {
      return false; // No mostrar advertencia si ya está concedido
    }

    // Verificar cooldown (no mostrar más de 1 vez por hora)
    final prefs = await SharedPreferences.getInstance();
    final lastWarning = prefs.getInt(_lastWarningKey);

    if (lastWarning != null) {
      final lastWarningTime = DateTime.fromMillisecondsSinceEpoch(lastWarning);
      final now = DateTime.now();
      if (now.difference(lastWarningTime) < _warningCooldown) {
        return false; // Aún en cooldown
      }
    }

    return true; // Debe mostrar advertencia
  }

  /// Actualiza el timestamp de la última advertencia mostrada
  Future<void> _updateLastWarningTimestamp() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_lastWarningKey, DateTime.now().millisecondsSinceEpoch);
  }

  // ========== SOLICITUD DE PERMISOS ==========

  /// Solicita el permiso de ubicación
  Future<bool> requestLocationPermission() async {
    // Primero verificar si el servicio está habilitado
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return false;
    }

    // Solicitar permiso
    final permission = await Geolocator.requestPermission();

    return permission == LocationPermission.always ||
        permission == LocationPermission.whileInUse;
  }

  /// Solicita el permiso de notificaciones
  Future<bool> requestNotificationPermission() async {
    final permission = await Permission.notification.request();
    return permission.isGranted;
  }

  /// Verifica y solicita ambos permisos (ubicación y notificaciones)
  Future<PermissionCheckResult> checkAndRequestPermissions(
    BuildContext context, {
    bool isFirstTime = false,
  }) async {
    // Si es la primera vez, mostrar diálogo educativo
    if (isFirstTime) {
      final userAccepted = await showFirstTimePermissionsDialog(context);
      if (!userAccepted) {
        return PermissionCheckResult(
          locationGranted: false,
          notificationGranted: false,
          userDenied: true,
        );
      }
    }

    // Solicitar permisos
    final locationGranted = await requestLocationPermission();
    final notificationGranted = await requestNotificationPermission();

    return PermissionCheckResult(
      locationGranted: locationGranted,
      notificationGranted: notificationGranted,
      userDenied: false,
    );
  }

  // ========== DIÁLOGOS UI ==========

  /// Muestra un diálogo educativo explicando por qué se necesitan los permisos
  Future<bool> showFirstTimePermissionsDialog(BuildContext context) async {
    return await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (BuildContext context) {
            return AlertDialog(
              title: Row(
                children: [
                  Icon(Icons.security, color: Theme.of(context).primaryColor),
                  const SizedBox(width: 10),
                  const Expanded(child: Text('Permisos Necesarios')),
                ],
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'Para ofrecerte la mejor experiencia, necesitamos los siguientes permisos:',
                      style: TextStyle(fontSize: 15),
                    ),
                    const SizedBox(height: 20),
                    _buildPermissionItem(
                      Icons.location_on,
                      'Ubicación',
                      'Para mostrarte restaurantes cercanos y calcular tiempos de entrega',
                      const Color(0xFF2563EB),
                    ),
                    const SizedBox(height: 15),
                    _buildPermissionItem(
                      Icons.notifications,
                      'Notificaciones',
                      'Para mantenerte informado sobre el estado de tus pedidos',
                      const Color(0xFFFF6F3C),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: const Text('Ahora no'),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2563EB),
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Permitir'),
                ),
              ],
            );
          },
        ) ??
        false;
  }

  /// Widget helper para mostrar un item de permiso
  Widget _buildPermissionItem(
      IconData icon, String title, String description, Color color) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: color, size: 24),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                description,
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// Muestra una advertencia cuando los permisos están desactivados
  Future<void> showPermissionWarning(
    BuildContext context, {
    required String title,
    required String message,
  }) async {
    await _updateLastWarningTimestamp();

    final status = await checkLocationPermission();

    await showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Row(
            children: [
              Icon(Icons.warning, color: Colors.orange[700]),
              const SizedBox(width: 10),
              Expanded(child: Text(title)),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(message),
              const SizedBox(height: 10),
              if (status == LocationPermissionStatus.serviceDisabled)
                const Text(
                  'El servicio de ubicación está desactivado. Por favor, actívalo en la configuración del dispositivo.',
                  style: TextStyle(fontStyle: FontStyle.italic),
                ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Ahora no'),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.of(context).pop();

                // Abrir configuración según el estado
                if (status == LocationPermissionStatus.serviceDisabled) {
                  await Geolocator.openLocationSettings();
                } else if (status == LocationPermissionStatus.permanentlyDenied) {
                  await openAppSettings();
                } else {
                  await requestLocationPermission();
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2563EB),
                foregroundColor: Colors.white,
              ),
              child: const Text('Ir a Configuración'),
            ),
          ],
        );
      },
    );
  }
}

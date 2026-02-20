import 'package:delivery_ct_admin/data/services/permissions_service.dart';
import 'package:flutter/material.dart';

/// Helper class para facilitar la integración del PermissionsService
/// en las pantallas de login, register y home.
class PermissionsHelper {
  static final PermissionsService _permissionsService = PermissionsService();

  /// Maneja los permisos después del login/registro exitoso.
  ///
  /// Si es la primera vez que el usuario abre la app:
  /// 1. Muestra un diálogo educativo explicando los permisos
  /// 2. Solicita permisos de ubicación y notificaciones
  /// 3. Marca como completado
  ///
  /// Ejemplo de uso en login.dart:
  /// ```dart
  /// if (mounted) {
  ///   await PermissionsHelper.handlePostLoginPermissions(context);
  /// }
  /// ```
  static Future<void> handlePostLoginPermissions(BuildContext context) async {
    final isFirstTime = await _permissionsService.isFirstLaunch();

    if (isFirstTime) {
      // Solicitar permisos en primer lanzamiento
      final result = await _permissionsService.checkAndRequestPermissions(
        context,
        isFirstTime: true,
      );

      // Solo marcar como completado si el usuario aceptó el diálogo
      if (result.locationGranted || result.notificationGranted) {
        await _permissionsService.markFirstLaunchCompleted();
      }

      // Mostrar advertencia si no se concedieron permisos (y el usuario no rechazó explícitamente)
      if (!result.locationGranted && !result.userDenied) {
        if (!context.mounted) return;

        await _permissionsService.showPermissionWarning(
          context,
          title: 'Permisos de Ubicación',
          message: 'Para una mejor experiencia, activa los permisos de ubicación en la configuración.',
        );
      }
    }
  }

  /// Verifica permisos cuando la app se reanuda (app resume).
  ///
  /// Muestra un diálogo de advertencia si:
  /// - Los permisos de ubicación están desactivados
  /// - No se ha mostrado el diálogo recientemente (cooldown de 1 hora)
  ///
  /// Ejemplo de uso en home_delivery.dart:
  /// ```dart
  /// @override
  /// void initState() {
  ///   super.initState();
  ///   WidgetsBinding.instance.addPostFrameCallback((_) {
  ///     PermissionsHelper.checkLocationOnAppResume(context);
  ///   });
  /// }
  /// ```
  static Future<void> checkLocationOnAppResume(BuildContext context) async {
    final shouldWarn = await _permissionsService.shouldShowLocationWarning();

    if (shouldWarn && context.mounted) {
      await _permissionsService.showPermissionWarning(
        context,
        title: 'Ubicación Desactivada',
        message: 'Activa tu ubicación para recibir pedidos cercanos y optimizar entregas.',
      );
    }
  }

  /// Resetea el estado de "primer lanzamiento" cuando el usuario cierra sesión.
  ///
  /// Esto permite que el próximo usuario que inicie sesión vea el diálogo
  /// de permisos en su primer lanzamiento.
  ///
  /// Ejemplo de uso en profile_delivery.dart:
  /// ```dart
  /// Future<void> logout() async {
  ///   // ... limpiar datos de sesión
  ///   await PermissionsHelper.resetOnLogout();
  /// }
  /// ```
  static Future<void> resetOnLogout() async {
    await _permissionsService.resetFirstLaunch();
  }
}

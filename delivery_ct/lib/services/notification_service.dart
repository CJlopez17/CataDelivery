import 'dart:convert';
import 'dart:io';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../config/env.dart';

/// Manejador global para mensajes en background
/// DEBE estar en el nivel superior (fuera de clases)
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  print('📨 [FCM Background] Mensaje recibido: ${message.messageId}');
  print('   Título: ${message.notification?.title}');
  print('   Cuerpo: ${message.notification?.body}');
}

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  /// Callback cuando se toca una notificación
  /// Se configurará desde main.dart
  Function(String route, Map<String, dynamic> data)? onNotificationTap;

  bool _initialized = false;

  /// Inicializa Firebase Cloud Messaging y notificaciones locales
  Future<void> initialize() async {
    if (_initialized) {
      print('ℹ️ [FCM] Ya estaba inicializado');
      return;
    }

    try {
      print('🔧 [FCM] Inicializando servicio de notificaciones...');

      // 1. Inicializar Firebase si no está inicializado
      if (!Firebase.apps.isNotEmpty) {
        await Firebase.initializeApp();
        print('✓ [FCM] Firebase inicializado');
      }

      // 2. Solicitar permisos (iOS y Android 13+)
      await _requestPermissions();

      // 3. Configurar notificaciones locales
      await _setupLocalNotifications();

      // 4. Configurar manejadores de mensajes FCM
      _setupFCMHandlers();

      // 5. Obtener y registrar token FCM
      await _registerFCMToken();

      // 6. Configurar listener de cambios de token
      _firebaseMessaging.onTokenRefresh.listen((newToken) {
        print('🔄 [FCM] Token actualizado: ${newToken.substring(0, 20)}...');
        _saveAndSendToken(newToken);
      });

      _initialized = true;
      print('✅ [FCM] Servicio de notificaciones inicializado correctamente');
    } catch (e) {
      print('❌ [FCM] Error al inicializar: $e');
    }
  }

  /// Solicita permisos de notificaciones
  Future<void> _requestPermissions() async {
    print('📲 [FCM] Solicitando permisos de notificaciones...');

    NotificationSettings settings = await _firebaseMessaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      announcement: false,
      carPlay: false,
      criticalAlert: false,
      provisional: false,
    );

    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      print('✓ [FCM] Permisos concedidos');
    } else if (settings.authorizationStatus == AuthorizationStatus.provisional) {
      print('⚠️ [FCM] Permisos provisionales concedidos');
    } else {
      print('⚠️ [FCM] Permisos denegados');
    }
  }

  /// Configura notificaciones locales para Android
  Future<void> _setupLocalNotifications() async {
    print('🔔 [FCM] Configurando notificaciones locales...');

    // Configuración Android
    const AndroidInitializationSettings androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    // Configuración iOS
    const DarwinInitializationSettings iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const InitializationSettings initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _localNotifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (NotificationResponse details) {
        print('👆 [FCM] Notificación tocada: ${details.payload}');
        _handleNotificationTap(details.payload);
      },
    );

    // Crear canal de notificación Android
    if (Platform.isAndroid) {
      const AndroidNotificationChannel channel = AndroidNotificationChannel(
        'order_updates', // ID del canal
        'Actualizaciones de Pedidos', // Nombre
        description: 'Notificaciones sobre el estado de tus pedidos',
        importance: Importance.high,
        enableVibration: true,
        playSound: true,
      );

      await _localNotifications
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(channel);

      print('✓ [FCM] Canal Android creado: order_updates');
    }
  }

  /// Configura los manejadores de mensajes FCM
  void _setupFCMHandlers() {
    print('⚙️ [FCM] Configurando manejadores de mensajes...');

    // Mensajes en FOREGROUND (app abierta)
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      print('📨 [FCM Foreground] Mensaje recibido');
      print('   Título: ${message.notification?.title}');
      print('   Cuerpo: ${message.notification?.body}');
      print('   Data: ${message.data}');

      // Mostrar notificación local
      _showLocalNotification(message);
    });

    // Mensajes cuando app se abre desde BACKGROUND
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      print('👆 [FCM] App abierta desde notificación');
      print('   Data: ${message.data}');
      _handleNotificationData(message.data);
    });

    // Mensaje en BACKGROUND/TERMINATED
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

    // Verificar si hay mensaje inicial (app iniciada desde notificación)
    _checkInitialMessage();
  }

  /// Verifica si la app se inició tocando una notificación
  Future<void> _checkInitialMessage() async {
    RemoteMessage? initialMessage =
        await _firebaseMessaging.getInitialMessage();

    if (initialMessage != null) {
      print('🚀 [FCM] App iniciada desde notificación');
      print('   Data: ${initialMessage.data}');
      // Esperar un poco para que la app termine de inicializar
      Future.delayed(const Duration(seconds: 1), () {
        _handleNotificationData(initialMessage.data);
      });
    }
  }

  /// Muestra notificación local cuando la app está en foreground
  Future<void> _showLocalNotification(RemoteMessage message) async {
    RemoteNotification? notification = message.notification;
    AndroidNotification? android = message.notification?.android;

    if (notification == null) return;

    // Serializar data a JSON string para el payload
    String payload = jsonEncode(message.data);

    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'order_updates',
      'Actualizaciones de Pedidos',
      channelDescription: 'Notificaciones sobre el estado de tus pedidos',
      importance: Importance.high,
      priority: Priority.high,
      color: Color(0xFF2563EB), // Azul principal
      icon: '@mipmap/ic_launcher',
      enableVibration: true,
      playSound: true,
    );

    const DarwinNotificationDetails iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const NotificationDetails notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _localNotifications.show(
      message.hashCode,
      notification.title,
      notification.body,
      notificationDetails,
      payload: payload,
    );

    print('✓ [FCM] Notificación local mostrada');
  }

  /// Maneja el tap en notificación (desde payload)
  void _handleNotificationTap(String? payload) {
    if (payload == null || payload.isEmpty) return;

    try {
      Map<String, dynamic> data = jsonDecode(payload);
      _handleNotificationData(data);
    } catch (e) {
      print('❌ [FCM] Error al parsear payload: $e');
    }
  }

  /// Maneja los datos de la notificación y navega
  void _handleNotificationData(Map<String, dynamic> data) {
    print('🔍 [FCM] Procesando datos de notificación: $data');

    String type = data['type'] ?? '';
    String route = data['route'] ?? '';

    if (type == 'order_status_change' && route.isNotEmpty) {
      print('🧭 [FCM] Navegando a: $route');

      // Llamar al callback para navegar
      if (onNotificationTap != null) {
        onNotificationTap!(route, data);
      } else {
        print('⚠️ [FCM] onNotificationTap no está configurado');
      }
    }
  }

  /// Obtiene y registra el token FCM en el backend
  Future<void> _registerFCMToken() async {
    try {
      // Obtener token FCM
      String? token = await _firebaseMessaging.getToken();

      if (token != null) {
        print('✓ [FCM] Token obtenido: ${token.substring(0, 20)}...');
        await _saveAndSendToken(token);
      } else {
        print('⚠️ [FCM] No se pudo obtener el token');
      }
    } catch (e) {
      print('❌ [FCM] Error al obtener token: $e');
    }
  }

  /// Guarda el token localmente y lo envía al backend
  Future<void> _saveAndSendToken(String token) async {
    try {
      // Guardar token localmente
      final prefs = await SharedPreferences.getInstance();
      final oldToken = prefs.getString('fcm_token');

      if (oldToken == token) {
        print('ℹ️ [FCM] Token sin cambios');
        return;
      }

      await prefs.setString('fcm_token', token);
      print('✓ [FCM] Token guardado localmente');

      // Enviar al backend
      final accessToken = prefs.getString('accessToken');
      if (accessToken == null) {
        print('⚠️ [FCM] No hay accessToken, omitiendo envío al backend');
        return;
      }

      final url = Uri.parse('${ENV.API_URL}/api/users/register_fcm_token/');
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $accessToken',
        },
        body: jsonEncode({
          'token': token,
          'platform': Platform.isAndroid
              ? 'android'
              : Platform.isIOS
                  ? 'ios'
                  : 'web',
        }),
      );

      if (response.statusCode == 201 || response.statusCode == 200) {
        print('✅ [FCM] Token enviado al backend exitosamente');
      } else {
        print('❌ [FCM] Error al enviar token: ${response.statusCode}');
        print('   Body: ${response.body}');
      }
    } catch (e) {
      print('❌ [FCM] Error al guardar/enviar token: $e');
    }
  }

  /// Elimina el token FCM del backend (útil al cerrar sesión)
  Future<void> unregisterToken() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('fcm_token');
      final accessToken = prefs.getString('accessToken');

      if (token == null || accessToken == null) {
        print('ℹ️ [FCM] No hay token para eliminar');
        return;
      }

      final url = Uri.parse('${ENV.API_URL}/api/users/unregister_fcm_token/');
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $accessToken',
        },
        body: jsonEncode({
          'token': token,
        }),
      );

      if (response.statusCode == 200) {
        print('✅ [FCM] Token eliminado del backend');
        await prefs.remove('fcm_token');
      } else {
        print('❌ [FCM] Error al eliminar token: ${response.statusCode}');
      }
    } catch (e) {
      print('❌ [FCM] Error al eliminar token: $e');
    }
  }

  /// Verifica y actualiza el token si es necesario
  Future<void> refreshTokenIfNeeded() async {
    final prefs = await SharedPreferences.getInstance();
    final savedToken = prefs.getString('fcm_token');
    final currentToken = await _firebaseMessaging.getToken();

    if (savedToken != currentToken && currentToken != null) {
      print('🔄 [FCM] Token cambió, actualizando...');
      await _saveAndSendToken(currentToken);
    }
  }
}

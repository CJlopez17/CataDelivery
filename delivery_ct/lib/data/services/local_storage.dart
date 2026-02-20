import 'package:shared_preferences/shared_preferences.dart';

class LocalStorage {

  // Guardar valores
  static Future<void> saveUserSession({
    required String access,
    required String user,
    required String userId,
  }) async {
    final prefs = await SharedPreferences.getInstance();

    await prefs.setString('access', access);
    await prefs.setString('user', user);
    await prefs.setString('userId', userId);
  }

  // Obtener token
  static Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('access');
  }

  // Obtener user
  static Future<String?> getUser() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('user');
  }

  // Obtener userId
  static Future<String?> getUserId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('userId');
  }

  // Borrar sesión (logout)
  static Future<void> clearSession() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('access');
    await prefs.remove('user');
    await prefs.remove('userId');
  }
}

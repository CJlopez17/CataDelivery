import 'package:shared_preferences/shared_preferences.dart';

class AuthService {
  static Future<bool> isLoggedIn() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('accessToken');
    return token != null && token.isNotEmpty;
  }
}

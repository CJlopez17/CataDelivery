import 'package:delivery_ct_admin/config/env.dart';
import 'package:flutter/material.dart';
// ignore: depend_on_referenced_packages
import 'package:http/http.dart' as http;
import 'dart:convert';
// ignore: depend_on_referenced_packages
import 'package:shared_preferences/shared_preferences.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();

  final bool _isLoading = false;

  Future<void> _login() async {
    final url = "${ENV.API_URL}/api/auth/login/";

    try {
      final response = await http.post(
        Uri.parse(url),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"username": _usernameController.text.trim(), "password": _passwordController.text.trim()}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        final prefs = await SharedPreferences.getInstance();

        // GUARDAR TOKENS
        await prefs.setString("accessToken", data["access"]);
        await prefs.setString("refreshToken", data["refresh"]);

        // GUARDAR DATOS DEL USUARIO
        await prefs.setInt("userId", data["user"]["id"]);
        await prefs.setString("role", data["user"]["role"]);

        // DATO TIENDA
        final stores = data["user"]["stores"];

        if (stores != null && stores.isNotEmpty) {
          await prefs.setInt("storeId", stores[0]);
        }

        // NAVEGAR SEGÚN EL ROL
        final role = data["user"]["role"];

        if (!mounted) return;

        if (role == "store") {
          // Redirigir al panel de administración de tienda
          Navigator.pushNamedAndRemoveUntil(context, '/butonPanel', (route) => false);
        } else if (role == "rider") {
          // Redirigir al panel de delivery
          Navigator.pushNamedAndRemoveUntil(context, '/deliveryPanel', (route) => false);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Rol no autorizado para este sistema"), backgroundColor: Colors.red),
          );
        }
      } else {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Credenciales incorrectas"), backgroundColor: Colors.red));
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Error de conexión: $e"), backgroundColor: Colors.red));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Iniciar Sesión'),
        backgroundColor: const Color(0xFF2563EB),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Padding(
        padding: const EdgeInsets.all(32),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              TextFormField(
                controller: _usernameController,
                decoration: InputDecoration(
                  labelText: 'Usuario',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                ),
                validator: (value) => (value == null || value.isEmpty) ? 'Campo requerido' : null,
              ),
              const SizedBox(height: 20),
              TextFormField(
                controller: _passwordController,
                obscureText: true,
                decoration: InputDecoration(
                  labelText: 'Contraseña',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                ),
                validator: (value) => (value == null || value.isEmpty) ? 'Campo requerido' : null,
              ),
              const SizedBox(height: 30),
              _isLoading
                  ? const CircularProgressIndicator()
                  : ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2563EB),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 80, vertical: 15),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: _login,
                      child: const Text('Entrar'),
                    ),
            ],
          ),
        ),
      ),
    );
  }
}

import 'package:delivery_ct/config/env.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class ChangePasswordPage extends StatefulWidget {
  const ChangePasswordPage({super.key});

  @override
  State<ChangePasswordPage> createState() => _ChangePasswordPageState();
}

class _ChangePasswordPageState extends State<ChangePasswordPage> {
  final _formKey = GlobalKey<FormState>();

  final TextEditingController oldPasswordController = TextEditingController();
  final TextEditingController newPasswordController = TextEditingController();
  final TextEditingController confirmPasswordController =
      TextEditingController();

  bool isLoading = false;
  bool hideOld = true;
  bool hideNew = true;
  bool hideConfirm = true;

  Future<void> _changePassword() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString("accessToken");
    if (!_formKey.currentState!.validate()) return;

    setState(() => isLoading = true);

    final url = Uri.parse("${ENV.API_URL}api/auth/change-password/");

    final body = {
      "old_password": oldPasswordController.text.trim(),
      "new_password": newPasswordController.text.trim(),
    };

    try {
      final response = await http.post(
        url,
        headers: {
          "Content-Type": "application/json",
          "Authorization": "Bearer $token"
        },
        body: jsonEncode(body),
      );

      if (response.statusCode == 200) {
        _showMessage("Contraseña cambiada correctamente", true);
      } else {
        _showMessage("Error: ${response.body}", false);
      }
    } catch (e) {
      _showMessage("Error de conexión", false);
    }

    setState(() => isLoading = false);
  }

  void _showMessage(String message, bool success) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(success ? "Éxito" : "Error"),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("OK"),
          )
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Cambiar contraseña"),
        backgroundColor: const Color(0xFF2563EB),
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              // Old Password
              TextFormField(
                controller: oldPasswordController,
                obscureText: hideOld,
                decoration: InputDecoration(
                  labelText: "Contraseña actual",
                  suffixIcon: IconButton(
                    icon: Icon(hideOld ? Icons.visibility : Icons.visibility_off),
                    onPressed: () => setState(() => hideOld = !hideOld),
                  ),
                ),
                validator: (value) =>
                    value!.isEmpty ? "Ingresa tu contraseña actual" : null,
              ),
              const SizedBox(height: 16),

              // New Password
              TextFormField(
                controller: newPasswordController,
                obscureText: hideNew,
                decoration: InputDecoration(
                  labelText: "Nueva contraseña",
                  suffixIcon: IconButton(
                    icon: Icon(hideNew ? Icons.visibility : Icons.visibility_off),
                    onPressed: () => setState(() => hideNew = !hideNew),
                  ),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return "Ingresa una nueva contraseña";
                  }
                  if (value.length < 8) {
                    return "Debe tener al menos 8 caracteres";
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Confirm Password
              TextFormField(
                controller: confirmPasswordController,
                obscureText: hideConfirm,
                decoration: InputDecoration(
                  labelText: "Confirmar nueva contraseña",
                  suffixIcon: IconButton(
                    icon: Icon(hideConfirm ? Icons.visibility : Icons.visibility_off),
                    onPressed: () => setState(() => hideConfirm = !hideConfirm),
                  ),
                ),
                validator: (value) {
                  if (value != newPasswordController.text) {
                    return "Las contraseñas no coinciden";
                  }
                  return null;
                },
              ),

              const SizedBox(height: 30),

              // Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: isLoading ? null : _changePassword,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2563EB),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text("Cambiar contraseña"),
                ),
              )
            ],
          ),
        ),
      ),
    );
  }
}

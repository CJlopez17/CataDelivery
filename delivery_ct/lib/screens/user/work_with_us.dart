import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../../config/env.dart';

class RequestRoleScreen extends StatefulWidget {
  const RequestRoleScreen({super.key});

  @override
  State<RequestRoleScreen> createState() => _RequestRoleScreenState();
}

class _RequestRoleScreenState extends State<RequestRoleScreen> {
  String selectedRole = "rider"; // default
  TextEditingController messageController = TextEditingController();
  bool loading = false;

  Future<void> sendRoleRequest() async {
    setState(() => loading = true);

    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString("accessToken");

    if (token == null) {
      setState(() => loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("No se encontró el token. Debes iniciar sesión."),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final url = "${ENV.API_URL}/api/role-change-requests/";

    final body = {
      "requested_role": selectedRole,
      "message": messageController.text.trim(),
    };

    try {
      final response = await http.post(
        Uri.parse(url),
        headers: {
          "Content-Type": "application/json",
          "Authorization": "Bearer $token", // <-- AQUI ESTÁ LA SOLUCIÓN
        },
        body: jsonEncode(body),
      );

      setState(() => loading = false);

      if (response.statusCode == 201 || response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Solicitud enviada correctamente"),
            backgroundColor: Colors.green,
          ),
        );
        messageController.clear();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Error: ${response.body}"),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      setState(() => loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Error de conexión: $e"),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        backgroundColor: const Color(0xFF2563EB),
        title: const Text("Trabaja con nosotros", style: TextStyle(color: Colors.white),),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 10),

            /// TÍTULO DE BIENVENIDA
            const Text(
              "¡Bienvenido!",
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1E1E1E),
              ),
            ),

            const SizedBox(height: 10),

            /// DESCRIPCIÓN
            Text(
              "Gracias por querer trabajar con nosotros. Completa la siguiente información para procesar tu solicitud de cambio de usuario.",
              style: TextStyle(fontSize: 16, color: Colors.grey.shade700),
            ),

            const SizedBox(height: 30),

            /// SELECTOR DE ROL
            Text(
              "¿Qué deseas ser?",
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.grey.shade800,
              ),
            ),
            const SizedBox(height: 10),

            Container(
              padding: const EdgeInsets.symmetric(horizontal: 15),
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border.all(color: Colors.grey.shade400),
                borderRadius: BorderRadius.circular(12),
              ),
              child: DropdownButton<String>(
                isExpanded: true,
                value: selectedRole,
                underline: const SizedBox(),
                items: const [
                  DropdownMenuItem(
                    value: "rider",
                    child: Text("Delivery / Repartidor"),
                  ),
                  DropdownMenuItem(
                    value: "store",
                    child: Text("Local Comercial"),
                  ),
                ],
                onChanged: (value) {
                  setState(() => selectedRole = value!);
                },
              ),
            ),

            const SizedBox(height: 30),

            /// MENSAJE DEL USUARIO
            Text(
              "¿Por qué quieres trabajar con nosotros?",
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.grey.shade800,
              ),
            ),
            const SizedBox(height: 10),

            TextField(
              controller: messageController,
              maxLines: 5,
              decoration: InputDecoration(
                filled: true,
                fillColor: Colors.white,
                hintText: "Escribe tu mensaje aquí...",
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey.shade400),
                ),
              ),
            ),

            const SizedBox(height: 40),

            /// BOTÓN ENVIAR
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: loading ? null : sendRoleRequest,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2563EB),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: loading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text(
                        "Enviar solicitud",
                        style: TextStyle(fontSize: 16, color: Colors.white),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

import 'package:delivery_ct/config/env.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _emailController = TextEditingController();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _password2Controller = TextEditingController();

  bool _isLoading = false;

  Future<void> _register() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    const url = '${ENV.API_URL}/api/auth/register/';
    final body = {
      "username": _usernameController.text,
      "email": _emailController.text,
      "first_name": _firstNameController.text,
      "last_name": _lastNameController.text,
      "password": _passwordController.text,
      "password2": _password2Controller.text,
    };
    try {
      final response = await http.post(
        Uri.parse(url),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode(body),
      );

      if (response.statusCode == 201 || response.statusCode == 200) {
        // Registro exitoso
        // ignore: use_build_context_synchronously
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Registro exitoso 🎉"),
            backgroundColor: Colors.green,
          ),
        );
        // ignore: use_build_context_synchronously
        Navigator.pushNamed(context, '/buttonpaneluser');
      } else {
        // Error en la respuesta del servidor
        // ignore: use_build_context_synchronously
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Error: ${response.body}"),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } catch (e) {
      // Error de conexión
      // ignore: use_build_context_synchronously
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Error de conexión: $e"),
          backgroundColor: Colors.redAccent,
        ),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Registro'),
        backgroundColor: const Color(0xFF2563EB),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              _buildTextField(_usernameController, 'Usuario'),
              const SizedBox(height: 15),
              _buildTextField(
                _emailController,
                'Correo electrónico',
                keyboard: TextInputType.emailAddress,
              ),
              const SizedBox(height: 15),
              _buildTextField(_firstNameController, 'Nombre'),
              const SizedBox(height: 15),
              _buildTextField(_lastNameController, 'Apellido'),
              const SizedBox(height: 15),
              _buildTextField(_passwordController, 'Contraseña', obscure: true),
              const SizedBox(height: 15),
              _buildTextField(
                _password2Controller,
                'Confirmar contraseña',
                obscure: true,
              ),
              const SizedBox(height: 30),
              _isLoading
                  ? const CircularProgressIndicator()
                  : ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2563EB),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 80,
                          vertical: 15,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: _register,
                      child: const Text('Registrar'),
                    ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTextField(
    TextEditingController controller,
    String label, {
    bool obscure = false,
    TextInputType keyboard = TextInputType.text,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: obscure,
      keyboardType: keyboard,
      decoration: InputDecoration(
        labelText: label,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
      ),
      validator: (value) =>
          (value == null || value.isEmpty) ? 'Campo requerido' : null,
    );
  }
}

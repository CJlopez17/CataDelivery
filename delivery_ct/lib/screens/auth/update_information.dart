import 'dart:convert';
import 'package:delivery_ct/config/env.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class UpdateInformationScreen extends StatefulWidget {
  const UpdateInformationScreen({super.key});

  @override
  State<UpdateInformationScreen> createState() => _UpdateInformationScreenState();
}

class _UpdateInformationScreenState extends State<UpdateInformationScreen> {
  final _formKey = GlobalKey<FormState>();
  bool isLoading = true;
  bool isSaving = false;
  String? errorMessage;

  // Controllers
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _firstNameController = TextEditingController();
  final TextEditingController _lastNameController = TextEditingController();
  final TextEditingController _phoneNumberController = TextEditingController();

  int? userId;
  String? token;

  @override
  void initState() {
    super.initState();
    loadUserData();
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _emailController.dispose();
    _firstNameController.dispose();
    _lastNameController.dispose();
    _phoneNumberController.dispose();
    super.dispose();
  }

  Future<void> loadUserData() async {
    setState(() => isLoading = true);

    try {
      final prefs = await SharedPreferences.getInstance();
      userId = prefs.getInt("userId");
      token = prefs.getString("accessToken");

      if (userId == null || token == null) {
        setState(() {
          errorMessage = "No se encontró información del usuario.";
          isLoading = false;
        });
        return;
      }

      final url = Uri.parse("${ENV.API_URL}/api/users/$userId/");
      final response = await http.get(
        url,
        headers: {"Content-Type": "application/json", "Authorization": "Bearer $token"},
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          _usernameController.text = data["username"] ?? "";
          _emailController.text = data["email"] ?? "";
          _firstNameController.text = data["first_name"] ?? "";
          _lastNameController.text = data["last_name"] ?? "";
          _phoneNumberController.text = data["phone_number"] ?? "";
          isLoading = false;
        });
      } else {
        setState(() {
          errorMessage = "Error al cargar datos del usuario";
          isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        errorMessage = "Error de conexión: $e";
        isLoading = false;
      });
    }
  }

  Future<void> updateUserData() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      isSaving = true;
      errorMessage = null;
    });

    try {
      final url = Uri.parse("${ENV.API_URL}/api/users/$userId/");
      final response = await http.patch(
        url,
        headers: {"Content-Type": "application/json", "Authorization": "Bearer $token"},
        body: jsonEncode({
          "username": _usernameController.text.trim(),
          "email": _emailController.text.trim(),
          "first_name": _firstNameController.text.trim(),
          "last_name": _lastNameController.text.trim(),
          "phone_number": _phoneNumberController.text.trim(),
        }),
      );

      if (response.statusCode == 200) {
        if (!mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Información actualizada correctamente"),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );

        // Esperar un momento antes de regresar
        await Future.delayed(const Duration(milliseconds: 500));
        if (mounted) {
          Navigator.pop(context);
        }
      } else {
        final errorData = jsonDecode(response.body);
        setState(() {
          errorMessage = errorData.toString();
        });
      }
    } catch (e) {
      setState(() {
        errorMessage = "Error de conexión: $e";
      });
    } finally {
      if (mounted) {
        setState(() => isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        title: const Text("Actualizar Información", style: TextStyle(color: Colors.white)),
        centerTitle: true,
        backgroundColor: const Color(0xFF2563EB),
        foregroundColor: Colors.white,
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : errorMessage != null && userId == null
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    errorMessage!,
                    style: const TextStyle(color: Colors.red, fontSize: 16),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton(onPressed: loadUserData, child: const Text("Reintentar")),
                ],
              ),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Título
                    const Text(
                      "Información Personal",
                      style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF1E1E1E)),
                    ),
                    const SizedBox(height: 8),
                    Text("Actualiza tu información personal", style: TextStyle(fontSize: 14, color: Colors.grey[600])),
                    const SizedBox(height: 30),

                    // Error message
                    if (errorMessage != null && userId != null)
                      Container(
                        padding: const EdgeInsets.all(12),
                        margin: const EdgeInsets.only(bottom: 20),
                        decoration: BoxDecoration(
                          color: Colors.red[50],
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.red[200]!),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.error_outline, color: Colors.red[700]),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(errorMessage!, style: TextStyle(color: Colors.red[700])),
                            ),
                          ],
                        ),
                      ),

                    // Username
                    TextFormField(
                      controller: _usernameController,
                      decoration: InputDecoration(
                        labelText: "Nombre de usuario",
                        prefixIcon: const Icon(Icons.person, color: Color(0xFF2563EB)),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        filled: true,
                        fillColor: Colors.white,
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return "El nombre de usuario es requerido";
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    // Email
                    TextFormField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      decoration: InputDecoration(
                        labelText: "Correo electrónico",
                        prefixIcon: const Icon(Icons.email, color: Color(0xFF2563EB)),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        filled: true,
                        fillColor: Colors.white,
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return "El correo electrónico es requerido";
                        }
                        if (!value.contains('@')) {
                          return "Ingresa un correo válido";
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    // First Name
                    TextFormField(
                      controller: _firstNameController,
                      decoration: InputDecoration(
                        labelText: "Nombre",
                        prefixIcon: const Icon(Icons.badge, color: Color(0xFF2563EB)),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        filled: true,
                        fillColor: Colors.white,
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return "El nombre es requerido";
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    // Last Name
                    TextFormField(
                      controller: _lastNameController,
                      decoration: InputDecoration(
                        labelText: "Apellido",
                        prefixIcon: const Icon(Icons.badge_outlined, color: Color(0xFF2563EB)),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        filled: true,
                        fillColor: Colors.white,
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return "El apellido es requerido";
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    // Phone Number
                    TextFormField(
                      controller: _phoneNumberController,
                      keyboardType: TextInputType.phone,
                      decoration: InputDecoration(
                        labelText: "Número de teléfono",
                        prefixIcon: const Icon(Icons.phone, color: Color(0xFF2563EB)),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        filled: true,
                        fillColor: Colors.white,
                        hintText: "Ejemplo: +593 999 999 999",
                      ),
                    ),
                    const SizedBox(height: 30),

                    // Update Button
                    SizedBox(
                      width: double.infinity,
                      height: 54,
                      child: ElevatedButton(
                        onPressed: isSaving ? null : updateUserData,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF2563EB),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          elevation: 2,
                        ),
                        child: isSaving
                            ? const SizedBox(
                                height: 24,
                                width: 24,
                                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                              )
                            : const Text(
                                "Actualizar Información",
                                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}

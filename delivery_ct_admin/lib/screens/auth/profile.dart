import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:delivery_ct_admin/config/env.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  bool isLoading = true;
  bool isSaving = false;
  String? errorMessage;

  // Controllers para los campos editables
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _firstNameController = TextEditingController();
  final TextEditingController _lastNameController = TextEditingController();
  final TextEditingController _phoneNumberController = TextEditingController();

  String role = "";
  int? userId;

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
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString("accessToken");
    userId = prefs.getInt("userId");

    if (userId == null) {
      setState(() {
        errorMessage = "No se encontró información del usuario.";
        isLoading = false;
      });
      return;
    }

    try {
      final url = Uri.parse("${ENV.API_URL}/api/users/$userId/");
      final response = await http.get(
        url,
        headers: {
          "Content-Type": "application/json",
          "Authorization": "Bearer $token",
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          _usernameController.text = data["username"] ?? "";
          _emailController.text = data["email"] ?? "";
          _firstNameController.text = data["first_name"] ?? "";
          _lastNameController.text = data["last_name"] ?? "";
          _phoneNumberController.text = data["phone_number"] ?? "";
          role = data["role"] ?? "";
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
    setState(() {
      isSaving = true;
      errorMessage = null;
    });

    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString("accessToken");

    try {
      final url = Uri.parse("${ENV.API_URL}/api/users/$userId/");
      final response = await http.patch(
        url,
        headers: {
          "Content-Type": "application/json",
          "Authorization": "Bearer $token",
        },
        body: json.encode({
          "username": _usernameController.text,
          "email": _emailController.text,
          "first_name": _firstNameController.text,
          "last_name": _lastNameController.text,
          "phone_number": _phoneNumberController.text,
        }),
      );

      if (response.statusCode == 200) {
        setState(() {
          isSaving = false;
        });

        if (!mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Información actualizada correctamente"),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        final errorData = json.decode(response.body);
        setState(() {
          errorMessage = errorData.toString();
          isSaving = false;
        });
      }
    } catch (e) {
      setState(() {
        errorMessage = "Error de conexión: $e";
        isSaving = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        backgroundColor: const Color(0xFF2563EB),
        foregroundColor: Colors.white,
        title: const Text("Mi Perfil"),
        centerTitle: true,
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : errorMessage != null
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
                      ElevatedButton(
                        onPressed: loadUserData,
                        child: const Text("Reintentar"),
                      ),
                    ],
                  ),
                )
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Icono de perfil
                      Center(
                        child: CircleAvatar(
                          radius: 50,
                          backgroundColor: const Color(0xFF2563EB),
                          child: Text(
                            _firstNameController.text.isNotEmpty
                                ? _firstNameController.text[0].toUpperCase()
                                : _usernameController.text[0].toUpperCase(),
                            style: const TextStyle(
                              fontSize: 40,
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 10),

                      // Rol del usuario
                      Center(
                        child: Chip(
                          label: Text(
                            role.toUpperCase(),
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          backgroundColor: const Color(0xFFFF6F3C),
                        ),
                      ),

                      const SizedBox(height: 30),

                      // Título
                      const Text(
                        "Información Personal",
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1E1E1E),
                        ),
                      ),

                      const SizedBox(height: 20),

                      // Campo: Usuario
                      TextField(
                        controller: _usernameController,
                        decoration: InputDecoration(
                          labelText: "Nombre de usuario",
                          prefixIcon: const Icon(Icons.person, color: Color(0xFF2563EB)),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          filled: true,
                          fillColor: Colors.white,
                        ),
                      ),

                      const SizedBox(height: 15),

                      // Campo: Email
                      TextField(
                        controller: _emailController,
                        keyboardType: TextInputType.emailAddress,
                        decoration: InputDecoration(
                          labelText: "Correo electrónico",
                          prefixIcon: const Icon(Icons.email, color: Color(0xFF2563EB)),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          filled: true,
                          fillColor: Colors.white,
                        ),
                      ),

                      const SizedBox(height: 15),

                      // Campo: Nombre
                      TextField(
                        controller: _firstNameController,
                        decoration: InputDecoration(
                          labelText: "Nombre",
                          prefixIcon: const Icon(Icons.badge, color: Color(0xFF2563EB)),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          filled: true,
                          fillColor: Colors.white,
                        ),
                      ),

                      const SizedBox(height: 15),

                      // Campo: Apellido
                      TextField(
                        controller: _lastNameController,
                        decoration: InputDecoration(
                          labelText: "Apellido",
                          prefixIcon: const Icon(Icons.badge_outlined, color: Color(0xFF2563EB)),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          filled: true,
                          fillColor: Colors.white,
                        ),
                      ),

                      const SizedBox(height: 15),

                      // Campo: Teléfono
                      TextField(
                        controller: _phoneNumberController,
                        keyboardType: TextInputType.phone,
                        decoration: InputDecoration(
                          labelText: "Número de teléfono",
                          prefixIcon: const Icon(Icons.phone, color: Color(0xFF2563EB)),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          filled: true,
                          fillColor: Colors.white,
                        ),
                      ),

                      const SizedBox(height: 30),

                      // Botón de actualizar
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton(
                          onPressed: isSaving ? null : updateUserData,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF2563EB),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          child: isSaving
                              ? const CircularProgressIndicator(
                                  color: Colors.white,
                                )
                              : const Text(
                                  "Actualizar Información",
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                        ),
                      ),
                    ],
                  ),
                ),
    );
  }
}

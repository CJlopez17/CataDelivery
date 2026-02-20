import 'dart:convert';

import 'package:delivery_ct/config/env.dart';
import 'package:delivery_ct/screens/auth/change_password.dart';
import 'package:delivery_ct/screens/auth/select_account.dart';
import 'package:delivery_ct/screens/auth/update_information.dart';
import 'package:delivery_ct/screens/user/address/list_address.dart';
import 'package:delivery_ct/screens/user/work_with_us.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class Profile extends StatefulWidget {
  const Profile({super.key});

  @override
  State<Profile> createState() => _ProfileState();
}

class _ProfileState extends State<Profile> {
  String? errorMessage;
  bool isLoading = true;
  int? id;
  String? token;
  String? first_name;
  String? last_name;

  @override
  void initState() {
    super.initState();
    loadDetail();
  }

  Future<void> loadDetail() async {
    final prefs = await SharedPreferences.getInstance();
    id = prefs.getInt("userId");
    token = prefs.getString("accessToken");

    try {
      if (token == null) {
        setState(() {
          errorMessage = "Token de autenticación no encontrado.";
          isLoading = false;
        });
        return;
      }

      final url = Uri.parse('${ENV.API_URL}/api/users/$id/');

      final response = await http.get(
        url,
        headers: {
          "Content-Type": "application/json",
          "Authorization": "Bearer $token",
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        first_name = data['first_name'];
        last_name = data['last_name'];
      } else {
        setState(() {
          errorMessage = "Error ${response.statusCode}: ${response.body}";
        });
      }
    } catch (e) {
      setState(() {
        errorMessage = "Error al cargar los datos del usuario: $e";
      });
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5), // Fondo suave
      appBar: AppBar(
        title: const Text("Mi Perfil", style: TextStyle(color: Colors.white)),
        centerTitle: true,
        backgroundColor: const Color(0xFF2563EB),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 30),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            /// --- FOTO DEL USUARIO ---
            const CircleAvatar(
              radius: 55,
              backgroundImage: AssetImage("assets/perfil.png"),
            ),
            const SizedBox(height: 15),

            /// --- NOMBRE DEL USUARIO ---
            Text(
              "$first_name $last_name",
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1E1E1E),
              ),
            ),

            const SizedBox(height: 30),
            const Divider(),

            /// --- BOTONES DEL PERFIL ---
            _buildProfileButton(
              icon: Icons.lock_outline,
              title: "Cambiar contraseña",
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => ChangePasswordPage()),
                );
              },
            ),
            _buildProfileButton(
              icon: Icons.person_outline,
              title: "Actualizar información",
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const UpdateInformationScreen(),
                  ),
                ).then((_) => loadDetail());
              },
            ),
            _buildProfileButton(
              icon: Icons.location_on_outlined,
              title: "Agregar ubicación",
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => AddressesList()),
                );
              },
            ),
            _buildProfileButton(
              icon: Icons.work_outline,
              title: "Trabaja con nosotros",
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => RequestRoleScreen()),
                );
              },
            ),
            _buildProfileButton(
              icon: Icons.exit_to_app,
              title: "Cerrar sesión",
              color: Colors.red,
              onTap: () async {
                final prefs = await SharedPreferences.getInstance();
                await prefs.clear();
                Navigator.of(context, rootNavigator: true).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (context) => SelectAccount()),
                  (route) => false,
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  /// WIDGET REUTILIZABLE PARA BOTONES
  Widget _buildProfileButton({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    Color color = const Color(0xFF2563EB),
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            spreadRadius: 1,
            blurRadius: 7,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ListTile(
        leading: Icon(icon, color: color),
        title: Text(
          title,
          style: TextStyle(
            fontSize: 16,
            color: color,
            fontWeight: FontWeight.w500,
          ),
        ),
        trailing: Icon(Icons.arrow_forward_ios, size: 16, color: color),
        onTap: onTap,
      ),
    );
  }
}

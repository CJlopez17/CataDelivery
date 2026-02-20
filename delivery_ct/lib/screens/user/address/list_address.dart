import 'dart:convert';
import 'package:delivery_ct/config/env.dart';
import 'package:delivery_ct/screens/user/address/create_address.dart';
import 'package:delivery_ct/screens/user/address/edit_address.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class AddressesList extends StatefulWidget {
  const AddressesList({super.key});

  @override
  _AddressesListPageState createState() => _AddressesListPageState();
}

class _AddressesListPageState extends State<AddressesList> {
  List<dynamic> futureAddresses = []; // Cambiado a List
  String? errorMessage;
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    getAddresses();
  }

  Future<void> getAddresses() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString("accessToken");
    final id = prefs.getInt("userId");
    try {
      if (token == null) {
        setState(() {
          errorMessage = "Token de autenticación no encontrado.";
          isLoading = false;
        });
        return;
      }

      final uri = Uri.parse("${ENV.API_URL}/api/addresses/?id=$id");

      final response = await http.get(
        uri,
        headers: {
          "Content-Type": "application/json",
          "Authorization": "Bearer $token",
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          futureAddresses = data;
          isLoading = false;
        });
      } else {
        setState(() {
          errorMessage = "Error ${response.statusCode}: ${response.body}";
          isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        errorMessage = "Error al cargar las direcciones: $e";
        isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Mis direcciones"),
        backgroundColor: const Color(0xFF2563EB),
        foregroundColor: Colors.white,
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : errorMessage != null
          ? Center(
              child: Text(
                errorMessage!,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 18, color: Colors.red),
              ),
            )
          : futureAddresses.isEmpty
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    "No tienes ninguna dirección",
                    style: TextStyle(fontSize: 18),
                  ),
                  const SizedBox(height: 15),
                  ElevatedButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => AddAddressPage(),
                        ),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2563EB),
                    ),
                    child: const Text(
                      "Agregar nueva dirección",
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                ],
              ),
            )
          : Column(
              children: [
                Expanded(
                  child: ListView.builder(
                    itemCount: futureAddresses.length,
                    itemBuilder: (context, index) {
                      final addr = futureAddresses[index];

                      return Card(
                        margin: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 8,
                        ),
                        elevation: 3,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(14.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                addr['name'],
                                style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                addr['description'] ?? 'Sin descripción',
                                style: const TextStyle(fontSize: 16),
                              ),
                              const SizedBox(height: 12),
                              Align(
                                alignment: Alignment.centerRight,
                                child: TextButton(
                                  onPressed: () => {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) =>
                                            EditAddress(address: addr),
                                      ),
                                    ),
                                  },
                                  style: TextButton.styleFrom(
                                    foregroundColor: const Color(0xFF2563EB),
                                  ),
                                  child: const Text("Editar"),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),

                // BOTÓN FINAL PARA AÑADIR DIRECCIÓN
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => AddAddressPage(),
                        ),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2563EB),
                      minimumSize: const Size(double.infinity, 50),
                    ),
                    child: const Text(
                      "Agregar nueva dirección",
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}

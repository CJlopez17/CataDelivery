import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:delivery_ct_admin/config/env.dart';
import 'package:delivery_ct_admin/screens/new_product.dart';

class Home extends StatefulWidget {
  const Home({super.key});

  @override
  State<Home> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<Home> {
  bool isLoading = true;
  String? errorMessage;
  int? storeId;
  List<dynamic> products = [];

  @override
  void initState() {
    super.initState();
    loadData();
  }

  Future<void> loadData() async {
    final prefs = await SharedPreferences.getInstance();

    // Recuperamos el storeId desde local storage
    storeId = prefs.getInt("storeId");

    if (storeId == null) {
      setState(() {
        errorMessage = "No existe storeId guardado.";
        isLoading = false;
      });
      return;
    }

    // Consultamos productos por tienda
    final url = Uri.parse("${ENV.API_URL}/api/products/?store=$storeId");
    final token = prefs.getString("accessToken");

    final response = await http.get(
      url,
      headers: {"Content-Type": "application/json", "Authorization": "Bearer $token"},
    );

    if (response.statusCode == 200) {
      setState(() {
        products = json.decode(response.body);
        isLoading = false;
      });
    } else {
      setState(() {
        errorMessage = "Error ${response.statusCode}: ${response.body}";
        isLoading = false;
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
        title: const Text("Productos de la Tienda"),
        centerTitle: true,
      ),

      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : errorMessage != null
          ? Center(
              child: Text(errorMessage!, style: const TextStyle(color: Colors.red, fontSize: 18)),
            )
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.add),
                      label: const Text("Agregar Producto"),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2563EB),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => CreateProduct(storeId: storeId!)),
                        ).then((_) => loadData());
                      },
                    ),
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(10),
                    child: GridView.builder(
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        crossAxisSpacing: 12,
                        mainAxisSpacing: 12,
                        childAspectRatio: 0.8,
                      ),
                      itemCount: products.length,
                      itemBuilder: (_, index) {
                        final p = products[index];

                        return Card(
                          elevation: 3,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Icon(Icons.fastfood, size: 42, color: Color(0xFF2563EB)),
                                const SizedBox(height: 8),

                                // Nombre
                                Text(
                                  p["name"],
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF1E1E1E),
                                  ),
                                ),

                                const SizedBox(height: 5),

                                // Descripción
                                Text(
                                  p["description"],
                                  maxLines: 3,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(fontSize: 13, color: Colors.black87),
                                ),

                                const Spacer(),

                                // Precio
                                Text(
                                  "\$${p["price"]}",
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFFFF6F3C),
                                  ),
                                ),

                                const SizedBox(height: 6),

                                Align(
                                  alignment: Alignment.bottomRight,
                                  child: TextButton(
                                    onPressed: () {},
                                    style: TextButton.styleFrom(foregroundColor: const Color(0xFF2563EB)),
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
                ),
              ],
            ),
    );
  }
}

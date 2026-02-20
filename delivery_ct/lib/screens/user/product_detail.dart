import 'dart:convert';
import 'package:delivery_ct/config/env.dart';
import 'package:delivery_ct/controllers/cart_item.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ProductDetail extends StatefulWidget {
  final int productId;

  const ProductDetail({super.key, required this.productId});

  @override
  State<ProductDetail> createState() => _ProductDetailPageState();
}

class _ProductDetailPageState extends State<ProductDetail> {
  String? errorMessage;
  bool isLoading = true;
  Map<String, dynamic> products = {};

  @override
  void initState() {
    super.initState();
    loadDetail();
  }

  Future<void> loadDetail() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString("accessToken");
    try {
      if (token == null) {
        setState(() {
          errorMessage = "Token de autenticación no encontrado.";
          isLoading = false;
        });
        return;
      }

      final url = Uri.parse('${ENV.API_URL}/api/products/${widget.productId}/');

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
          products = data;
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
        errorMessage = "Error al cargar el detalle del producto: $e";
        isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text("Detalle del producto"),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
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
          : SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Foto
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Image.network(
                      products["photoProduct"],
                      width: double.infinity,
                      height: 260,
                      fit: BoxFit.cover,
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Nombre
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Text(
                      products["name"],
                      style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),

                  const SizedBox(height: 10),

                  // Descripción
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Text(
                      products["description"],
                      style: const TextStyle(
                        fontSize: 18,
                        color: Colors.black54,
                      ),
                    ),
                  ),

                  const SizedBox(height: 25),

                  // Precio
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Text(
                      "\$${products["price"]}",
                      style: const TextStyle(
                        fontSize: 30,
                        fontWeight: FontWeight.bold,
                        color: Colors.green,
                      ),
                    ),
                  ),

                  const SizedBox(height: 30),

                  // Botón agregar al carrito
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: SizedBox(
                      width: double.infinity,
                      height: 55,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.black,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onPressed: () {
                          Provider.of<CartProvider>(
                            context,
                            listen: false,
                          ).addToCart(
                            CartItem(
                              id: products["id"],
                              name: products["name"],
                              price: products["price"].toDouble(),
                              storeId: products["store"],
                            ),
                          );
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text("Producto agregado al carrito"),
                            ),
                          );
                        },
                        child: const Text(
                          "Agregar",
                          style: TextStyle(color: Colors.white, fontSize: 18),
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 20),
                ],
              ),
            ),
    );
  }
}

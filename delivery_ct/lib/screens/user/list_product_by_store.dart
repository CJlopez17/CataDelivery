import 'dart:convert';
import 'package:delivery_ct/config/env.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:delivery_ct/screens/user/product_detail.dart';

class StoreProductsPage extends StatefulWidget {
  final int storeId;
  final String storeName;

  const StoreProductsPage({
    super.key,
    required this.storeId,
    required this.storeName,
  });

  @override
  _StoreProductsPageState createState() => _StoreProductsPageState();
}

class _StoreProductsPageState extends State<StoreProductsPage> {
  List products = [];
  bool isLoading = true;
  String? errorMessage;

  @override
  void initState() {
    super.initState();
    loadProducts();
  }

  Future<void> loadProducts() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString("accessToken");

      if (token == null) {
        setState(() {
          errorMessage = "Token no encontrado.";
          isLoading = false;
        });
        return;
      }

      final url = Uri.parse(
        "${ENV.API_URL}/api/products/?store=${widget.storeId}",
      );

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
        errorMessage = "Error de conexión: $e";
        isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.storeName),
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
          : ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: products.length,
              itemBuilder: (context, index) {
                final product = products[index];

                return Card(
                  margin: const EdgeInsets.symmetric(vertical: 8),
                  elevation: 3,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Row(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: Image.network(
                            product['photoProduct'] ?? '',
                            width: 70,
                            height: 70,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) {
                              return Container(
                                width: 70,
                                height: 70,
                                color: Colors.grey[300],
                                child: const Icon(
                                  Icons.store,
                                  size: 35,
                                  color: Colors.grey,
                                ),
                              );
                            },
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            children: [
                              ListTile(
                                contentPadding: const EdgeInsets.all(16),
                                title: Text(
                                  product["name"],
                                  style: const TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF1E1E1E),
                                  ),
                                ),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const SizedBox(height: 6),
                                    Text(
                                      product["description"],
                                      style: const TextStyle(
                                        fontSize: 15,
                                        color: Colors.black87,
                                      ),
                                    ),
                                    const SizedBox(height: 10),
                                    Text(
                                      "\$${product["price"].toString()}",
                                      style: const TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFFFF6F3C),
                                      ),
                                    ),
                                  ],
                                ),
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => ProductDetail(
                                        productId: product["id"],
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}

/*
body: cart.items.isEmpty
        ? Center(
            child: Text(
              "Tu carrito está vacío",
              style: TextStyle(fontSize: 18),
            ),
          )
        : Column(
            children: [
              Expanded(
                child: ListView.builder(
                  itemCount: cart.items.length,
                  itemBuilder: (context, index) {
                    final item = cart.items[index];

                    return Card(
                      margin: const EdgeInsets.all(10),
                      child: ListTile(
                        title: Text(item.name),
                        subtitle: Text(
                          "Precio: \$${item.price.toStringAsFixed(2)}",
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: Icon(Icons.remove_circle),
                              onPressed: () => cart.decreaseQty(item.id),
                            ),
                            Text("${item.quantity}"),
                            IconButton(
                              icon: Icon(Icons.add_circle),
                              onPressed: () => cart.increaseQty(item.id),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),

              // ---- Subtotal ----
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          "Subtotal",
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          "\$${cart.subtotal.toStringAsFixed(2)}",
                          style: TextStyle(fontSize: 20),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // ---- Botón Continuar ----
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        minimumSize: Size(double.infinity, 50),
                      ),
                      onPressed: () {
                        showDialog(
                          context: context,
                          builder: (_) => AlertDialog(
                            title: Text("Revisa tu carrito"),
                            content: Text("¿Tu pedido es correcto?"),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(context),
                                child: Text("Revisar"),
                              ),
                              ElevatedButton(
                                onPressed: () {
                                  Navigator.pop(context);
                                  Navigator.pushNamed(context, "/payment");
                                },
                                child: Text("Es correcto"),
                              ),
                            ],
                          ),
                        );
                      },
                      child: Text("Continuar con el pago"),
                    ),
                  ],
                ),
              ),
            ],
          ),
*/
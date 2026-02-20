import 'dart:convert';

import 'package:delivery_ct/config/env.dart';
import 'package:delivery_ct/controllers/cart_item.dart';
import 'package:delivery_ct/data/models/address.dart';
import 'package:delivery_ct/data/models/payment.dart';
import 'package:delivery_ct/screens/user/payment.dart';
import 'package:delivery_ct/utils/distance_utils.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;

class CartScreen extends StatefulWidget {
  const CartScreen({super.key});

  @override
  State<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends State<CartScreen> {
  List<Address> _addresses = [];
  Address? _selectedAddress;
  bool _isLoadingAddresses = true;
  String? _errorMessage;
  double? _deliveryFee;
  bool _isCalculatingDeliveryFee = false;
  final TextEditingController _orderCommentController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _fetchAddresses();
  }

  @override
  void dispose() {
    _orderCommentController.dispose();
    super.dispose();
  }

  Future<void> _fetchAddresses() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString("accessToken");
      final userId = prefs.getInt('userId');

      if (userId == null) {
        setState(() {
          _errorMessage = "No se encontró el ID de usuario";
          _isLoadingAddresses = false;
        });
        return;
      }

      final url = Uri.parse("${ENV.API_URL}/api/addresses/?id=$userId");

      // Ajusta la URL base según tu configuración
      final response = await http.get(
        url,
        headers: {"Content-Type": "application/json", "Authorization": "Bearer $token"},
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        setState(() {
          _addresses = data.map((json) => Address.fromJson(json)).toList();
          if (_addresses.isNotEmpty) {
            _selectedAddress = _addresses.first;
          }
          _isLoadingAddresses = false;
        });

        // Calcular delivery fee si hay dirección seleccionada
        if (_selectedAddress != null) {
          _calculateDeliveryFee();
        }
      } else {
        setState(() {
          _errorMessage = "Error al cargar direcciones";
          _isLoadingAddresses = false;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = "Error de conexión: $e";
        _isLoadingAddresses = false;
      });
    }
  }

  /// Calcula el delivery fee basándose en la dirección seleccionada
  Future<void> _calculateDeliveryFee() async {
    final cart = Provider.of<CartProvider>(context, listen: false);

    if (_selectedAddress == null || cart.items.isEmpty) {
      setState(() {
        _deliveryFee = null;
      });
      return;
    }

    setState(() {
      _isCalculatingDeliveryFee = true;
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString("accessToken");

      // Obtener storeId del primer item (asumiendo que todos son de la misma tienda)
      final storeId = cart.items.first.storeId;

      // Obtener información de la tienda
      final storeResponse = await http.get(
        Uri.parse("${ENV.API_URL}/api/stores/$storeId/"),
        headers: {"Content-Type": "application/json", "Authorization": "Bearer $token"},
      );

      if (storeResponse.statusCode == 200) {
        final storeData = json.decode(storeResponse.body);
        final storeLat = storeData['latitude'] as double?;
        final storeLon = storeData['longitude'] as double?;

        if (storeLat != null && storeLon != null) {
          // Calcular delivery fee basándose en la distancia
          final deliveryFee = DistanceUtils.calculateDeliveryFee(
            storeLat,
            storeLon,
            _selectedAddress!.latitude,
            _selectedAddress!.longitude,
          );

          debugPrint('✅ Delivery fee calculado: \$${deliveryFee.toStringAsFixed(2)}');

          setState(() {
            _deliveryFee = deliveryFee;
            _isCalculatingDeliveryFee = false;
          });
        } else {
          setState(() {
            _deliveryFee = 2.50; // Valor por defecto
            _isCalculatingDeliveryFee = false;
          });
        }
      } else {
        setState(() {
          _deliveryFee = 2.50; // Valor por defecto
          _isCalculatingDeliveryFee = false;
        });
      }
    } catch (e) {
      debugPrint('⚠️ Error calculando delivery fee: $e');
      setState(() {
        _deliveryFee = 2.50; // Valor por defecto
        _isCalculatingDeliveryFee = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final cart = Provider.of<CartProvider>(context);

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text("Tu carrito", style: TextStyle(fontWeight: FontWeight.w600)),
        backgroundColor: const Color(0xFF2563EB), // Azul principal
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: cart.items.isEmpty
          ? Center(child: Text("Tu carrito está vacío", style: TextStyle(fontSize: 18)))
          : Column(
              children: [
                // ---- Selector de dirección ----
                _buildAddressSelector(),
                // ---- Campo de comentario ----
                _buildCommentSection(),
                Expanded(
                  child: ListView.builder(
                    itemCount: cart.items.length,
                    itemBuilder: (context, index) {
                      final item = cart.items[index];

                      return Card(
                        margin: const EdgeInsets.all(10),
                        child: ListTile(
                          title: Text(item.name),
                          subtitle: Text("Precio: \$${item.price.toStringAsFixed(2)}"),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(icon: Icon(Icons.remove_circle), onPressed: () => cart.decreaseQty(item.id)),
                              Text("${item.quantity}"),
                              IconButton(icon: Icon(Icons.add_circle), onPressed: () => cart.increaseQty(item.id)),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),

                // ---- Resumen de costos ----
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      // Subtotal
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text("Subtotal", style: TextStyle(fontSize: 16, color: Colors.grey[700])),
                          Text(
                            "\$${cart.subtotal.toStringAsFixed(2)}",
                            style: TextStyle(fontSize: 16, color: Colors.grey[700]),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),

                      // Delivery fee
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.delivery_dining, size: 18, color: Colors.grey[700]),
                              const SizedBox(width: 6),
                              Text("Costo de envío", style: TextStyle(fontSize: 16, color: Colors.grey[700])),
                            ],
                          ),
                          _isCalculatingDeliveryFee
                              ? SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                              : Text(
                                  _deliveryFee != null ? "\$${_deliveryFee!.toStringAsFixed(2)}" : "---",
                                  style: TextStyle(fontSize: 16, color: Colors.grey[700]),
                                ),
                        ],
                      ),

                      const Divider(height: 24, thickness: 1.5),

                      // Total
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            "Total",
                            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF1E1E1E)),
                          ),
                          Text(
                            _deliveryFee != null
                                ? "\$${(cart.subtotal + _deliveryFee!).toStringAsFixed(2)}"
                                : "\$${cart.subtotal.toStringAsFixed(2)}",
                            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF2563EB)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // ---- Botón Continuar ----
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          minimumSize: const Size(double.infinity, 56),
                          backgroundColor: const Color(0xFF2563EB), // Azul principal
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          elevation: 2,
                        ),
                        onPressed: (_selectedAddress == null || _deliveryFee == null)
                            ? null // Deshabilitar botón si no hay dirección o delivery fee
                            : () {
                                if (cart.items.isEmpty) return;

                                // Obtener storeId del primer item
                                final storeId = cart.items.first.storeId;

                                // Crear argumentos para pantalla de pago
                                final paymentArgs = PaymentArguments(
                                  storeId: storeId,
                                  address: _selectedAddress!,
                                  subtotal: cart.subtotal,
                                  deliveryFee: _deliveryFee!,
                                  orderComment: _orderCommentController.text.trim().isEmpty
                                      ? null
                                      : _orderCommentController.text.trim(),
                                );

                                Navigator.push(
                                  context,
                                  MaterialPageRoute(builder: (context) => PaymentScreen(args: paymentArgs)),
                                );
                              },
                        child: const Text(
                          "Continuar con el pago",
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildCommentSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        border: Border(bottom: BorderSide(color: Colors.grey[300]!)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.comment, color: Color(0xFF2563EB)),
              const SizedBox(width: 8),
              Text("Comentarios sobre el pedido", style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _orderCommentController,
            maxLines: 3,
            decoration: InputDecoration(
              hintText: "Ej: Sin cebolla, tocar timbre 3 veces, dejar en portería...",
              hintStyle: TextStyle(fontSize: 14, color: Colors.grey[400]),
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: Colors.grey[300]!),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: Colors.grey[300]!),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: Color(0xFF2563EB), width: 2),
              ),
              contentPadding: EdgeInsets.all(12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAddressSelector() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        border: Border(bottom: BorderSide(color: Colors.grey[300]!)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.location_on, color: Colors.red),
              const SizedBox(width: 8),
              Text("Dirección de entrega", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 12),

          if (_isLoadingAddresses)
            Center(child: CircularProgressIndicator())
          else if (_errorMessage != null)
            Text(_errorMessage!, style: TextStyle(color: Colors.red))
          else if (_addresses.isEmpty)
            Text("No tienes direcciones guardadas")
          else
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey[300]!),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<Address>(
                  isExpanded: true,
                  value: _selectedAddress,
                  icon: Icon(Icons.keyboard_arrow_down),
                  items: _addresses.map((address) {
                    return DropdownMenuItem<Address>(
                      value: address,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(address.name, style: TextStyle(fontWeight: FontWeight.bold)),
                          Text(
                            address.description,
                            style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                  onChanged: (Address? newValue) {
                    setState(() {
                      _selectedAddress = newValue;
                    });
                    // Recalcular delivery fee cuando cambie la dirección
                    if (newValue != null) {
                      _calculateDeliveryFee();
                    }
                  },
                  selectedItemBuilder: (context) {
                    return _addresses.map((address) {
                      return Container(
                        alignment: Alignment.centerLeft,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(address.name, style: TextStyle(fontWeight: FontWeight.bold)),
                            Text(
                              address.description,
                              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      );
                    }).toList();
                  },
                ),
              ),
            ),
        ],
      ),
    );
  }
}

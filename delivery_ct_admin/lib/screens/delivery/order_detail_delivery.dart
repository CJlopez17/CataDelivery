import 'package:delivery_ct_admin/config/env.dart';
import 'package:delivery_ct_admin/screens/chat_screen.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

class OrderDetailDelivery extends StatefulWidget {
  final Map order;

  const OrderDetailDelivery({super.key, required this.order});

  @override
  State<OrderDetailDelivery> createState() => _OrderDetailDeliveryState();
}

class _OrderDetailDeliveryState extends State<OrderDetailDelivery> {
  bool loading = true;
  Map? storeInfo;
  Map? clientInfo;
  Map? addressInfo;
  int? currentUserId;
  bool isMyOrder = false;
  bool canAcceptOrder = false;

  MapboxMap? mapboxMap;
  PointAnnotationManager? pointManager;
  PointAnnotation? marker;

  @override
  void initState() {
    super.initState();
    initializeOrder();
  }

  Future<void> initializeOrder() async {
    final prefs = await SharedPreferences.getInstance();
    currentUserId = prefs.getInt("userId");

    // Verificar si este pedido ya es del rider actual
    if (widget.order['rider'] != null && widget.order['rider'] == currentUserId) {
      isMyOrder = true;
      canAcceptOrder = false;
    } else {
      // Es un pedido disponible, verificar si el rider puede aceptarlo
      isMyOrder = false;
      await checkCanAcceptOrder();
    }

    fetchOrderDetails();
  }

  Future<void> checkCanAcceptOrder() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString("accessToken");

    try {
      final response = await http.get(
        Uri.parse("${ENV.API_URL}/api/orders/active_order/"),
        headers: {"Content-Type": "application/json", "Authorization": "Bearer $token"},
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        // Si tiene un pedido activo, no puede aceptar otro
        setState(() {
          canAcceptOrder = !data['has_active_order'];
        });
      } else {
        setState(() {
          canAcceptOrder = true;
        });
      }
    } catch (e) {
      setState(() {
        canAcceptOrder = true;
      });
    }
  }

  Future<void> fetchOrderDetails() async {
    // Primero intentar usar datos anidados si están disponibles
    if (widget.order.containsKey('store_data') &&
        widget.order.containsKey('client_data') &&
        widget.order.containsKey('delivery_address_data')) {
      // Usar datos anidados directamente
      setState(() {
        storeInfo = widget.order['store_data'];
        clientInfo = widget.order['client_data'];
        addressInfo = widget.order['delivery_address_data'];
        loading = false;
      });

      // Agregar marcador en el mapa
      if (addressInfo != null) {
        _addMarker(addressInfo!['latitude'], addressInfo!['longitude']);
      }
      return;
    }

    // Si no hay datos anidados, hacer consultas individuales
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString("accessToken");

    try {
      // Obtener información de la tienda
      final storeResponse = await http.get(
        Uri.parse("${ENV.API_URL}/api/stores/${widget.order['store']}/"),
        headers: {"Content-Type": "application/json", "Authorization": "Bearer $token"},
      );

      // Obtener información del cliente
      final clientResponse = await http.get(
        Uri.parse("${ENV.API_URL}/api/users/${widget.order['client']}/"),
        headers: {"Content-Type": "application/json", "Authorization": "Bearer $token"},
      );

      // Obtener información de la dirección (usar delivery_address en lugar de address)
      final addressResponse = await http.get(
        Uri.parse("${ENV.API_URL}/api/addresses/${widget.order['delivery_address']}/"),
        headers: {"Content-Type": "application/json", "Authorization": "Bearer $token"},
      );

      if (storeResponse.statusCode == 200 && clientResponse.statusCode == 200 && addressResponse.statusCode == 200) {
        setState(() {
          storeInfo = jsonDecode(storeResponse.body);
          clientInfo = jsonDecode(clientResponse.body);
          addressInfo = jsonDecode(addressResponse.body);
          loading = false;
        });

        // Agregar marcador en el mapa
        if (addressInfo != null) {
          _addMarker(addressInfo!['latitude'], addressInfo!['longitude']);
        }
      } else {
        setState(() => loading = false);
      }
    } catch (e) {
      setState(() => loading = false);
    }
  }

  Future<void> _addMarker(double lat, double lng) async {
    if (mapboxMap == null) return;

    pointManager ??= await mapboxMap!.annotations.createPointAnnotationManager();

    // eliminar marcador anterior
    if (marker != null) {
      await pointManager!.delete(marker!);
    }

    // crear marcador nuevo
    marker = await pointManager!.create(
      PointAnnotationOptions(
        geometry: Point(coordinates: Position(lng, lat)),
        iconSize: 1.5,
        iconColor: const Color(0xFFFF6F3C).value,
        iconImage: "marker",
      ),
    );
  }

  Future<void> acceptOrder() async {
    if (!canAcceptOrder) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Ya tienes un pedido en progreso. Debes completarlo primero."),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString("accessToken");
    final riderId = prefs.getInt("userId");

    try {
      final response = await http.patch(
        Uri.parse("${ENV.API_URL}/api/orders/${widget.order['id']}/"),
        headers: {"Content-Type": "application/json", "Authorization": "Bearer $token"},
        body: jsonEncode({
          "status": 4, // En Camino
          "rider": riderId,
        }),
      );

      if (response.statusCode == 200) {
        if (!mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text("Pedido aceptado exitosamente"), backgroundColor: Colors.green));
        Navigator.pop(context, true); // Retornar true para indicar que se aceptó
      } else {
        if (!mounted) return;
        final errorData = jsonDecode(response.body);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(errorData['detail'] ?? "Error al aceptar el pedido"), backgroundColor: Colors.red),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red));
    }
  }

  Future<void> markDelivered() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString("accessToken");

    try {
      final response = await http.post(
        Uri.parse("${ENV.API_URL}/api/orders/${widget.order['id']}/mark_delivered/"),
        headers: {"Content-Type": "application/json", "Authorization": "Bearer $token"},
      );

      if (response.statusCode == 200) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Pedido marcado como entregado exitosamente"), backgroundColor: Colors.green),
        );
        Navigator.pop(context, true); // Retornar true para actualizar la lista
      } else {
        if (!mounted) return;
        final errorData = jsonDecode(response.body);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(errorData['detail'] ?? "Error al marcar como entregado"), backgroundColor: Colors.red),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red));
    }
  }

  Widget? _buildChatFab() {
    // Rider chatea con el cliente cuando el pedido es suyo y está en ruta
    if (!isMyOrder || widget.order['status'] != 4) return null;
    final clientId = widget.order['client'];
    if (clientId == null) return null;

    final clientName = clientInfo != null
        ? "${clientInfo!['first_name'] ?? ''} ${clientInfo!['last_name'] ?? ''}".trim()
        : "Cliente";

    return FloatingActionButton.extended(
      onPressed: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ChatScreen(
              orderId: widget.order['id'],
              otherUserId: clientId,
              otherUserName: clientName.isNotEmpty ? clientName : "Cliente",
            ),
          ),
        );
      },
      backgroundColor: const Color(0xFF2563EB),
      icon: const Icon(Icons.chat, color: Colors.white),
      label: const Text(
        "Chat con cliente",
        style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Pedido #${widget.order['id']}"),
        backgroundColor: const Color(0xFF2563EB),
        foregroundColor: Colors.white,
      ),
      floatingActionButton: _buildChatFab(),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Mapa
                  if (addressInfo != null)
                    SizedBox(
                      height: 300,
                      child: MapWidget(
                        key: const ValueKey("delivery_map"),
                        styleUri: MapboxStyles.MAPBOX_STREETS,
                        cameraOptions: CameraOptions(
                          center: Point(coordinates: Position(addressInfo!['longitude'], addressInfo!['latitude'])),
                          zoom: 15,
                        ),
                        onMapCreated: (controller) {
                          mapboxMap = controller;
                          _addMarker(addressInfo!['latitude'], addressInfo!['longitude']);
                        },
                      ),
                    ),

                  // Información del pedido
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Información de la tienda
                        _buildSectionTitle("Información de la Tienda", Icons.store),
                        const SizedBox(height: 8),
                        Card(
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildDetailRow("Nombre", storeInfo?['name'] ?? "N/A"),
                                _buildDetailRow("Dirección", storeInfo?['address'] ?? "N/A"),
                                _buildDetailRow("Teléfono", storeInfo?['phone_number'] ?? "N/A"),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),

                        // Información del cliente
                        _buildSectionTitle("Información del Cliente", Icons.person),
                        const SizedBox(height: 8),
                        Card(
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildDetailRow(
                                  "Nombre",
                                  "${clientInfo?['first_name'] ?? ''} ${clientInfo?['last_name'] ?? ''}",
                                ),
                                _buildDetailRow("Teléfono", clientInfo?['phone_number'] ?? "N/A"),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),

                        // Dirección de entrega
                        _buildSectionTitle("Dirección de Entrega", Icons.location_on),
                        const SizedBox(height: 8),
                        Card(
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildDetailRow("Descripción", addressInfo?['description'] ?? "N/A"),
                                _buildDetailRow(
                                  "Coordenadas",
                                  "${addressInfo?['latitude']?.toStringAsFixed(6) ?? 'N/A'}, ${addressInfo?['longitude']?.toStringAsFixed(6) ?? 'N/A'}",
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        _buildSectionTitle("Comentario del cliente", Icons.comment),
                        const SizedBox(height: 8),
                        Card(
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [_buildDetailRow("Comentario", widget.order['order_comment'].toString())],
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),

                        // Detalles del pedido
                        _buildSectionTitle("Detalles del Pedido", Icons.receipt),
                        const SizedBox(height: 8),
                        Card(
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildDetailRow(
                                  "Subtotal",
                                  "\$${widget.order['subtotal']?.toStringAsFixed(2) ?? '0.00'}",
                                ),
                                _buildDetailRow(
                                  "Envío",
                                  "\$${widget.order['delivery_fee']?.toStringAsFixed(2) ?? '0.00'}",
                                ),
                                const Divider(height: 20),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    const Text("Total:", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                                    Text(
                                      "\$${widget.order['total']?.toStringAsFixed(2) ?? '0.00'}",
                                      style: const TextStyle(
                                        fontSize: 20,
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFFFF6F3C),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 30),

                        // Botones según el estado del pedido
                        if (isMyOrder && widget.order['status'] == 4)
                          // Botón de marcar como entregado (pedido activo del rider)
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              onPressed: markDelivered,
                              icon: const Icon(Icons.check_circle_outline),
                              label: const Text("Marcar como Entregado", style: TextStyle(fontSize: 16)),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF10B981),
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                            ),
                          )
                        else if (!isMyOrder && widget.order['status'] == 3)
                          // Botón de aceptar pedido (pedido disponible)
                          Column(
                            children: [
                              if (!canAcceptOrder)
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: Colors.orange.shade50,
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: Colors.orange.shade300),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(Icons.info_outline, color: Colors.orange.shade700),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          "Ya tienes un pedido en progreso. Complétalo antes de aceptar otro.",
                                          style: TextStyle(color: Colors.orange.shade900, fontSize: 14),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              const SizedBox(height: 12),
                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton.icon(
                                  onPressed: canAcceptOrder ? acceptOrder : null,
                                  icon: const Icon(Icons.check_circle),
                                  label: const Text(
                                    "Aceptar Pedido y Comenzar Entrega",
                                    style: TextStyle(fontSize: 16),
                                  ),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF2563EB),
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(vertical: 16),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                    disabledBackgroundColor: Colors.grey.shade300,
                                    disabledForegroundColor: Colors.grey.shade600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        const SizedBox(height: 16),
                      ],
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildSectionTitle(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, color: const Color(0xFF2563EB)),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF1E1E1E)),
        ),
      ],
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text("$label:", style: TextStyle(color: Colors.grey[600], fontSize: 14)),
          ),
          Expanded(
            child: Text(value, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
          ),
        ],
      ),
    );
  }
}

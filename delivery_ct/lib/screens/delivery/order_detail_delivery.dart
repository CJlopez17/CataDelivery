import 'dart:async';
import 'dart:convert';
import 'package:delivery_ct/config/env.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

class OrderDetailDelivery extends StatefulWidget {
  final int orderId;

  const OrderDetailDelivery({super.key, required this.orderId});

  @override
  State<OrderDetailDelivery> createState() => _OrderDetailDeliveryState();
}

class _OrderDetailDeliveryState extends State<OrderDetailDelivery> {
  Map<String, dynamic>? orderData;
  bool isLoading = true;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _fetchOrderDetails();
    // Actualizar cada 10 segundos
    _timer = Timer.periodic(const Duration(seconds: 10), (timer) {
      if (mounted) {
        _fetchOrderDetails(showLoading: false);
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _timer = null;
    super.dispose();
  }

  Future<void> _fetchOrderDetails({bool showLoading = true}) async {
    if (showLoading && mounted) {
      setState(() => isLoading = true);
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString("accessToken");

      // Obtener datos de la orden (ahora con datos anidados)
      final orderUrl = Uri.parse("${ENV.API_URL}/api/orders/${widget.orderId}/");
      final orderResponse = await http.get(
        orderUrl,
        headers: {"Content-Type": "application/json", "Authorization": "Bearer $token"},
      );

      if (orderResponse.statusCode == 200) {
        final order = jsonDecode(orderResponse.body);

        if (mounted) {
          setState(() {
            orderData = order;
            isLoading = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => isLoading = false);
      }
    }
  }

  Future<void> _updateOrderStatus(int newStatus) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString("accessToken");

      final url = Uri.parse("${ENV.API_URL}/api/orders/${widget.orderId}/");
      final response = await http.patch(
        url,
        headers: {"Content-Type": "application/json", "Authorization": "Bearer $token"},
        body: jsonEncode({"status": newStatus}),
      );

      if (response.statusCode == 200) {
        if (!mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Estado actualizado correctamente"), backgroundColor: Colors.green),
        );

        _fetchOrderDetails();
      } else {
        if (!mounted) return;

        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text("Error al actualizar el estado"), backgroundColor: Colors.red));
      }
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red));
    }
  }

  Future<void> _makePhoneCall(String phoneNumber) async {
    final Uri launchUri = Uri(scheme: 'tel', path: phoneNumber);
    if (await canLaunchUrl(launchUri)) {
      await launchUrl(launchUri);
    } else {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("No se puede realizar la llamada"), backgroundColor: Colors.red));
    }
  }

  String _getStatusText(int status) {
    switch (status) {
      case 1:
        return "Enviado";
      case 2:
        return "Recibido";
      case 3:
        return "Preparando";
      case 4:
        return "En Camino";
      case 5:
        return "Entregado";
      default:
        return "Desconocido";
    }
  }

  Color _getStatusColor(int status) {
    switch (status) {
      case 1:
        return Colors.orange;
      case 2:
        return Colors.blue;
      case 3:
        return Colors.purple;
      case 4:
        return Colors.teal;
      case 5:
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  String _formatDateTime(String? dateTime) {
    if (dateTime == null) return "N/A";
    try {
      final dt = DateTime.parse(dateTime);
      return "${dt.day}/${dt.month}/${dt.year} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}";
    } catch (e) {
      return dateTime;
    }
  }

  String _formatPaymentMethod(String? method) {
    if (method == null) return "N/A";
    switch (method) {
      case 'cash':
        return 'Efectivo';
      case 'ahorita':
        return 'Ahorita';
      case 'deuna':
        return 'De Una';
      case 'megowallet':
        return 'MegoWallet';
      case 'jetfaster':
        return 'Jet Faster';
      default:
        return method;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return Scaffold(
        appBar: AppBar(
          title: const Text("Detalle del Pedido"),
          backgroundColor: const Color(0xFF2563EB),
          foregroundColor: Colors.white,
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (orderData == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text("Detalle del Pedido"),
          backgroundColor: const Color(0xFF2563EB),
          foregroundColor: Colors.white,
        ),
        body: const Center(child: Text("No se pudo cargar la información del pedido")),
      );
    }

    final status = orderData!['status'] ?? 0;
    final storeData = orderData!['store_data'];
    final clientData = orderData!['client_data'];
    final addressData = orderData!['delivery_address_data'];

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: Text("Pedido #${widget.orderId}"),
        backgroundColor: const Color(0xFF2563EB),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: RefreshIndicator(
        onRefresh: () => _fetchOrderDetails(),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          physics: const AlwaysScrollableScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Estado del pedido
              Card(
                elevation: 3,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text("Estado del Pedido", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: _getStatusColor(status),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              _getStatusText(status),
                              style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Botones de cambio de estado
                      if (status == 4) // En camino
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: () => _updateOrderStatus(5),
                            icon: const Icon(Icons.done_all),
                            label: const Text("Marcar como Entregado"),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // Información del cliente
              if (clientData != null)
                Card(
                  elevation: 3,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.person, color: Colors.grey[700]),
                            const SizedBox(width: 8),
                            const Text(
                              "Información del Cliente",
                              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                        const Divider(height: 20),
                        _buildInfoRow("Nombre:", "${clientData['first_name'] ?? ''} ${clientData['last_name'] ?? ''}"),
                        if (clientData['phone_number'] != null && clientData['phone_number'].toString().isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text("Teléfono: ${clientData['phone_number']}", style: const TextStyle(fontSize: 15)),
                                IconButton(
                                  onPressed: () => _makePhoneCall(clientData['phone_number']),
                                  icon: const Icon(Icons.phone, color: Color(0xFF2563EB)),
                                  tooltip: "Llamar",
                                ),
                              ],
                            ),
                          ),
                        _buildInfoRow("Email:", clientData['email'] ?? 'N/A'),
                      ],
                    ),
                  ),
                ),

              const SizedBox(height: 16),

              // Dirección de entrega
              if (addressData != null)
                Card(
                  elevation: 3,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.location_on, color: Colors.grey[700]),
                            const SizedBox(width: 8),
                            const Text(
                              "Dirección de Entrega",
                              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(width: 8),
                            const Text(
                              "Selección una dirección de entrega para este pedido",
                              style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                        const Divider(height: 20),
                        _buildInfoRow("Nombre:", addressData['name'] ?? 'N/A'),
                        _buildInfoRow("Dirección:", addressData['description'] ?? 'N/A'),
                      ],
                    ),
                  ),
                ),

              const SizedBox(height: 16),

              // Información de la tienda
              if (storeData != null)
                Card(
                  elevation: 3,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.store, color: Colors.grey[700]),
                            const SizedBox(width: 8),
                            const Text(
                              "Información de la Tienda",
                              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                        const Divider(height: 20),
                        _buildInfoRow("Tienda:", storeData['name'] ?? 'N/A'),
                        _buildInfoRow("Dirección:", storeData['address'] ?? 'N/A'),
                      ],
                    ),
                  ),
                ),

              const SizedBox(height: 16),

              // Información del pedido
              Card(
                elevation: 3,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.receipt, color: Colors.grey[700]),
                          const SizedBox(width: 8),
                          const Text(
                            "Información del Pedido",
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                      const Divider(height: 20),
                      _buildInfoRow("Fecha:", _formatDateTime(orderData!['dt'])),
                      _buildInfoRow("Método de pago:", _formatPaymentMethod(orderData!['payment_method'])),
                      _buildInfoRow("Subtotal:", "\$${orderData!['subtotal']?.toStringAsFixed(2) ?? '0.00'}"),
                      _buildInfoRow(
                        "Tarifa de envío:",
                        "\$${orderData!['delivery_fee']?.toStringAsFixed(2) ?? '0.00'}",
                      ),
                      // Mostrar comentario si existe
                      if (orderData!['order_comment'] != null &&
                          orderData!['order_comment'].toString().trim().isNotEmpty)
                        Container(
                          margin: const EdgeInsets.only(top: 8, bottom: 8),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.amber[50],
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.amber[200]!),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(Icons.comment, size: 18, color: Colors.amber[700]),
                                  const SizedBox(width: 6),
                                  Text(
                                    "Comentario del cliente:",
                                    style: TextStyle(fontWeight: FontWeight.bold, color: Colors.amber[900]),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Text(orderData!['order_comment'].toString(), style: const TextStyle(fontSize: 14)),
                            ],
                          ),
                        ),
                      const Divider(height: 20),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text("Total:", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                          Text(
                            "\$${orderData!['total']?.toStringAsFixed(2) ?? '0.00'}",
                            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.green),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(fontWeight: FontWeight.w600, color: Colors.grey[700], fontSize: 15),
          ),
          const SizedBox(width: 8),
          Expanded(child: Text(value, style: const TextStyle(fontSize: 15))),
        ],
      ),
    );
  }
}

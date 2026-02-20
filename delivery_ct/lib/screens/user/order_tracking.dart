import 'dart:async';
import 'dart:convert';
import 'package:delivery_ct/config/env.dart';
import 'package:delivery_ct/screens/user/chat_screen.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class OrderTrackingScreen extends StatefulWidget {
  final int orderId;

  const OrderTrackingScreen({super.key, required this.orderId});

  @override
  State<OrderTrackingScreen> createState() => _OrderTrackingScreenState();
}

class _OrderTrackingScreenState extends State<OrderTrackingScreen> {
  Map<String, dynamic>? orderData;
  List<dynamic> orderProducts = [];
  Map<String, dynamic>? storeData;
  Map<String, dynamic>? addressData;
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

      // Obtener datos de la orden
      final orderUrl = Uri.parse("${ENV.API_URL}/api/orders/${widget.orderId}/");
      final orderResponse = await http.get(
        orderUrl,
        headers: {
          "Content-Type": "application/json",
          "Authorization": "Bearer $token",
        },
      );

      if (orderResponse.statusCode == 200) {
        final order = jsonDecode(orderResponse.body);

        // Obtener productos de la orden
        final productsUrl = Uri.parse(
          "${ENV.API_URL}/api/order-products/?order=${widget.orderId}",
        );
        final productsResponse = await http.get(
          productsUrl,
          headers: {
            "Content-Type": "application/json",
            "Authorization": "Bearer $token",
          },
        );

        // Obtener datos de la tienda
        final storeUrl = Uri.parse("${ENV.API_URL}/api/stores/${order['store']}/");
        final storeResponse = await http.get(
          storeUrl,
          headers: {
            "Content-Type": "application/json",
            "Authorization": "Bearer $token",
          },
        );

        // Obtener datos de la dirección
        final addressUrl = Uri.parse(
          "${ENV.API_URL}/api/addresses/${order['delivery_address']}/",
        );
        final addressResponse = await http.get(
          addressUrl,
          headers: {
            "Content-Type": "application/json",
            "Authorization": "Bearer $token",
          },
        );

        if (mounted) {
          setState(() {
            orderData = order;
            orderProducts = productsResponse.statusCode == 200
                ? jsonDecode(productsResponse.body)
                : [];
            storeData = storeResponse.statusCode == 200
                ? jsonDecode(storeResponse.body)
                : null;
            addressData = addressResponse.statusCode == 200
                ? jsonDecode(addressResponse.body)
                : null;
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
      case 6:
        return "Cancelado";
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
      case 6:
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  IconData _getStatusIcon(int status) {
    switch (status) {
      case 1:
        return Icons.send;
      case 2:
        return Icons.check_circle;
      case 3:
        return Icons.restaurant;
      case 4:
        return Icons.delivery_dining;
      case 5:
        return Icons.done_all;
      case 6:
        return Icons.cancel;
      default:
        return Icons.help_outline;
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

  /// Determina si el botón de chat debe mostrarse y a quién chatear.
  Widget? _buildChatFab() {
    if (orderData == null) return null;
    final status = orderData!['status'] ?? 1;

    // Solo mostrar chat en estados activos (1-4)
    if (status >= 5) return null;

    // Status 1-3: chat con el comercio
    if (status >= 1 && status <= 3) {
      final storeUserId = storeData?['userprofile'];
      if (storeUserId == null) return null;
      final storeName = storeData?['name'] ?? 'Comercio';

      return FloatingActionButton.extended(
        onPressed: () => _openChat(storeUserId, storeName),
        backgroundColor: const Color(0xFF2563EB),
        icon: const Icon(Icons.chat, color: Colors.white),
        label: const Text(
          "Chat con comercio",
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
        ),
      );
    }

    // Status 4: chat con el rider
    if (status == 4) {
      final riderId = orderData!['rider'];
      if (riderId == null) return null;

      return FloatingActionButton.extended(
        onPressed: () => _openChat(riderId, "Rider"),
        backgroundColor: Colors.teal,
        icon: const Icon(Icons.chat, color: Colors.white),
        label: const Text(
          "Chat con rider",
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
        ),
      );
    }

    return null;
  }

  void _openChat(int otherUserId, String otherUserName) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChatScreen(
          orderId: widget.orderId,
          otherUserId: otherUserId,
          otherUserName: otherUserName,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        // Al salir, ir al home
        Navigator.popUntil(context, (route) => route.isFirst);
        return false;
      },
      child: Scaffold(
        backgroundColor: Colors.grey[50],
        appBar: AppBar(
          title: Text(
            "Pedido #${widget.orderId}",
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          backgroundColor: const Color(0xFF2563EB), // Azul principal
          foregroundColor: Colors.white,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () {
              Navigator.popUntil(context, (route) => route.isFirst);
            },
          ),
        ),
        floatingActionButton: _buildChatFab(),
        body: isLoading
            ? const Center(child: CircularProgressIndicator())
            : orderData == null
                ? const Center(child: Text("Error al cargar el pedido"))
                : RefreshIndicator(
                    onRefresh: () => _fetchOrderDetails(showLoading: false),
                    child: SingleChildScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Estado del pedido
                          _buildStatusSection(),
                          const SizedBox(height: 16),

                          // Progreso del pedido
                          _buildProgressSection(),
                          const SizedBox(height: 16),

                          // Información de la tienda
                          _buildStoreSection(),
                          const SizedBox(height: 16),

                          // Productos del pedido
                          _buildProductsSection(),
                          const SizedBox(height: 16),

                          // Dirección de entrega
                          _buildAddressSection(),
                          const SizedBox(height: 16),

                          // Resumen de costos
                          _buildCostSummarySection(),
                        ],
                      ),
                    ),
                  ),
      ),
    );
  }

  Widget _buildStatusSection() {
    final status = orderData!['status'] ?? 1;
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Icon(
              _getStatusIcon(status),
              size: 64,
              color: _getStatusColor(status),
            ),
            const SizedBox(height: 16),
            Text(
              _getStatusText(status),
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: _getStatusColor(status),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _getStatusDescription(status),
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
              ),
            ),
            // Mostrar motivo de cancelación si existe
            if (status == 6 &&
                orderData!['cancellation_reason'] != null &&
                orderData!['cancellation_reason'].toString().trim().isNotEmpty) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red[200]!),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.info_outline, size: 18, color: Colors.red[700]),
                        const SizedBox(width: 6),
                        Text(
                          "Motivo de cancelación:",
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.red[900],
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      orderData!['cancellation_reason'].toString(),
                      style: const TextStyle(fontSize: 14),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _getStatusDescription(int status) {
    switch (status) {
      case 1:
        return "Tu pedido ha sido enviado al comercio. Espera su confirmación.";
      case 2:
        return "El comercio ha recibido tu pedido y pronto comenzará a prepararlo.";
      case 3:
        return "Tu pedido está siendo preparado en este momento.";
      case 4:
        return "Un rider está en camino con tu pedido.";
      case 5:
        return "Tu pedido ha sido entregado exitosamente.";
      case 6:
        return "Lo sentimos, el comercio ha cancelado tu pedido.";
      default:
        return "";
    }
  }

  Widget _buildProgressSection() {
    final currentStatus = orderData!['status'] ?? 1;
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Progreso del pedido",
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 20),
            _buildProgressStep(1, "Enviado", currentStatus >= 1),
            _buildProgressStep(2, "Recibido", currentStatus >= 2),
            _buildProgressStep(3, "Preparando", currentStatus >= 3),
            _buildProgressStep(4, "En Camino", currentStatus >= 4),
            _buildProgressStep(5, "Entregado", currentStatus >= 5, isLast: true),
          ],
        ),
      ),
    );
  }

  Widget _buildProgressStep(int step, String label, bool isCompleted,
      {bool isLast = false}) {
    return Row(
      children: [
        Column(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isCompleted ? Colors.green : Colors.grey[300],
              ),
              child: Center(
                child: Icon(
                  isCompleted ? Icons.check : Icons.circle,
                  color: Colors.white,
                  size: 20,
                ),
              ),
            ),
            if (!isLast)
              Container(
                width: 2,
                height: 40,
                color: isCompleted ? Colors.green : Colors.grey[300],
              ),
          ],
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Padding(
            padding: EdgeInsets.only(bottom: isLast ? 0 : 40),
            child: Text(
              label,
              style: TextStyle(
                fontSize: 16,
                fontWeight: isCompleted ? FontWeight.bold : FontWeight.normal,
                color: isCompleted ? Colors.black : Colors.grey[600],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStoreSection() {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.store, color: const Color(0xFF2563EB)), // Azul principal
                const SizedBox(width: 8),
                const Text(
                  "Local comercial",
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1E1E1E), // Color de texto
                  ),
                ),
              ],
            ),
            const Divider(height: 20),
            if (storeData != null) ...[
              Text(
                storeData!['name'] ?? 'Sin nombre',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              if (storeData!['description'] != null)
                Text(
                  storeData!['description'],
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[700],
                  ),
                ),
            ] else
              const Text("Cargando información de la tienda..."),
          ],
        ),
      ),
    );
  }

  Widget _buildProductsSection() {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.shopping_bag, color: const Color(0xFFFF6F3C)), // Naranja secundario
                const SizedBox(width: 8),
                const Text(
                  "Productos",
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1E1E1E), // Color de texto
                  ),
                ),
              ],
            ),
            const Divider(height: 20),
            if (orderProducts.isEmpty)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(20),
                  child: Text("No se encontraron productos"),
                ),
              )
            else
              ...orderProducts.map((product) {
                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              product['name'] ?? "Producto #${product['product']}",
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              "Cantidad: ${product['quantity']}",
                              style: TextStyle(
                                color: Colors.grey[700],
                                fontSize: 14,
                              ),
                            ),
                            if (product['note'] != null &&
                                product['note'].toString().isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Container(
                                margin: const EdgeInsets.only(top: 4),
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: Colors.yellow[100],
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(
                                      Icons.note,
                                      size: 14,
                                      color: Colors.orange,
                                    ),
                                    const SizedBox(width: 4),
                                    Expanded(
                                      child: Text(
                                        "Nota: ${product['note']}",
                                        style: const TextStyle(fontSize: 12),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      Text(
                        "\$${product['total']?.toStringAsFixed(2) ?? '0.00'}",
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: Colors.green,
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
          ],
        ),
      ),
    );
  }

  Widget _buildAddressSection() {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.location_on, color: const Color(0xFFFF6F3C)), // Naranja secundario
                const SizedBox(width: 8),
                const Text(
                  "Dirección de entrega",
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1E1E1E), // Color de texto
                  ),
                ),
              ],
            ),
            const Divider(height: 20),
            if (addressData != null) ...[
              Text(
                addressData!['name'] ?? 'Sin nombre',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                addressData!['description'] ?? 'Sin descripción',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[700],
                ),
              ),
            ] else
              const Text("Cargando dirección..."),
          ],
        ),
      ),
    );
  }

  Widget _buildCostSummarySection() {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Resumen del pedido",
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const Divider(height: 20),
            _buildCostRow(
              "Subtotal",
              "\$${orderData!['subtotal']?.toStringAsFixed(2) ?? '0.00'}",
            ),
            const SizedBox(height: 8),
            _buildCostRow(
              "Envío",
              "\$${orderData!['delivery_fee']?.toStringAsFixed(2) ?? '0.00'}",
            ),
            const SizedBox(height: 8),
            _buildCostRow(
              "Método de pago",
              _formatPaymentMethod(orderData!['payment_method']),
            ),
            const SizedBox(height: 8),
            _buildCostRow(
              "Fecha",
              _formatDateTime(orderData!['dt']),
            ),
            const Divider(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  "Total",
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  "\$${orderData!['total']?.toStringAsFixed(2) ?? '0.00'}",
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Colors.green,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCostRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 16),
        ),
        Text(
          value,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
        ),
      ],
    );
  }
}

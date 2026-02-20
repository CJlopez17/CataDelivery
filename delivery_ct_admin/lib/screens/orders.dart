import 'package:delivery_ct_admin/config/env.dart';
import 'package:delivery_ct_admin/data/models/order_product.dart';
import 'package:delivery_ct_admin/screens/chat_screen.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class OrdersPage extends StatefulWidget {
  const OrdersPage({super.key});

  @override
  State<OrdersPage> createState() => _OrdersPageState();
}

class _OrdersPageState extends State<OrdersPage> {
  List orders = [];
  bool loading = true;
  String selectedFilter = "today"; // Filtro por defecto: hoy

  @override
  void initState() {
    super.initState();
    fetchOrders();
  }

  Future<void> fetchOrders() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString("accessToken");
    final storeId = prefs.getInt("storeId");

    // Construir URL con filtro de fecha
    String url = "${ENV.API_URL}/api/orders/?store=$storeId";
    if (selectedFilter != "all") {
      url += "&date_filter=$selectedFilter";
    }

    final uri = Uri.parse(url);

    try {
      final response = await http.get(
        uri,
        headers: {"Content-Type": "application/json", "Authorization": "Bearer $token"},
      );

      if (response.statusCode == 200) {
        setState(() {
          orders = jsonDecode(response.body);
          loading = false;
        });
      } else {
        setState(() => loading = false);
      }
    } catch (e) {
      setState(() => loading = false);
    }
  }

  String getStatusText(int status) {
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

  Color getStatusColor(int status) {
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Pedidos recibidos"),
        backgroundColor: const Color(0xFF2563EB),
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          // Filtros por período
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 4, offset: const Offset(0, 2))],
            ),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildFilterChip("Hoy", "today"),
                  const SizedBox(width: 8),
                  _buildFilterChip("Ayer", "yesterday"),
                  const SizedBox(width: 8),
                  _buildFilterChip("Última semana", "week"),
                  const SizedBox(width: 8),
                  _buildFilterChip("Todos", "all"),
                ],
              ),
            ),
          ),
          // Lista de órdenes
          Expanded(
            child: loading
                ? const Center(child: CircularProgressIndicator())
                : orders.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.shopping_bag_outlined, size: 64, color: Colors.grey[400]),
                        const SizedBox(height: 16),
                        Text("No hay pedidos en este período", style: TextStyle(fontSize: 16, color: Colors.grey[600])),
                      ],
                    ),
                  )
                : RefreshIndicator(
                    onRefresh: fetchOrders,
                    child: ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: orders.length,
                      itemBuilder: (context, index) {
                        final order = orders[index];

                        return Card(
                          margin: const EdgeInsets.only(bottom: 14),
                          elevation: 3,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          child: InkWell(
                            onTap: () async {
                              final result = await Navigator.push(
                                context,
                                MaterialPageRoute(builder: (_) => OrderDetailPage(order: order)),
                              );
                              // Si se actualizó el estado, refrescar la lista
                              if (result == true) {
                                fetchOrders();
                              }
                            },
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        "Pedido #${order['id']}",
                                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                        decoration: BoxDecoration(
                                          color: getStatusColor(order['status']),
                                          borderRadius: BorderRadius.circular(20),
                                        ),
                                        child: Text(
                                          getStatusText(order['status']),
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const Divider(height: 20),
                                  _buildInfoRow(
                                    Icons.calendar_today,
                                    "Fecha",
                                    order['dt'] != null ? _formatDateTime(order['dt']) : "N/A",
                                  ),
                                  const SizedBox(height: 8),
                                  _buildInfoRow(
                                    Icons.payment,
                                    "Método de pago",
                                    _formatPaymentMethod(order['payment_method']),
                                  ),
                                  const SizedBox(height: 8),
                                  _buildInfoRow(
                                    Icons.attach_money,
                                    "Subtotal",
                                    "\$${order['subtotal']?.toStringAsFixed(2) ?? '0.00'}",
                                  ),
                                  const SizedBox(height: 8),
                                  _buildInfoRow(
                                    Icons.delivery_dining,
                                    "Envío",
                                    "\$${order['delivery_fee']?.toStringAsFixed(2) ?? '0.00'}",
                                  ),
                                  const Divider(height: 20),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      const Text("Total:", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                                      Text(
                                        "\$${order['total']?.toStringAsFixed(2) ?? '0.00'}",
                                        style: const TextStyle(
                                          fontSize: 20,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.green,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
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

  Widget _buildFilterChip(String label, String value) {
    final isSelected = selectedFilter == value;
    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        setState(() {
          selectedFilter = value;
          loading = true;
        });
        fetchOrders();
      },
      backgroundColor: Colors.white,
      selectedColor: const Color(0xFF2563EB),
      checkmarkColor: Colors.white,
      labelStyle: TextStyle(
        color: isSelected ? Colors.white : Colors.grey[800],
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 18, color: Colors.grey[600]),
        const SizedBox(width: 8),
        Text("$label: ", style: TextStyle(color: Colors.grey[600], fontSize: 14)),
        Expanded(
          child: Text(value, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
        ),
      ],
    );
  }

  String _formatDateTime(String dateTime) {
    try {
      final dt = DateTime.parse(dateTime);
      return "${dt.day}/${dt.month}/${dt.year} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}";
    } catch (e) {
      return dateTime;
    }
  }

  String _formatPaymentMethod(String method) {
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
}

// ========================================
// PANTALLA DE DETALLE DE LA ORDEN
// ========================================
class OrderDetailPage extends StatefulWidget {
  final Map order;

  const OrderDetailPage({super.key, required this.order});

  @override
  State<OrderDetailPage> createState() => _OrderDetailPageState();
}

class _OrderDetailPageState extends State<OrderDetailPage> {
  List<OrderProduct> orderProducts = [];
  bool loading = true;
  int currentStatus = 1;

  @override
  void initState() {
    super.initState();
    currentStatus = widget.order['status'] ?? 1;
    fetchOrderProducts();
  }

  Future<void> fetchOrderProducts() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString("accessToken");
    final orderId = widget.order['id'];
    final url = Uri.parse("${ENV.API_URL}/api/order-products/?order=$orderId");

    try {
      final response = await http.get(
        url,
        headers: {"Content-Type": "application/json", "Authorization": "Bearer $token"},
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        setState(() {
          orderProducts = data.map((item) => OrderProduct.fromJson(item)).toList();
          loading = false;
        });
      } else {
        setState(() => loading = false);
      }
    } catch (e) {
      setState(() => loading = false);
    }
  }

  Future<void> cancelOrderWithReason(String? reason) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString("accessToken");
    final orderId = widget.order['id'];
    final url = Uri.parse("${ENV.API_URL}/api/orders/$orderId/");

    try {
      final body = {
        "status": 6, // Cancelled
        if (reason != null && reason.trim().isNotEmpty) "cancellation_reason": reason.trim(),
      };

      final response = await http.patch(
        url,
        headers: {"Content-Type": "application/json", "Authorization": "Bearer $token"},
        body: jsonEncode(body),
      );

      if (response.statusCode == 200) {
        setState(() {
          currentStatus = 6;
          widget.order['status'] = 6;
          if (reason != null && reason.trim().isNotEmpty) {
            widget.order['cancellation_reason'] = reason.trim();
          }
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Pedido cancelado correctamente"), backgroundColor: Colors.orange),
          );

          // Programar el Navigator.pop para después del frame actual
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              Navigator.pop(context, true); // Cerrar el detalle del pedido y retornar true para refrescar la lista
            }
          });
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text("Error al cancelar el pedido"), backgroundColor: Colors.red));
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red));
      }
    }
  }

  Future<void> updateOrderStatus(int newStatus) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString("accessToken");
    final orderId = widget.order['id'];
    final url = Uri.parse("${ENV.API_URL}/api/orders/$orderId/");

    try {
      final response = await http.patch(
        url,
        headers: {"Content-Type": "application/json", "Authorization": "Bearer $token"},
        body: jsonEncode({"status": newStatus}),
      );

      if (response.statusCode == 200) {
        setState(() {
          currentStatus = newStatus;
          widget.order['status'] = newStatus;
        });

        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Estado actualizado a: ${_getStatusText(newStatus)}'), backgroundColor: Colors.green),
        );
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Error al actualizar el estado'), backgroundColor: Colors.red));
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
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

  Widget? _buildChatFab() {
    // Store chatea con el cliente mientras el pedido está activo (status 1-4)
    if (currentStatus >= 5) return null;
    final clientId = widget.order['client'];
    if (clientId == null) return null;

    return FloatingActionButton.extended(
      onPressed: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ChatScreen(
              orderId: widget.order['id'],
              otherUserId: clientId,
              otherUserName: "Cliente",
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
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Estado actual
                  Card(
                    elevation: 3,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text("Estado del pedido", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 12),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            decoration: BoxDecoration(
                              color: _getStatusColor(currentStatus),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              _getStatusText(currentStatus),
                              textAlign: TextAlign.center,
                              style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Botones de acción (solo para estados 1, 2, 3)
                  if (currentStatus <= 3) ...[
                    Card(
                      elevation: 3,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text("Acciones", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                            const SizedBox(height: 12),

                            // Botón Aceptar pedido (solo si está en estado 1)
                            if (currentStatus == 1) ...[
                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton.icon(
                                  onPressed: () => updateOrderStatus(2),
                                  icon: const Icon(Icons.check_circle),
                                  label: const Text("Aceptar Pedido"),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF2563EB),
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(vertical: 14),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 8),
                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton.icon(
                                  onPressed: () {
                                    final reasonController = TextEditingController();
                                    showDialog(
                                      context: context,
                                      builder: (dialogContext) => AlertDialog(
                                        title: const Text("Rechazar Pedido"),
                                        content: Column(
                                          mainAxisSize: MainAxisSize.min,
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            const Text(
                                              "¿Está seguro que desea rechazar este pedido?",
                                              style: TextStyle(fontSize: 14),
                                            ),
                                            const SizedBox(height: 16),
                                          ],
                                        ),
                                        actions: [
                                          TextButton(
                                            onPressed: () {
                                              reasonController.dispose();
                                              Navigator.pop(dialogContext);
                                            },
                                            child: const Text("Cancelar"),
                                          ),
                                          TextButton(
                                            onPressed: () {
                                              final reason = reasonController.text;
                                              reasonController.dispose();
                                              Navigator.pop(dialogContext);
                                              cancelOrderWithReason(reason.isEmpty ? null : reason);
                                            },
                                            child: const Text("Rechazar", style: TextStyle(color: Colors.red)),
                                          ),
                                        ],
                                      ),
                                    );
                                  },
                                  icon: const Icon(Icons.cancel),
                                  label: const Text("Rechazar Pedido"),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.red,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(vertical: 14),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                  ),
                                ),
                              ),
                            ],

                            // Botón Preparar pedido (si está en estado 2)
                            if (currentStatus == 2) ...[
                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton.icon(
                                  onPressed: () => updateOrderStatus(3),
                                  icon: const Icon(Icons.restaurant),
                                  label: const Text("Marcar como Preparando"),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFFFF6F3C),
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(vertical: 14),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                  ),
                                ),
                              ),
                            ],

                            // Información (si está en estado 3)
                            if (currentStatus == 3) ...[
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFF6F3C).withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: const Color(0xFFFF6F3C)),
                                ),
                                child: const Row(
                                  children: [
                                    Icon(Icons.info_outline, color: Color(0xFFFF6F3C)),
                                    SizedBox(width: 12),
                                    Expanded(
                                      child: Text(
                                        "El pedido está en preparación. Un rider lo recogerá pronto.",
                                        style: TextStyle(fontSize: 14),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // Información del pedido
                  Card(
                    elevation: 3,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            "Información del pedido",
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                          const Divider(height: 20),
                          _buildDetailRow("Fecha", _formatDateTime(widget.order['dt'])),
                          _buildDetailRow("Método de pago", _formatPaymentMethod(widget.order['payment_method'])),
                          // Mostrar comentario si existe
                          if (widget.order['order_comment'] != null &&
                              widget.order['order_comment'].toString().trim().isNotEmpty) ...[
                            const SizedBox(height: 12),
                            Container(
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
                                  Text(widget.order['order_comment'].toString(), style: const TextStyle(fontSize: 14)),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Lista de productos
                  Card(
                    elevation: 3,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            "Productos del pedido",
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                          const Divider(height: 20),
                          if (orderProducts.isEmpty)
                            const Center(
                              child: Padding(padding: EdgeInsets.all(20), child: Text("No se encontraron productos")),
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
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Expanded(
                                          child: Text(
                                            product.name ?? "Producto #${product.product}",
                                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                          ),
                                        ),
                                        Text(
                                          "\$${product.total.toStringAsFixed(2)}",
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 16,
                                            color: Colors.green,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    Row(
                                      children: [
                                        Text(
                                          "Cantidad: ${product.quantity}",
                                          style: TextStyle(color: Colors.grey[700], fontSize: 14),
                                        ),
                                        const SizedBox(width: 20),
                                        Text(
                                          "Precio unit.: \$${product.price.toStringAsFixed(2)}",
                                          style: TextStyle(color: Colors.grey[700], fontSize: 14),
                                        ),
                                      ],
                                    ),
                                    if (product.note != null && product.note!.isNotEmpty) ...[
                                      const SizedBox(height: 8),
                                      Container(
                                        padding: const EdgeInsets.all(8),
                                        decoration: BoxDecoration(
                                          color: Colors.yellow[100],
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: Row(
                                          children: [
                                            const Icon(Icons.note, size: 16, color: Colors.orange),
                                            const SizedBox(width: 8),
                                            Expanded(
                                              child: Text(
                                                "Nota: ${product.note}",
                                                style: const TextStyle(fontSize: 13),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              );
                            }).toList(),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Resumen de costos
                  Card(
                    elevation: 3,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text("Subtotal:", style: TextStyle(fontSize: 16)),
                              Text(
                                "\$${widget.order['subtotal']?.toStringAsFixed(2) ?? '0.00'}",
                                style: const TextStyle(fontSize: 16),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text("Envío:", style: TextStyle(fontSize: 16)),
                              Text(
                                "\$${widget.order['delivery_fee']?.toStringAsFixed(2) ?? '0.00'}",
                                style: const TextStyle(fontSize: 16),
                              ),
                            ],
                          ),
                          const Divider(height: 20),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text("Total:", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                              Text(
                                "\$${widget.order['total']?.toStringAsFixed(2) ?? '0.00'}",
                                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.green),
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
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text("$label:", style: TextStyle(color: Colors.grey[600], fontSize: 14)),
          ),
          Expanded(
            child: Text(value, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
          ),
        ],
      ),
    );
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
}

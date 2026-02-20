import 'dart:convert';
import 'package:delivery_ct/config/env.dart';
import 'package:delivery_ct/screens/delivery/order_detail_delivery.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class HomeDelivery extends StatefulWidget {
  const HomeDelivery({super.key});

  @override
  State<HomeDelivery> createState() => _HomeDeliveryState();
}

class _HomeDeliveryState extends State<HomeDelivery>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<dynamic> availableOrders = [];
  List<dynamic> myOrders = [];
  bool isLoadingAvailable = true;
  bool isLoadingMy = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _fetchOrders();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _fetchOrders() async {
    setState(() {
      isLoadingAvailable = true;
      isLoadingMy = true;
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString("accessToken");
      final userId = prefs.getInt("userId");

      if (userId == null || token == null) {
        setState(() {
          isLoadingAvailable = false;
          isLoadingMy = false;
        });
        return;
      }

      // Obtener todos los pedidos (el backend ya filtra según permisos)
      final url = Uri.parse("${ENV.API_URL}/api/orders/");
      final response = await http.get(
        url,
        headers: {
          "Content-Type": "application/json",
          "Authorization": "Bearer $token",
        },
      );

      if (response.statusCode == 200) {
        final List<dynamic> allOrders = jsonDecode(response.body);

        // Filtrar pedidos disponibles (status=3, sin rider asignado)
        final available = allOrders.where((order) {
          final status = order['status'] ?? 0;
          final riderId = order['rider'];
          return status == 3 && riderId == null;
        }).toList();

        // Filtrar mis pedidos (asignados al rider actual)
        final mine = allOrders.where((order) {
          final riderId = order['rider'];
          return riderId == userId;
        }).toList();

        // Ordenar por fecha descendente
        available.sort((a, b) {
          final aDate = DateTime.tryParse(a['dt'] ?? '') ?? DateTime.now();
          final bDate = DateTime.tryParse(b['dt'] ?? '') ?? DateTime.now();
          return bDate.compareTo(aDate);
        });

        mine.sort((a, b) {
          final aDate = DateTime.tryParse(a['dt'] ?? '') ?? DateTime.now();
          final bDate = DateTime.tryParse(b['dt'] ?? '') ?? DateTime.now();
          return bDate.compareTo(aDate);
        });

        if (mounted) {
          setState(() {
            availableOrders = available;
            myOrders = mine;
            isLoadingAvailable = false;
            isLoadingMy = false;
          });
        }
      } else {
        if (mounted) {
          setState(() {
            isLoadingAvailable = false;
            isLoadingMy = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          isLoadingAvailable = false;
          isLoadingMy = false;
        });
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

  Future<void> _acceptOrder(int orderId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString("accessToken");
      final userId = prefs.getInt("userId");

      final url = Uri.parse("${ENV.API_URL}/api/orders/$orderId/");
      final response = await http.patch(
        url,
        headers: {
          "Content-Type": "application/json",
          "Authorization": "Bearer $token",
        },
        body: jsonEncode({
          "rider": userId,
          "status": 4, // En camino
        }),
      );

      if (response.statusCode == 200) {
        if (!mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Pedido aceptado correctamente"),
            backgroundColor: Colors.green,
          ),
        );

        _fetchOrders(); // Recargar pedidos
      } else {
        if (!mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Error al aceptar el pedido"),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Error: $e"),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text(
          "Pedidos",
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        backgroundColor: const Color(0xFF2563EB),
        foregroundColor: Colors.white,
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: const Color(0xFFFF6F3C),
          indicatorWeight: 3,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          labelStyle: const TextStyle(fontWeight: FontWeight.w600),
          tabs: const [
            Tab(text: "Disponibles"),
            Tab(text: "Mis Pedidos"),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // Tab de pedidos disponibles
          _buildOrdersList(availableOrders, isLoadingAvailable,
              isAvailable: true),
          // Tab de mis pedidos
          _buildOrdersList(myOrders, isLoadingMy, isAvailable: false),
        ],
      ),
    );
  }

  Widget _buildOrdersList(List<dynamic> orders, bool isLoading,
      {required bool isAvailable}) {
    if (isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (orders.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isAvailable ? Icons.inbox_outlined : Icons.delivery_dining,
              size: 80,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              isAvailable
                  ? "No hay pedidos disponibles"
                  : "No tienes pedidos asignados",
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _fetchOrders,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: orders.length,
        itemBuilder: (context, index) {
          final order = orders[index];
          final status = order['status'] ?? 0;
          final storeData = order['store_data'];
          final clientData = order['client_data'];

          return Card(
            margin: const EdgeInsets.only(bottom: 16),
            elevation: 3,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: InkWell(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) =>
                        OrderDetailDelivery(orderId: order['id']),
                  ),
                ).then((_) => _fetchOrders());
              },
              borderRadius: BorderRadius.circular(12),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header: Número de pedido y estado
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.receipt_long,
                              color: Colors.grey[700],
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              "Pedido #${order['id']}",
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: _getStatusColor(status),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            _getStatusText(status),
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

                    // Tienda
                    if (storeData != null)
                      Row(
                        children: [
                          Icon(Icons.store, size: 16, color: Colors.grey[600]),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              "Tienda: ${storeData['name'] ?? 'N/A'}",
                              style: TextStyle(
                                color: Colors.grey[700],
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    const SizedBox(height: 8),

                    // Cliente
                    if (clientData != null)
                      Row(
                        children: [
                          Icon(Icons.person, size: 16, color: Colors.grey[600]),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              "Cliente: ${clientData['first_name'] ?? ''} ${clientData['last_name'] ?? ''}",
                              style: TextStyle(
                                color: Colors.grey[700],
                                fontSize: 14,
                              ),
                            ),
                          ),
                        ],
                      ),
                    const SizedBox(height: 8),

                    // Fecha
                    Row(
                      children: [
                        Icon(Icons.calendar_today,
                            size: 16, color: Colors.grey[600]),
                        const SizedBox(width: 8),
                        Text(
                          _formatDateTime(order['dt']),
                          style: TextStyle(
                            color: Colors.grey[700],
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),

                    // Total
                    Row(
                      children: [
                        Icon(Icons.attach_money,
                            size: 16, color: Colors.grey[600]),
                        const SizedBox(width: 8),
                        Text(
                          "Total: \$${order['total']?.toStringAsFixed(2) ?? '0.00'}",
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Colors.green,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Comentario del cliente (si existe)
                    if (order['order_comment'] != null &&
                        order['order_comment'].toString().trim().isNotEmpty)
                      Container(
                        margin: const EdgeInsets.only(bottom: 12),
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
                                Icon(Icons.comment,
                                    size: 16, color: Colors.amber[700]),
                                const SizedBox(width: 6),
                                Text(
                                  "Comentario:",
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.amber[900],
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              order['order_comment'].toString(),
                              style: const TextStyle(fontSize: 13),
                            ),
                          ],
                        ),
                      ),

                    // Botones
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        if (isAvailable)
                          ElevatedButton.icon(
                            onPressed: () => _acceptOrder(order['id']),
                            icon: const Icon(Icons.check, size: 18),
                            label: const Text("Aceptar"),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF2563EB),
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                          ),
                        if (!isAvailable)
                          TextButton.icon(
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) =>
                                      OrderDetailDelivery(orderId: order['id']),
                                ),
                              ).then((_) => _fetchOrders());
                            },
                            icon: const Icon(Icons.visibility, size: 18),
                            label: const Text("Ver detalles"),
                            style: TextButton.styleFrom(
                              foregroundColor: const Color(0xFF2563EB),
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
    );
  }
}

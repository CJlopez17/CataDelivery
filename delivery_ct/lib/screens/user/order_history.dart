import 'dart:convert';
import 'package:delivery_ct/config/env.dart';
import 'package:delivery_ct/screens/user/order_tracking.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class OrderHistory extends StatefulWidget {
  const OrderHistory({super.key});

  @override
  State<OrderHistory> createState() => _OrderHistoryState();
}

class _OrderHistoryState extends State<OrderHistory>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<dynamic> activeOrders = [];
  List<dynamic> completedOrders = [];
  bool isLoadingActive = true;
  bool isLoadingCompleted = true;

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
      isLoadingActive = true;
      isLoadingCompleted = true;
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString("accessToken");
      final userId = prefs.getInt("userId");

      if (userId == null || token == null) {
        setState(() {
          isLoadingActive = false;
          isLoadingCompleted = false;
        });
        return;
      }

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

        // Filtrar pedidos activos (estados 1-4) y completados (estado 5)
        final active = allOrders.where((order) {
          final status = order['status'] ?? 0;
          return status >= 1 && status <= 4;
        }).toList();

        final completed = allOrders.where((order) {
          final status = order['status'] ?? 0;
          return status == 5;
        }).toList();

        // Ordenar por fecha descendente (más recientes primero)
        active.sort((a, b) {
          final aDate = DateTime.tryParse(a['dt'] ?? '') ?? DateTime.now();
          final bDate = DateTime.tryParse(b['dt'] ?? '') ?? DateTime.now();
          return bDate.compareTo(aDate);
        });

        completed.sort((a, b) {
          final aDate = DateTime.tryParse(a['dt'] ?? '') ?? DateTime.now();
          final bDate = DateTime.tryParse(b['dt'] ?? '') ?? DateTime.now();
          return bDate.compareTo(aDate);
        });

        if (mounted) {
          setState(() {
            activeOrders = active;
            completedOrders = completed;
            isLoadingActive = false;
            isLoadingCompleted = false;
          });
        }
      } else {
        if (mounted) {
          setState(() {
            isLoadingActive = false;
            isLoadingCompleted = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          isLoadingActive = false;
          isLoadingCompleted = false;
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text(
          "Mis Pedidos",
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        backgroundColor: const Color(0xFF2563EB), // Azul principal
        foregroundColor: Colors.white,
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: const Color(0xFFFF6F3C), // Naranja secundario
          indicatorWeight: 3,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          labelStyle: const TextStyle(fontWeight: FontWeight.w600),
          tabs: const [
            Tab(text: "Activos"),
            Tab(text: "Historial"),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // Tab de pedidos activos
          _buildOrdersList(activeOrders, isLoadingActive, isActive: true),
          // Tab de pedidos completados
          _buildOrdersList(completedOrders, isLoadingCompleted, isActive: false),
        ],
      ),
    );
  }

  Widget _buildOrdersList(List<dynamic> orders, bool isLoading,
      {required bool isActive}) {
    if (isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (orders.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isActive ? Icons.shopping_bag_outlined : Icons.history,
              size: 80,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              isActive
                  ? "No tienes pedidos activos"
                  : "No hay pedidos en el historial",
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
                        OrderTrackingScreen(orderId: order['id']),
                  ),
                );
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

                    // Botón de ver detalles
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton.icon(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) =>
                                  OrderTrackingScreen(orderId: order['id']),
                            ),
                          );
                        },
                        icon: const Icon(Icons.visibility, size: 18),
                        label: const Text("Ver detalles"),
                        style: TextButton.styleFrom(
                          foregroundColor: const Color(0xFF2563EB), // Azul principal
                        ),
                      ),
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

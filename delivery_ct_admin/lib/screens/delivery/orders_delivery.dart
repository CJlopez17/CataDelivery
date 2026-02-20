import 'package:delivery_ct_admin/config/env.dart';
import 'package:delivery_ct_admin/screens/delivery/order_detail_delivery.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class OrdersDelivery extends StatefulWidget {
  const OrdersDelivery({super.key});

  @override
  State<OrdersDelivery> createState() => _OrdersDeliveryState();
}

class _OrdersDeliveryState extends State<OrdersDelivery>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List assignedOrders = []; // Pedidos asignados (status=3)
  List activeOrders = []; // Pedidos activos (status=4)
  bool isLoadingAssigned = true;
  bool isLoadingActive = true;

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
      isLoadingAssigned = true;
      isLoadingActive = true;
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString("accessToken");
      final userId = prefs.getInt("userId");

      if (userId == null || token == null) {
        setState(() {
          isLoadingAssigned = false;
          isLoadingActive = false;
        });
        return;
      }

      // Obtener todos los pedidos asignados al rider
      // El backend ya filtra automáticamente por rider
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

        // Separar órdenes asignadas (status=3, Preparing) de activas (status=4, In Route)
        final assigned = allOrders.where((order) {
          final status = order['status'] ?? 0;
          return status == 3; // Preparando (recién asignadas)
        }).toList();

        final active = allOrders.where((order) {
          final status = order['status'] ?? 0;
          return status == 4; // En camino (aceptadas)
        }).toList();

        // Ordenar por fecha descendente
        assigned.sort((a, b) {
          final aDate = DateTime.tryParse(a['dt'] ?? '') ?? DateTime.now();
          final bDate = DateTime.tryParse(b['dt'] ?? '') ?? DateTime.now();
          return bDate.compareTo(aDate);
        });

        active.sort((a, b) {
          final aDate = DateTime.tryParse(a['dt'] ?? '') ?? DateTime.now();
          final bDate = DateTime.tryParse(b['dt'] ?? '') ?? DateTime.now();
          return bDate.compareTo(aDate);
        });

        if (mounted) {
          setState(() {
            assignedOrders = assigned;
            activeOrders = active;
            isLoadingAssigned = false;
            isLoadingActive = false;
          });
        }
      } else {
        if (mounted) {
          setState(() {
            isLoadingAssigned = false;
            isLoadingActive = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          isLoadingAssigned = false;
          isLoadingActive = false;
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

      final url = Uri.parse("${ENV.API_URL}/api/orders/$orderId/");
      final response = await http.patch(
        url,
        headers: {
          "Content-Type": "application/json",
          "Authorization": "Bearer $token",
        },
        body: jsonEncode({
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

  Future<void> _rejectOrder(int orderId) async {
    // Confirmar rechazo
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Rechazar pedido"),
        content: const Text(
          "¿Estás seguro de que deseas rechazar este pedido? "
          "El pedido volverá a estar disponible para asignación.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Cancelar"),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text("Rechazar"),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString("accessToken");

      final url = Uri.parse("${ENV.API_URL}/api/orders/$orderId/");
      final response = await http.patch(
        url,
        headers: {
          "Content-Type": "application/json",
          "Authorization": "Bearer $token",
        },
        body: jsonEncode({
          "rider": null, // Quitar asignación
          "status": 3, // Volver a Preparing
        }),
      );

      if (response.statusCode == 200) {
        if (!mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Pedido rechazado correctamente"),
            backgroundColor: Colors.orange,
          ),
        );

        _fetchOrders(); // Recargar pedidos
      } else {
        if (!mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Error al rechazar el pedido"),
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
          tabs: [
            Tab(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text("Asignados"),
                  if (assignedOrders.isNotEmpty)
                    Container(
                      margin: const EdgeInsets.only(left: 8),
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(
                        color: Color(0xFFFF6F3C),
                        shape: BoxShape.circle,
                      ),
                      child: Text(
                        '${assignedOrders.length}',
                        style: const TextStyle(fontSize: 10),
                      ),
                    ),
                ],
              ),
            ),
            const Tab(text: "En Camino"),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // Tab de pedidos asignados (Preparing)
          _buildOrdersList(assignedOrders, isLoadingAssigned,
              isAssigned: true),
          // Tab de pedidos activos (In Route)
          _buildOrdersList(activeOrders, isLoadingActive, isAssigned: false),
        ],
      ),
    );
  }

  Widget _buildOrdersList(List<dynamic> orders, bool isLoading,
      {required bool isAssigned}) {
    if (isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (orders.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isAssigned ? Icons.assignment_outlined : Icons.delivery_dining,
              size: 80,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              isAssigned
                  ? "No tienes pedidos asignados"
                  : "No tienes pedidos en camino",
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[600],
              ),
            ),
            if (isAssigned)
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  "Los pedidos se asignan automáticamente cuando las tiendas los marcan como listos",
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[500],
                  ),
                  textAlign: TextAlign.center,
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
          final isAutoAssigned = order['is_auto_assigned'] == true;
          final assignmentScore = order['assignment_score'];

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
                    builder: (_) => OrderDetailDelivery(order: order),
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

                    // Indicador de asignación automática
                    if (isAutoAssigned && isAssigned)
                      Container(
                        margin: const EdgeInsets.only(top: 8),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.blue.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: Colors.blue.shade200,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.auto_awesome,
                              size: 14,
                              color: Colors.blue.shade700,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              "Asignado automáticamente",
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.blue.shade700,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            if (assignmentScore != null)
                              Text(
                                " • ${assignmentScore.toStringAsFixed(2)} km",
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.blue.shade600,
                                ),
                              ),
                          ],
                        ),
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

                    // Botones
                    if (isAssigned)
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          // Botón Rechazar
                          OutlinedButton.icon(
                            onPressed: () => _rejectOrder(order['id']),
                            icon: const Icon(Icons.close, size: 18),
                            label: const Text("Rechazar"),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.red,
                              side: const BorderSide(color: Colors.red),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          // Botón Aceptar
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
                        ],
                      ),
                    if (!isAssigned)
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton.icon(
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) =>
                                      OrderDetailDelivery(order: order),
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

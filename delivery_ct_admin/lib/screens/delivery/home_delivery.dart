import 'package:delivery_ct_admin/config/env.dart';
import 'package:delivery_ct_admin/data/services/permissions_helper.dart';
import 'package:delivery_ct_admin/data/services/location_service.dart';
import 'package:delivery_ct_admin/screens/delivery/order_detail_delivery.dart';
import 'package:delivery_ct_admin/screens/delivery/orders_delivery.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class HomeDelivery extends StatefulWidget {
  const HomeDelivery({super.key});

  @override
  State<HomeDelivery> createState() => _HomeDeliveryState();
}

class _HomeDeliveryState extends State<HomeDelivery> {
  Map? activeOrder;
  bool loading = true;

  @override
  void initState() {
    super.initState();
    fetchActiveOrder();

    // Verificar permisos de ubicación al abrir la pantalla
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkLocationPermissions();
      _initializeLocationService();
    });
  }

  /// Inicia el servicio de actualización de ubicación
  Future<void> _initializeLocationService() async {
    // Verificar si el rider está disponible
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString("accessToken");
    final userId = prefs.getInt("userId");

    if (token == null || userId == null) return;

    try {
      // Obtener información del usuario para verificar disponibilidad
      final response = await http.get(
        Uri.parse("${ENV.API_URL}/api/users/$userId/"),
        headers: {
          "Content-Type": "application/json",
          "Authorization": "Bearer $token",
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final isAvailable = data['is_available'] ?? false;

        if (isAvailable) {
          // Iniciar servicio de ubicación si el rider está disponible
          final locationService = LocationService();
          await locationService.startLocationUpdates(immediate: true);
        }
      }
    } catch (e) {
      debugPrint('Error al inicializar servicio de ubicación: $e');
    }
  }

  Future<void> _checkLocationPermissions() async {
    await PermissionsHelper.checkLocationOnAppResume(context);
  }

  Future<void> fetchActiveOrder() async {
    setState(() => loading = true);
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString("accessToken");

    try {
      final response = await http.get(
        Uri.parse("${ENV.API_URL}/api/orders/active_order/"),
        headers: {
          "Content-Type": "application/json",
          "Authorization": "Bearer $token",
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          activeOrder = data['has_active_order'] ? data['order'] : null;
          loading = false;
        });
      } else {
        setState(() => loading = false);
      }
    } catch (e) {
      setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        backgroundColor: const Color(0xFF2563EB),
        foregroundColor: Colors.white,
        title: const Text("Delivery - Inicio"),
        centerTitle: true,
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: fetchActiveOrder,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      // Card de Pedido Activo (si existe)
                      if (activeOrder != null) ...[
                        _buildActiveOrderCard(context),
                        const SizedBox(height: 30),
                      ],

                      // Icono principal (solo si no hay pedido activo)
                      if (activeOrder == null) ...[
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: const Color(0xFF2563EB).withOpacity(0.1),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.delivery_dining,
                            size: 80,
                            color: Color(0xFF2563EB),
                          ),
                        ),
                        const SizedBox(height: 40),

                        // Título
                        const Text(
                          "¡Bienvenido Rider!",
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1E1E1E),
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          "Selecciona una opción para continuar",
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.grey[600],
                          ),
                        ),
                        const SizedBox(height: 60),
                      ],

                      // Botón Ordenes
                      _buildButton(
                        context,
                        title: "Ordenes",
                        subtitle: "Ver pedidos disponibles",
                        icon: Icons.shopping_bag,
                        color: const Color(0xFF2563EB),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const OrdersDelivery(),
                            ),
                          ).then((_) => fetchActiveOrder());
                        },
                      ),
                      const SizedBox(height: 20),

                      // Botón Encargos
                      _buildButton(
                        context,
                        title: "Encargos",
                        subtitle: "Ver tus encargos activos",
                        icon: Icons.assignment,
                        color: const Color(0xFFFF6F3C),
                        onTap: () {
                          // TODO: Implementar pantalla de encargos
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text("Funcionalidad próximamente"),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ),
    );
  }

  Widget _buildActiveOrderCard(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFF10B981),
            const Color(0xFF059669),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF10B981).withOpacity(0.4),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.local_shipping,
                  color: Colors.white,
                  size: 28,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Pedido en Curso",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      "Tienes un pedido activo",
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text(
                  "En Camino",
                  style: TextStyle(
                    color: Color(0xFF10B981),
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Detalles del pedido
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.receipt_long, color: Colors.white, size: 20),
                        const SizedBox(width: 8),
                        Text(
                          "Pedido #${activeOrder!['id']}",
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    Text(
                      "\$${activeOrder!['total']?.toStringAsFixed(2) ?? '0.00'}",
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    const Icon(Icons.store, color: Colors.white70, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        activeOrder!['store_data']?['name'] ?? "Tienda",
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Botón para ver detalles y marcar como entregado
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => OrderDetailDelivery(order: activeOrder!),
                  ),
                ).then((_) => fetchActiveOrder());
              },
              icon: const Icon(Icons.map, size: 20),
              label: const Text(
                "Ver Detalles y Marcar Entregado",
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: const Color(0xFF10B981),
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildButton(
    BuildContext context, {
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                icon,
                size: 32,
                color: color,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: color,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.arrow_forward_ios,
              color: color,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }
}

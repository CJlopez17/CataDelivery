import 'package:delivery_ct/data/services/permissions_helper.dart';
import 'package:delivery_ct/screens/user/order_history.dart';
import 'package:delivery_ct/screens/user/stores_list.dart';
import 'package:flutter/material.dart';

class HomeScreenUser extends StatefulWidget {
  const HomeScreenUser({super.key});

  @override
  State<HomeScreenUser> createState() => _HomeScreenUserState();
}

class _HomeScreenUserState extends State<HomeScreenUser> {
  @override
  void initState() {
    super.initState();
    // Verificar permisos de ubicación al abrir la pantalla
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkLocationPermissions();
    });
  }

  Future<void> _checkLocationPermissions() async {
    await PermissionsHelper.checkLocationOnAppResume(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text(
          'Bienvenido',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
        backgroundColor: const Color(0xFF2563EB), // Azul principal
        elevation: 0,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 40),
            _buildButton(
              context,
              'Restaurant',
              Icons.restaurant,
              const Color(0xFF2563EB), // Azul principal
            ),
            const SizedBox(height: 20),
            _buildButton(
              context,
              'Mis Pedidos',
              Icons.receipt_long,
              const Color(0xFFFF6F3C), // Naranja secundario
            ),
            const SizedBox(height: 20),
            _buildButton(
              context,
              'Encargos',
              Icons.local_shipping,
              const Color(0xFF2563EB), // Azul principal
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildButton(
      BuildContext context, String title, IconData icon, Color color) {
    return ElevatedButton.icon(
      onPressed: () {
        if (title == 'Restaurant') {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => StoresListPage()),
          );
        } else if (title == 'Mis Pedidos') {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => OrderHistory()),
          );
        } else if (title == 'Encargos') {
          Navigator.pushNamed(context, '/orderHistory');
        }
      },
      icon: Icon(icon, color: Colors.white, size: 28),
      label: Text(
        title,
        style: const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: Colors.white,
        ),
      ),
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 20),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        elevation: 2,
        shadowColor: color.withOpacity(0.3),
      ),
    );
  }
}

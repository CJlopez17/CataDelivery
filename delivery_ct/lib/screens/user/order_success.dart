import 'dart:async';
import 'package:delivery_ct/screens/user/order_tracking.dart';
import 'package:flutter/material.dart';

class OrderSuccessScreen extends StatefulWidget {
  final int orderId;

  const OrderSuccessScreen({super.key, required this.orderId});

  @override
  State<OrderSuccessScreen> createState() => _OrderSuccessScreenState();
}

class _OrderSuccessScreenState extends State<OrderSuccessScreen> {
  @override
  void initState() {
    super.initState();
    // Esperar 3 segundos y luego navegar a la pantalla de seguimiento
    Timer(const Duration(seconds: 3), () {
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => OrderTrackingScreen(orderId: widget.orderId),
          ),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Checkmark animado
            Container(
              width: 200,
              height: 200,
              decoration: BoxDecoration(
                color: const Color(0xFF2563EB), // Azul principal
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF2563EB).withOpacity(0.3),
                    blurRadius: 20,
                    spreadRadius: 5,
                  ),
                ],
              ),
              child: const Icon(
                Icons.check,
                color: Colors.white,
                size: 120,
              ),
            ),
            const SizedBox(height: 40),
            // Texto "Pedido Realizado"
            const Text(
              "Pedido Realizado",
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w600,
                color: Color(0xFF1E1E1E), // Color de texto
              ),
            ),
            const SizedBox(height: 12),
            Text(
              "Redirigiendo al seguimiento...",
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

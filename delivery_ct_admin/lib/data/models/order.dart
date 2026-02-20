// ========================================
// 1. MODEL: order.dart
// ========================================
class Order {
  final int id;
  final int status;
  final DateTime dt;
  final String paymentMethod;
  final double subtotal;
  final double deliveryFee;
  final double total;
  final int? rider;
  final int store;
  final int client;
  final int deliveryAddress;

  Order({
    required this.id,
    required this.status,
    required this.dt,
    required this.paymentMethod,
    required this.subtotal,
    required this.deliveryFee,
    required this.total,
    this.rider,
    required this.store,
    required this.client,
    required this.deliveryAddress,
  });

  factory Order.fromJson(Map<String, dynamic> json) {
    return Order(
      id: json['id'],
      status: json['status'],
      dt: DateTime.parse(json['dt']),
      paymentMethod: json['payment_method'],
      subtotal: (json['subtotal'] as num).toDouble(),
      deliveryFee: (json['delivery_fee'] as num).toDouble(),
      total: (json['total'] as num).toDouble(),
      rider: json['rider'],
      store: json['store'],
      client: json['client'],
      deliveryAddress: json['delivery_address'],
    );
  }

  // Helper para obtener el texto del estado
  String getStatusText() {
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
}
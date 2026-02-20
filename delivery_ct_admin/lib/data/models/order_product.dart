class OrderProduct {
  final int id;
  final int order;
  final int product;
  final String? name;
  final double price;
  final int quantity;
  final double total;
  final String? note;

  OrderProduct({
    required this.id,
    required this.order,
    required this.product,
    this.name,
    required this.price,
    required this.quantity,
    required this.total,
    this.note,
  });

  factory OrderProduct.fromJson(Map<String, dynamic> json) {
    return OrderProduct(
      id: json['id'],
      order: json['order'],
      product: json['product'],
      name: json['name'],
      price: (json['price'] as num).toDouble(),
      quantity: json['quantity'],
      total: (json['total'] as num).toDouble(),
      note: json['note'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'order': order,
      'product': product,
      'name': name,
      'price': price,
      'quantity': quantity,
      'total': total,
      'note': note,
    };
  }
}

import 'package:flutter/material.dart';

class CartItem {
  final int id;
  final String name;
  final double price;
  final int storeId;
  int quantity;

  CartItem({
    required this.id,
    required this.name,
    required this.price,
    required this.storeId,
    this.quantity = 1,
  });
}

class CartProvider extends ChangeNotifier {
  final List<CartItem> _items = [];

  List<CartItem> get items => _items;

  void addToCart(CartItem item) {
    // Si el producto ya está en el carrito, aumentar cantidad
    final existing = _items.indexWhere((i) => i.id == item.id);
    if (existing != -1) {
      _items[existing].quantity++;
    } else {
      _items.add(item);
    }
    notifyListeners();
  }

  void increaseQty(int id) {
    final index = _items.indexWhere((i) => i.id == id);
    _items[index].quantity++;
    notifyListeners();
  }

  void decreaseQty(int id) {
    final index = _items.indexWhere((i) => i.id == id);
    if (_items[index].quantity > 1) {
      _items[index].quantity--;
    } else {
      _items.removeAt(index);
    }
    notifyListeners();
  }

  double get subtotal =>
      _items.fold(0, (sum, item) => sum + (item.price * item.quantity));

  void clearCart() {
    _items.clear();
    notifyListeners();
  }
}

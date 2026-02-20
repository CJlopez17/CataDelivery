class Product {
  final int id;
  final String name;
  final String description;
  final double price;
  final String photoProduct;
  final int category;
  final int store;

  Product({
    required this.id,
    required this.name,
    required this.description,
    required this.price,
    required this.photoProduct,
    required this.category,
    required this.store,
  });

  factory Product.fromJson(Map<String, dynamic> json) {
    return Product(
      id: json["id"],
      name: json["name"],
      description: json["description"],
      price: json["price"].toDouble(),
      photoProduct: json["photoProduct"],
      category: json["category"],
      store: json["store"],
    );
  }
}

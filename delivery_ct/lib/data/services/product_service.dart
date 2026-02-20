import 'dart:convert';
import 'package:delivery_ct/config/env.dart';
import 'package:http/http.dart' as http;
import '../models/product.dart';

class ProductService {
  Future<Product> getProductDetail(int id) async {
    final response = await http.get(
      Uri.parse("${ENV.API_URL}/api/products/$id"),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return Product.fromJson(data);
    } else {
      throw Exception("Error al obtener el producto");
    }
  }
}

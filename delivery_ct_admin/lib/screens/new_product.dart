import 'dart:typed_data';
import 'package:delivery_ct_admin/config/env.dart';
import 'package:flutter/material.dart';
// ignore: depend_on_referenced_packages
import 'package:http/http.dart' as http;
// ignore: depend_on_referenced_packages
import 'package:file_picker/file_picker.dart';
import 'dart:convert';
// ignore: depend_on_referenced_packages
import 'package:shared_preferences/shared_preferences.dart';

class CreateProduct extends StatefulWidget {
  final int storeId;

  const CreateProduct({super.key, required this.storeId});

  @override
  State<CreateProduct> createState() => _CreateProductPageState();
}

class _CreateProductPageState extends State<CreateProduct> {
  final _formKey = GlobalKey<FormState>();

  String name = "";
  String description = "";
  double price = 0.0;
  int? categoryId;
  Uint8List? selectedImageBytes;
  String? selectedImageName;

  List categories = [];

  @override
  void initState() {
    super.initState();
    fetchCategories();
  }

  Future<void> fetchCategories() async {
    final url = Uri.parse("${ENV.API_URL}/api/categories/");
    final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString("accessToken");

    final response = await http.get(
      url,
      headers: {"Authorization": "Bearer $token"},
    );

    if (response.statusCode == 200) {
      setState(() {
        categories = jsonDecode(response.body);
      });
    } else {
      debugPrint("Error cargando categorías: ${response.body}");
    }
  }

  Future<void> pickImage() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      withData: true,
    );

    if (result != null) {
      setState(() {
        selectedImageBytes = result.files.first.bytes;
        selectedImageName = result.files.first.name;
      });
    }
  }

  Future<void> createProduct() async {
    if (!_formKey.currentState!.validate()) return;

    if (categoryId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Selecciona una categoría")),
      );
      return;
    }

    if (selectedImageBytes == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Selecciona una imagen")),
      );
      return;
    }

    _formKey.currentState!.save();

    final url =
        Uri.parse("${ENV.API_URL}/api/products/?store=${widget.storeId}/");
    final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString("accessToken");

    final request = http.MultipartRequest("POST", url);
    request.headers["Authorization"] = "Bearer $token";

    request.fields["name"] = name;
    request.fields["description"] = description;
    request.fields["price"] = price.toString();
    request.fields["category"] = categoryId.toString();
    request.fields["store"] = widget.storeId.toString();

    // imagen
    request.files.add(
      http.MultipartFile.fromBytes(
        "photoProduct",
        selectedImageBytes!,
        filename: selectedImageName,
      ),
    );

    final response = await request.send();

    if (response.statusCode == 201) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Producto creado correctamente")),
      );
      Navigator.pop(context);
    } else {
      final body = await response.stream.bytesToString();
      debugPrint("Error: $body");

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error al crear producto: $body")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Crear producto"),
        backgroundColor: const Color(0xFF2563EB),
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              TextFormField(
                decoration: const InputDecoration(labelText: "Nombre"),
                validator: (value) => value!.isEmpty ? "Ingresa el nombre" : null,
                onSaved: (value) => name = value!,
              ),
              const SizedBox(height: 10),

              TextFormField(
                decoration: const InputDecoration(labelText: "Descripción"),
                validator: (value) => value!.isEmpty ? "Ingresa la descripción" : null,
                onSaved: (value) => description = value!,
              ),

              const SizedBox(height: 10),

              TextFormField(
                decoration: const InputDecoration(labelText: "Precio"),
                keyboardType: TextInputType.number,
                validator: (value) => value!.isEmpty ? "Ingresa el precio" : null,
                onSaved: (value) => price = double.parse(value!),
              ),

              const SizedBox(height: 10),

              // Dropdown de categorías
              DropdownButtonFormField<int>(
                decoration: const InputDecoration(labelText: "Categoría"),
                items: categories.map<DropdownMenuItem<int>>((cat) {
                  return DropdownMenuItem(
                    value: cat["id"],
                    child: Text(cat["name"]),
                  );
                }).toList(),
                onChanged: (value) => setState(() => categoryId = value),
              ),

              const SizedBox(height: 20),

              ElevatedButton(
                onPressed: pickImage,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFF6F3C),
                  foregroundColor: Colors.white,
                ),
                child: const Text("Seleccionar imagen"),
              ),

              if (selectedImageName != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text("Imagen: $selectedImageName"),
                ),

              const SizedBox(height: 30),

              ElevatedButton(
                onPressed: createProduct,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2563EB),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: const Text("Crear producto"),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

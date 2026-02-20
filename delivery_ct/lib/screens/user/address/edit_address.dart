import 'dart:convert';
import 'package:delivery_ct/config/env.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

class EditAddress extends StatefulWidget {
  final Map<String, dynamic> address; // Recibe la dirección desde la lista

  const EditAddress({super.key, required this.address});

  @override
  _EditAddressPageState createState() => _EditAddressPageState();
}

class _EditAddressPageState extends State<EditAddress> {
  late TextEditingController nameController;
  late TextEditingController descriptionController;

  MapboxMap? mapboxMap;

  late double selectedLat;
  late double selectedLng;

  PointAnnotationManager? pointManager;
  PointAnnotation? marker;

  @override
  void initState() {
    super.initState();

    // Cargar valores actuales
    nameController = TextEditingController(text: widget.address["name"]);
    descriptionController = TextEditingController(
      text: widget.address["description"] ?? "",
    );

    selectedLat = widget.address["latitude"];
    selectedLng = widget.address["longitude"];
  }

  @override
  void dispose() {
    nameController.dispose();
    descriptionController.dispose();
    super.dispose();
  }

  Future<void> _addMarker(double lat, double lng) async {
    pointManager ??= await mapboxMap!.annotations
        .createPointAnnotationManager();

    if (marker != null) {
      await pointManager!.delete(marker!);
    }

    marker = await pointManager!.create(
      PointAnnotationOptions(
        geometry: Point(coordinates: Position(lng, lat)),
        iconSize: 1.2,
      ),
    );
  }

  Future<void> updateAddress() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString("accessToken");

    if (token == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Error: no hay token")));
      return;
    }

    final body = {
      "name": nameController.text,
      "description": descriptionController.text,
      "latitude": selectedLat,
      "longitude": selectedLng,
    };

    try {
      final response = await http.put(
        Uri.parse("${ENV.API_URL}/api/addresses/?id=${widget.address["id"]}/"),
        headers: {
          "Content-Type": "application/json",
          "Authorization": "Bearer $token",
        },
        body: jsonEncode(body),
      );

      if (response.statusCode == 200) {
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Dirección actualizada correctamente")),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error al actualizar: ${response.body}")),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error al actualizar la dirección: $e")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Editar dirección"),
        backgroundColor: const Color(0xFF2563EB),
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          // FORMULARIO
          Padding(
            padding: const EdgeInsets.all(14.0),
            child: Column(
              children: [
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: "Nombre de la dirección",
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: descriptionController,
                  decoration: const InputDecoration(
                    labelText: "Descripción",
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 2,
                ),
              ],
            ),
          ),

          // MAPA
          Expanded(
            child: MapWidget(
              key: const ValueKey("mapbox_edit_map"),
              styleUri: MapboxStyles.MAPBOX_STREETS,
              cameraOptions: CameraOptions(
                center: Point(coordinates: Position(selectedLng, selectedLat)),
                zoom: 14,
              ),

              onTapListener: (tapContext) {
                final coord = tapContext.point.coordinates;

                setState(() {
                  selectedLat = coord.lat.toDouble();
                  selectedLng = coord.lng.toDouble();
                });

                _addMarker(selectedLat, selectedLng);

              },
              onMapCreated: (controller) {
                mapboxMap = controller;

                _addMarker(selectedLat, selectedLng);
              },
            ),
          ),

          // BOTÓN GUARDAR
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: ElevatedButton(
              onPressed: updateAddress,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2563EB),
              ),
              child: const Text(
                "Guardar cambios",
                style: TextStyle(color: Colors.white, fontSize: 16),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

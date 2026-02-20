import 'dart:convert';
import 'package:delivery_ct/config/env.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AddAddressPage extends StatefulWidget {
  const AddAddressPage({super.key});

  @override
  _AddAddressPageState createState() => _AddAddressPageState();
}

class _AddAddressPageState extends State<AddAddressPage> {
  final TextEditingController nameController = TextEditingController();
  final TextEditingController descriptionController = TextEditingController();

  MapboxMap? mapboxMap;

  // Coordenadas por defecto (Paltas)
  double selectedLat = -4.050274863391152;
  double selectedLng = -79.64977648865819;

  // Marcador
  PointAnnotationManager? pointManager;
  PointAnnotation? marker;

  @override
  void initState() {
    super.initState();
  }

  Future<void> _addMarker(double lat, double lng) async {
    pointManager ??= await mapboxMap!.annotations
        .createPointAnnotationManager();

    // eliminar marcador anterior
    if (marker != null) {
      await pointManager!.delete(marker!);
    }

    // crear marcador nuevo con un pin más visible
    marker = await pointManager!.create(
      PointAnnotationOptions(
        geometry: Point(coordinates: Position(lng, lat)),
        iconSize: 1.5,
        iconColor: Colors.red.value,
        iconImage: "marker", // Usa el ícono por defecto de Mapbox
      ),
    );
  }

  Future<void> saveAddress() async {
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

    final response = await http.post(
      Uri.parse("${ENV.API_URL}/api/addresses/?id=${prefs.getInt("userId")}"),
      headers: {
        "Content-Type": "application/json",
        "Authorization": "Bearer $token",
      },
      body: jsonEncode(body),
    );

    if (response.statusCode == 201) {
      Navigator.pop(context);
    } else {
      print(response.body);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error al guardar: ${response.body}")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Agregar dirección"),
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
                const SizedBox(height: 8),
                // Instrucción para el usuario
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF2563EB).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Row(
                    children: [
                      Icon(
                        Icons.info_outline,
                        color: Color(0xFF2563EB),
                        size: 20,
                      ),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          "Toca en el mapa para seleccionar tu ubicación",
                          style: TextStyle(
                            fontSize: 13,
                            color: Color(0xFF2563EB),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // MAPA CON INDICADOR CENTRAL
          Expanded(
            child: Stack(
              children: [
                MapWidget(
                  key: const ValueKey("mapbox_map"),
                  styleUri: MapboxStyles.MAPBOX_STREETS,
                  cameraOptions: CameraOptions(
                    center: Point(
                      coordinates: Position(selectedLng, selectedLat),
                    ),
                    zoom: 14,
                  ),
                  onMapCreated: (controller) {
                    mapboxMap = controller;
                    _addMarker(selectedLat, selectedLng);
                  },
                  onTapListener: (tapContext) {
                    final coord = tapContext.point.coordinates;

                    setState(() {
                      selectedLat = coord.lat.toDouble();
                      selectedLng = coord.lng.toDouble();
                    });

                    _addMarker(selectedLat, selectedLng);
                  },
                ),
                // Pin fijo en el centro como alternativa visual
                Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.location_on,
                        size: 50,
                        color: Color(0xFFFF6F3C),
                        shadows: [
                          Shadow(
                            blurRadius: 10,
                            color: Colors.black.withOpacity(0.3),
                          ),
                        ],
                      ),
                      const SizedBox(height: 50), // Compensa la altura del pin
                    ],
                  ),
                ),
              ],
            ),
          ),

          // INFO DE COORDENADAS
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: Colors.grey[100],
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.my_location, size: 16, color: Colors.grey),
                const SizedBox(width: 8),
                Text(
                  "Lat: ${selectedLat.toStringAsFixed(6)}, Lng: ${selectedLng.toStringAsFixed(6)}",
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ),
          ),

          // GUARDAR
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: saveAddress,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2563EB),
                ),
                child: const Text(
                  "Guardar dirección",
                  style: TextStyle(color: Colors.white, fontSize: 16),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

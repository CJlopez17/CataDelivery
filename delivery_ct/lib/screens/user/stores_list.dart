import 'dart:convert';
import 'package:delivery_ct/config/env.dart';
import 'package:delivery_ct/screens/user/list_product_by_store.dart';
import 'package:delivery_ct/utils/distance_utils.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class StoresListPage extends StatefulWidget {
  const StoresListPage({super.key});

  @override
  _StoresListPageState createState() => _StoresListPageState();
}

class _StoresListPageState extends State<StoresListPage> {
  List stores = [];
  bool isLoading = true;
  String? errorMessage;
  Position? _userPosition;

  @override
  void initState() {
    super.initState();
    _getUserLocation();
    loadStores();
  }

  /// Obtiene la ubicación actual del usuario
  Future<void> _getUserLocation() async {
    try {
      // Verificar si el servicio de ubicación está habilitado
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        debugPrint('⚠️ Servicio de ubicación deshabilitado');
        return;
      }

      // Verificar permisos
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          debugPrint('⚠️ Permisos de ubicación denegados');
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        debugPrint('⚠️ Permisos de ubicación denegados permanentemente');
        return;
      }

      // Obtener ubicación actual
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );

      setState(() {
        _userPosition = position;
      });

      debugPrint('📍 Ubicación del usuario obtenida: (${position.latitude}, ${position.longitude})');
    } catch (e) {
      debugPrint('❌ Error obteniendo ubicación: $e');
    }
  }

  /// Calcula el delivery fee aproximado para una tienda
  double? _calculateStoreDeliveryFee(dynamic store) {
    if (_userPosition == null) return null;

    final storeLat = store['latitude'] as double?;
    final storeLon = store['longitude'] as double?;

    if (storeLat == null || storeLon == null) return null;

    return DistanceUtils.calculateDeliveryFee(
      storeLat,
      storeLon,
      _userPosition!.latitude,
      _userPosition!.longitude,
    );
  }

  Future<void> loadStores() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString("accessToken");

      if (token == null) {
        setState(() {
          errorMessage = "Token de autenticación no encontrado.";
          isLoading = false;
        });
        return;
      }

      final url = Uri.parse("${ENV.API_URL}/api/stores/");

      final response = await http.get(
        url,
        headers: {
          "Content-Type": "application/json",
          "Authorization": "Bearer $token", // ← Usa Bearer si tu API usa JWT
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        setState(() {
          stores = data;
          isLoading = false;
        });
      } else {
        setState(() {
          errorMessage = "Error ${response.statusCode}: ${response.body}";
          isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        errorMessage = "Error de conexión: $e";
        isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Locales Comerciales"),
        backgroundColor: const Color(0xFF2563EB),
        foregroundColor: Colors.white,
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : errorMessage != null
          ? Center(
              child: Text(
                errorMessage!,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 18, color: Colors.red),
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: stores.length,
              itemBuilder: (context, index) {
                final store = stores[index];
                final deliveryFee = _calculateStoreDeliveryFee(store);

                return Card(
                  margin: const EdgeInsets.symmetric(vertical: 8),
                  elevation: 3,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: Image.network(
                            store['logo'] ?? '',
                            width: 70,
                            height: 70,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) {
                              return Container(
                                width: 70,
                                height: 70,
                                color: Colors.grey[300],
                                child: const Icon(
                                  Icons.store,
                                  size: 35,
                                  color: Colors.grey,
                                ),
                              );
                            },
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              ListTile(
                                contentPadding: const EdgeInsets.all(16),
                                title: Text(
                                  store["name"],
                                  style: const TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF1E1E1E),
                                  ),
                                ),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const SizedBox(height: 6),
                                    Text(
                                      store["description"],
                                      style: const TextStyle(
                                        fontSize: 16,
                                        color: Colors.black87,
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    Row(
                                      children: [
                                        const Icon(
                                          Icons.location_on,
                                          size: 18,
                                          color: Color(0xFFFF6F3C),
                                        ),
                                        const SizedBox(width: 4),
                                        Expanded(
                                          child: Text(
                                            store["address"],
                                            style: const TextStyle(
                                              fontSize: 15,
                                              color: Colors.black54,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    if (deliveryFee != null) ...[
                                      const SizedBox(height: 6),
                                      Row(
                                        children: [
                                          const Icon(
                                            Icons.delivery_dining,
                                            size: 18,
                                            color: Color(0xFF2563EB),
                                          ),
                                          const SizedBox(width: 4),
                                          Text(
                                            "Envío aprox: ${DistanceUtils.formatPrice(deliveryFee)}",
                                            style: const TextStyle(
                                              fontSize: 14,
                                              color: Color(0xFF2563EB),
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ],
                                ),
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => StoreProductsPage(
                                        storeId: store["id"],
                                        storeName: store["name"],
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}

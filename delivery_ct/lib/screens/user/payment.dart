import 'dart:convert';
import 'package:delivery_ct/config/env.dart';
import 'package:delivery_ct/controllers/cart_item.dart';
import 'package:delivery_ct/data/models/address.dart';
import 'package:delivery_ct/data/models/payment.dart';
import 'package:delivery_ct/screens/user/order_success.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'package:intl/date_symbol_data_local.dart';

enum PaymentMethod { efectivo, transferencia, tarjeta }

enum TransferApp { ahorita, deuna, jepfaster, megowallet }

class PaymentScreen extends StatefulWidget {
  final PaymentArguments args;
  const PaymentScreen({super.key, required this.args});

  @override
  State<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends State<PaymentScreen> {
  PaymentMethod _selectedMethod = PaymentMethod.efectivo;
  TransferApp? _selectedTransferApp;
  bool _isLoading = false;

  // Para el selector de fecha
  DateTime _selectedDate = DateTime.now();

  // Lista de direcciones para poder cambiar
  List<Address> _addresses = [];
  Address? _selectedAddress;
  bool _isLoadingAddresses = true;

  @override
  void initState() {
    super.initState();
    _selectedAddress = widget.args.address;
    _initializeLocale();
    _fetchAddresses();
  }

  Future<void> _initializeLocale() async {
    await initializeDateFormatting('es', null);
  }

  Future<void> _fetchAddresses() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString("accessToken");
      final userId = prefs.getInt("userId");

      final url = Uri.parse('${ENV.API_URL}api/addresses/?id=${userId}');

      final response = await http.get(
        url,
        headers: {
          "Content-Type": "application/json",
          "Authorization": "Bearer $token",
        },
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        setState(() {
          _addresses = data.map((json) => Address.fromJson(json)).toList();
          _isLoadingAddresses = false;
        });
      } else {
        setState(() => _isLoadingAddresses = false);
      }
    } catch (e) {
      setState(() => _isLoadingAddresses = false);
    }
  }

  /// Método para obtener el valor correcto de payment_method
  String _getPaymentMethodValue() {
    if (_selectedMethod == PaymentMethod.efectivo) {
      return "cash";
    } else if (_selectedMethod == PaymentMethod.transferencia) {
      // Si es transferencia, devolver el nombre de la app seleccionada
      switch (_selectedTransferApp) {
        case TransferApp.ahorita:
          return "ahorita";
        case TransferApp.deuna:
          return "deuna";
        case TransferApp.jepfaster:
          return "jetfaster";
        case TransferApp.megowallet:
          return "megowallet";
        default:
          return "cash"; // Fallback
      }
    } else if (_selectedMethod == PaymentMethod.tarjeta) {
      return "tarjeta";
    }
    return "cash"; // Fallback por defecto
  }

  Future<void> _submitOrder(CartProvider cart) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString("accessToken");
    final args = widget.args;
    // Validaciones
    if (_selectedMethod == PaymentMethod.transferencia &&
        _selectedTransferApp == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Selecciona una app de transferencia")),
      );
      return;
    }

    if (_selectedMethod == PaymentMethod.tarjeta) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Pago con tarjeta próximamente disponible")),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getInt('userId');

      if (userId == null) {
        throw Exception("No se encontró el ID del cliente");
      }

      // Construir el body del request con un solo payment_method
      final orderBody = {
        "store": args.storeId,
        "client": userId,
        "delivery_address": _selectedAddress?.id ?? args.address.id,
        "delivery_fee": args.deliveryFee,
        "payment_method": _getPaymentMethodValue(),
        "dt": _selectedDate.toIso8601String(),
        if (args.orderComment != null && args.orderComment!.isNotEmpty)
          "order_comment": args.orderComment,
        "items": cart.items
            .map(
              (item) => {
                "product": item.id,
                "price": item.price,
                "quantity": item.quantity,
              },
            )
            .toList(),
      };

      print(orderBody);

      final response = await http.post(
        Uri.parse('${ENV.API_URL}/api/orders/'),
        headers: {
          'Content-Type': 'application/json',
          "Authorization": "Bearer $token",
        },
        body: json.encode(orderBody),
      );


      if (response.statusCode == 200 || response.statusCode == 201) {
        // Limpiar el carrito
        cart.items.clear();

        // Obtener el ID de la orden creada
        final orderResponse = jsonDecode(response.body);
        final orderId = orderResponse['id'];

        // Navegar a la pantalla de éxito
        if (mounted) {
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(
              builder: (_) => OrderSuccessScreen(orderId: orderId),
            ),
            (route) => route.isFirst, // Mantener solo la primera ruta
          );
        }
      } else {
        throw Exception("Error al crear el pedido: ${response.request} ${response.body}");
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _showAddressDatePicker() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) {
          return Container(
            padding: EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Dirección de entrega",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 12),
                if (_isLoadingAddresses)
                  Center(child: CircularProgressIndicator())
                else
                  ..._addresses.map(
                    (address) => RadioListTile<Address>(
                      title: Text(address.name),
                      subtitle: Text(
                        address.description,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      value: address,
                      groupValue: _selectedAddress,
                      onChanged: (value) {
                        setModalState(() => _selectedAddress = value);
                        setState(() {});
                      },
                    ),
                  ),
                Divider(height: 32),
                Text(
                  "Fecha de entrega",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 12),
                ListTile(
                  leading: Icon(Icons.calendar_today),
                  title: Text(
                    DateFormat('EEEE, d MMMM', 'es').format(_selectedDate),
                  ),
                  trailing: Icon(Icons.chevron_right),
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: _selectedDate,
                      firstDate: DateTime.now(),
                      lastDate: DateTime.now().add(Duration(days: 7)),
                      locale: Locale('es', ''),
                    );
                    if (picked != null) {
                      setModalState(() => _selectedDate = picked);
                      setState(() {});
                    }
                  },
                ),
                SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text("Confirmar"),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final args = widget.args;
    final cart = Provider.of<CartProvider>(context);

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text(
          "Confirmar pedido",
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
        centerTitle: true,
        backgroundColor: const Color(0xFF2563EB), // Azul principal
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ---- Dirección de entrega ----
                  Container(
                    margin: EdgeInsets.all(16),
                    padding: EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey[200]!),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              "Dirección de entrega",
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            TextButton(
                              onPressed: _showAddressDatePicker,
                              child: const Text(
                                "Cambiar",
                                style: TextStyle(color: Color(0xFF2563EB)), // Azul principal
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 8),
                        Row(
                          children: [
                            Icon(
                              Icons.location_on,
                              size: 20,
                              color: Colors.grey[600],
                            ),
                            SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _selectedAddress?.description ??
                                    args.address.description,
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey[700],
                                ),
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 12),
                        Row(
                          children: [
                            Icon(
                              Icons.calendar_today,
                              size: 20,
                              color: Colors.grey[600],
                            ),
                            SizedBox(width: 8),
                            Text(
                              DateFormat(
                                'EEEE, d MMMM',
                                'es',
                              ).format(_selectedDate),
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey[700],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  // ---- Método de pago ----
                  Container(
                    margin: EdgeInsets.symmetric(horizontal: 16),
                    padding: EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey[200]!),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Método de pago",
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        SizedBox(height: 16),

                        // ---- Efectivo ----
                        _buildPaymentOption(
                          title: "Efectivo",
                          subtitle: null,
                          value: PaymentMethod.efectivo,
                          showExpansion: false,
                        ),

                        Divider(height: 24),

                        // ---- Transferencia ----
                        _buildPaymentOption(
                          title: "Transferencia",
                          subtitle: null,
                          value: PaymentMethod.transferencia,
                          showExpansion: true,
                          expansionContent: _buildTransferOptions(),
                        ),

                        Divider(height: 24),

                        // Texto informativo
                        Padding(
                          padding: EdgeInsets.only(top: 8),
                          child: Text(
                            "Todos los datos de pago están protegidos y encriptados",
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                          ),
                        ),

                        // ---- Tarjeta (Próximamente) ----
                        _buildPaymentOption(
                          title: "Tarjeta de crédito o debito",
                          subtitle: "(Proximamente)",
                          value: PaymentMethod.tarjeta,
                          showExpansion: false,
                          enabled: false,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ---- Botón Pedir ----
          Padding(
            padding: EdgeInsets.all(24),
            child: SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Color(0xFF5B9BD5), // Azul como en la imagen
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 0,
                ),
                onPressed: _isLoading ? null : () => _submitOrder(cart),
                child: _isLoading
                    ? SizedBox(
                        height: 24,
                        width: 24,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : Text(
                        "Pedir",
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentOption({
    required String title,
    String? subtitle,
    required PaymentMethod value,
    required bool showExpansion,
    Widget? expansionContent,
    bool enabled = true,
  }) {
    final isSelected = _selectedMethod == value;

    return Column(
      children: [
        InkWell(
          onTap: enabled
              ? () {
                  setState(() {
                    _selectedMethod = value;
                    if (value != PaymentMethod.transferencia) {
                      _selectedTransferApp = null;
                    }
                  });
                }
              : null,
          child: Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Row(
              children: [
                // Radio button personalizado
                Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: enabled
                          ? (isSelected ? Color(0xFF5B9BD5) : Colors.grey[400]!)
                          : Colors.grey[300]!,
                      width: 2,
                    ),
                  ),
                  child: isSelected
                      ? Center(
                          child: Container(
                            width: 12,
                            height: 12,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Color(0xFF5B9BD5),
                            ),
                          ),
                        )
                      : null,
                ),
                SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            title,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                              color: enabled ? Colors.black : Colors.grey[400],
                            ),
                          ),
                          if (showExpansion && isSelected) ...[
                            SizedBox(width: 4),
                            Icon(
                              Icons.keyboard_arrow_down,
                              color: Colors.grey[600],
                              size: 20,
                            ),
                          ],
                        ],
                      ),
                      if (subtitle != null)
                        Text(
                          subtitle,
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[400],
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        if (showExpansion && isSelected && expansionContent != null)
          expansionContent,
      ],
    );
  }

  Widget _buildTransferOptions() {
    return Padding(
      padding: EdgeInsets.only(left: 40, top: 8, bottom: 8),
      child: Wrap(
        spacing: 16,
        runSpacing: 16,
        children: [
          _buildTransferAppButton(
            app: TransferApp.ahorita,
            name: "Ahorita!",
            color: Color(0xFF4CAF50), // Verde
            icon: Icons.access_time, // Puedes reemplazar con la imagen real
          ),
          _buildTransferAppButton(
            app: TransferApp.deuna,
            name: "De una!",
            color: Color(0xFF9E9E9E), // Gris
            icon: Icons.flash_on,
          ),
          _buildTransferAppButton(
            app: TransferApp.jepfaster,
            name: "Jep Faster",
            color: Color(0xFFFFFFFF),
            icon: Icons.speed,
            textColor: Colors.green,
            hasBorder: true,
          ),
          _buildTransferAppButton(
            app: TransferApp.megowallet,
            name: "MegoWallet",
            color: Color(0xFF1565C0), // Azul oscuro
            icon: Icons.account_balance_wallet,
          ),
        ],
      ),
    );
  }

  Widget _buildTransferAppButton({
    required TransferApp app,
    required String name,
    required Color color,
    required IconData icon,
    Color textColor = Colors.white,
    bool hasBorder = false,
  }) {
    final isSelected = _selectedTransferApp == app;

    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedTransferApp = app;
        });
      },
      child: Container(
        width: 90,
        padding: EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: isSelected ? Colors.blue[50] : Colors.grey[100],
          borderRadius: BorderRadius.circular(12),
          border: isSelected
              ? Border.all(color: Color(0xFF5B9BD5), width: 2)
              : null,
        ),
        child: Column(
          children: [
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(12),
                border: hasBorder ? Border.all(color: Colors.grey[300]!) : null,
              ),
              child: Center(
                child: Icon(icon, color: textColor, size: 32),
                // Si tienes las imágenes de los logos, reemplaza con:
                // Image.asset('assets/images/${app.name}.png', width: 40),
              ),
            ),
            SizedBox(height: 4),
            Text(
              name,
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

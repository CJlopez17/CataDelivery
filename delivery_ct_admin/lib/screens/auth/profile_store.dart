import 'package:delivery_ct_admin/config/env.dart';
import 'package:delivery_ct_admin/screens/auth/login.dart';
import 'package:delivery_ct_admin/screens/auth/profile.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:io';

class ProfileStore extends StatefulWidget {
  const ProfileStore({super.key});

  @override
  State<ProfileStore> createState() => _ProfileStoreState();
}

class _ProfileStoreState extends State<ProfileStore> {
  String userName = "Local Comercial";
  int userId = 0;
  bool isAvailable = true;
  bool isLoadingStatus = false;
  bool isLoading = true;

  // Subscription data
  Map? subscription;
  bool hasSubscription = false;
  bool isLoadingSubscription = false;

  bool get _isSubscriptionActive {
    if (!hasSubscription || subscription == null) return false;
    if (subscription!['status'] != 'active') return false;
    return !(subscription!['is_expired'] ?? true);
  }

  bool get _isSubscriptionPending {
    if (subscription == null) return false;
    return subscription!['status'] == 'pending';
  }

  int get _daysRemaining {
    if (subscription == null) return 0;
    return subscription!['days_remaining'] ?? 0;
  }

  @override
  void initState() {
    super.initState();
    loadSubscription();
    loadUserData();
  }

  Future<void> loadUserData() async {
    setState(() => isLoading = true);

    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString("accessToken");
    userId = prefs.getInt("userId") ?? 0;

    try {
      final url = Uri.parse("${ENV.API_URL}/api/users/$userId/");
      final response = await http.get(
        url,
        headers: {"Content-Type": "application/json", "Authorization": "Bearer $token"},
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          userName = "${data['first_name'] ?? ''} ${data['last_name'] ?? ''}".trim();
          if (userName.isEmpty) {
            userName = data['username'] ?? "Local Comercial";
          }
          isAvailable = data['is_available'] ?? true;
          isLoading = false;
        });
      } else {
        setState(() {
          isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        isLoading = false;
      });
    }
  }

  Future<void> loadSubscription() async {
    setState(() => isLoadingSubscription = true);

    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString("accessToken");

    try {
      final response = await http.get(
        Uri.parse("${ENV.API_URL}/api/users/my_subscription/"),
        headers: {"Content-Type": "application/json", "Authorization": "Bearer $token"},
      );

      print(response.body);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          hasSubscription = data['has_subscription'] ?? false;
          subscription = data['subscription'];
          isLoadingSubscription = false;
        });
      } else {
        setState(() {
          isLoadingSubscription = false;
        });
      }
    } catch (e) {
      setState(() {
        isLoadingSubscription = false;
      });
    }
  }

  Future<void> uploadPaymentProof() async {
    // Mostrar selector de archivos
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['jpg', 'jpeg', 'png', 'pdf'],
    );

    if (result == null) return;

    PlatformFile file = result.files.first;

    // Validar tamaño (máximo 2.5 MB)
    const maxSizeInBytes = 2.5 * 1024 * 1024;
    if (file.size > maxSizeInBytes) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("El archivo es demasiado grande. El tamaño máximo es 2.5 MB."),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (file.path == null) return;

    // Mostrar indicador de carga
    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    String? successMessage;
    String? errorMessage;

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString("accessToken");

      var request = http.MultipartRequest('POST', Uri.parse("${ENV.API_URL}/api/users/upload_payment_proof/"));
      request.headers['Authorization'] = 'Bearer $token';
      request.files.add(await http.MultipartFile.fromPath('document', file.path!));

      var streamedResponse = await request.send().timeout(const Duration(seconds: 30));
      var response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = jsonDecode(response.body);
        successMessage = data['detail'] ?? 'Comprobante subido exitosamente';

        // Actualizar estado inmediatamente con la suscripción pendiente
        setState(() {
          hasSubscription = true;
          subscription = data['subscription'];
        });
      } else {
        try {
          final errorData = jsonDecode(response.body);
          errorMessage = errorData['detail'] ?? 'Error al subir el comprobante';
        } catch (_) {
          errorMessage = 'Error al subir el comprobante';
        }
      }
    } catch (e) {
      errorMessage = "Error de conexión. Intenta de nuevo.";
    } finally {
      // SIEMPRE cerrar el dialog de carga
      if (mounted) {
        Navigator.of(context).pop();
      }
    }

    if (!mounted) return;

    if (successMessage != null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(successMessage), backgroundColor: Colors.green));
    } else if (errorMessage != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(errorMessage), backgroundColor: Colors.red));
    }
  }

  Future<void> toggleActiveStatus() async {
    setState(() {
      isLoadingStatus = true;
    });

    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString("accessToken");

    try {
      final response = await http.post(
        Uri.parse("${ENV.API_URL}/api/auth/toggle-active/"),
        headers: {"Content-Type": "application/json", "Authorization": "Bearer $token"},
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          isAvailable = data["is_available"];
          isLoadingStatus = false;
        });

        if (!mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(data["detail"]), backgroundColor: Colors.green));
      } else {
        setState(() {
          isLoadingStatus = false;
        });

        if (!mounted) return;
        String errorMessage = "Error al cambiar la disponibilidad";
        try {
          final errorData = jsonDecode(response.body);
          errorMessage = errorData["detail"] ?? errorMessage;
        } catch (_) {}

        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(errorMessage), backgroundColor: Colors.red));
      }
    } catch (e) {
      setState(() {
        isLoadingStatus = false;
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Error de conexión. Intenta de nuevo."), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();

    if (!mounted) return;

    Navigator.of(
      context,
      rootNavigator: true,
    ).pushAndRemoveUntil(MaterialPageRoute(builder: (context) => const LoginPage()), (route) => false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text("Mi Perfil"),
        backgroundColor: const Color(0xFF2563EB),
        foregroundColor: Colors.white,
        centerTitle: true,
        automaticallyImplyLeading: false,
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  // Avatar y nombre
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 10, offset: const Offset(0, 4)),
                      ],
                    ),
                    child: Column(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: const Color(0xFF2563EB).withOpacity(0.1),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.store, size: 60, color: Color(0xFF2563EB)),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          userName,
                          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFF1E1E1E)),
                        ),
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: const Color(0xFF2563EB),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Text(
                            "Local Comercial",
                            style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Card de estado Activo/Inactivo
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: !_isSubscriptionActive && !isLoadingSubscription
                          ? Border.all(
                              color: _isSubscriptionPending
                                  ? Colors.blue.withOpacity(0.3)
                                  : Colors.red.withOpacity(0.3),
                              width: 1,
                            )
                          : null,
                      boxShadow: [
                        BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 6, offset: const Offset(0, 2)),
                      ],
                    ),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: (!_isSubscriptionActive && !isLoadingSubscription)
                                    ? (_isSubscriptionPending
                                          ? Colors.blue.withOpacity(0.1)
                                          : Colors.red.withOpacity(0.1))
                                    : (isAvailable ? Colors.green : Colors.orange).withOpacity(0.1),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Icon(
                                (!_isSubscriptionActive && !isLoadingSubscription)
                                    ? (_isSubscriptionPending ? Icons.hourglass_empty : Icons.block)
                                    : (isAvailable ? Icons.check_circle : Icons.pause_circle),
                                color: (!_isSubscriptionActive && !isLoadingSubscription)
                                    ? (_isSubscriptionPending ? Colors.blue : Colors.red)
                                    : (isAvailable ? Colors.green : Colors.orange),
                                size: 24,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    "Disponibilidad",
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w500,
                                      color: Color(0xFF1E1E1E),
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  if (_isSubscriptionPending)
                                    Text(
                                      "Pago en revisión - esperando aprobación",
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.blue[700],
                                        fontWeight: FontWeight.w500,
                                      ),
                                    )
                                  else if (!_isSubscriptionActive && !isLoadingSubscription)
                                    Text(
                                      "Suscripción requerida para recibir pedidos",
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.red[700],
                                        fontWeight: FontWeight.w500,
                                      ),
                                    )
                                  else
                                    Text(
                                      isAvailable
                                          ? "Disponible - Recibiendo pedidos"
                                          : "No disponible - No recibiendo pedidos",
                                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                                    ),
                                  if (_isSubscriptionActive && _daysRemaining > 0) ...[
                                    const SizedBox(height: 2),
                                    Text(
                                      "$_daysRemaining ${_daysRemaining == 1 ? 'día restante' : 'días restantes'} de suscripción",
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: _daysRemaining <= 5 ? Colors.orange[700] : Colors.grey[500],
                                        fontWeight: _daysRemaining <= 5 ? FontWeight.w600 : FontWeight.normal,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            if (isLoadingStatus)
                              const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2))
                            else
                              Switch(
                                value: isAvailable,
                                onChanged: (_isSubscriptionActive) ? (value) => toggleActiveStatus() : null,
                                activeColor: Colors.green,
                              ),
                          ],
                        ),
                        if (!_isSubscriptionActive && !_isSubscriptionPending && !isLoadingSubscription) ...[
                          const SizedBox(height: 12),
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: Colors.red.shade50,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.info_outline, color: Colors.red.shade700, size: 18),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    hasSubscription
                                        ? "Tu suscripción ha vencido. Renueva tu pago para poder activarte."
                                        : "Necesitas una suscripción activa para recibir pedidos.",
                                    style: TextStyle(fontSize: 11, color: Colors.red.shade900),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Sección de Suscripción
                  if (isLoadingSubscription)
                    const Center(child: CircularProgressIndicator())
                  else if (_isSubscriptionPending)
                    _buildPendingSubscriptionCard()
                  else if (_isSubscriptionActive)
                    _buildSubscriptionCard()
                  else
                    _buildNoSubscriptionCard(),
                  const SizedBox(height: 24),

                  // Opciones del perfil
                  _buildProfileButton(
                    icon: Icons.attach_money,
                    title: "Mis ganancias",
                    onTap: () {
                      ScaffoldMessenger.of(
                        context,
                      ).showSnackBar(const SnackBar(content: Text("Funcionalidad próximamente")));
                    },
                  ),
                  const SizedBox(height: 12),

                  _buildProfileButton(
                    icon: Icons.edit,
                    title: "Editar información personal",
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const ProfilePage()),
                      ).then((_) => loadUserData());
                    },
                  ),
                  const SizedBox(height: 12),

                  _buildProfileButton(
                    icon: Icons.help_outline,
                    title: "Ayuda y soporte",
                    onTap: () {
                      ScaffoldMessenger.of(
                        context,
                      ).showSnackBar(const SnackBar(content: Text("Funcionalidad próximamente")));
                    },
                  ),
                  const SizedBox(height: 12),

                  _buildProfileButton(
                    icon: Icons.exit_to_app,
                    title: "Cerrar sesión",
                    color: Colors.red,
                    onTap: () {
                      showDialog(
                        context: context,
                        builder: (context) => AlertDialog(
                          title: const Text("Cerrar sesión"),
                          content: const Text("¿Estás seguro que deseas cerrar sesión?"),
                          actions: [
                            TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancelar")),
                            TextButton(
                              onPressed: () {
                                Navigator.pop(context);
                                logout();
                              },
                              child: const Text("Cerrar sesión", style: TextStyle(color: Colors.red)),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildProfileButton({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    Color color = const Color(0xFF2563EB),
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 6, offset: const Offset(0, 2))],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: Color(0xFF1E1E1E)),
              ),
            ),
            Icon(Icons.arrow_forward_ios, color: Colors.grey[400], size: 18),
          ],
        ),
      ),
    );
  }

  Widget _buildSubscriptionCard() {
    final isExpired = subscription!['is_expired'] ?? false;
    final daysRemaining = subscription!['days_remaining'] ?? 0;
    final expiresAt = subscription!['expires_at'];

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isExpired ? Colors.red : const Color(0xFF10B981), width: 2),
        boxShadow: [
          BoxShadow(
            color: (isExpired ? Colors.red : const Color(0xFF10B981)).withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: (isExpired ? Colors.red : const Color(0xFF10B981)).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  isExpired ? Icons.warning : Icons.verified,
                  color: isExpired ? Colors.red : const Color(0xFF10B981),
                  size: 28,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "Suscripción Mensual",
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF1E1E1E)),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      isExpired
                          ? "Suscripción vencida"
                          : "$daysRemaining ${daysRemaining == 1 ? 'día restante' : 'días restantes'}",
                      style: TextStyle(
                        fontSize: 14,
                        color: isExpired ? Colors.red : const Color(0xFF10B981),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: isExpired ? Colors.red : const Color(0xFF10B981),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  isExpired ? "Vencida" : "Activa",
                  style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Información de la suscripción
          _buildSubscriptionInfo(icon: Icons.calendar_today, label: "Vence el", value: _formatDate(expiresAt)),

          // Advertencia si está vencida
          if (isExpired) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: Colors.red.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
              child: Row(
                children: [
                  const Icon(Icons.warning, color: Colors.red, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      "Tu suscripción ha vencido. Sube tu comprobante de pago para renovar y poder recibir pedidos.",
                      style: TextStyle(fontSize: 12, color: Colors.red[900]),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: uploadPaymentProof,
                icon: const Icon(Icons.autorenew, size: 20),
                label: const Text("Renovar Suscripción", style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2563EB),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPendingSubscriptionCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.blue, width: 2),
        boxShadow: [BoxShadow(color: Colors.blue.withOpacity(0.1), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: Colors.blue.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
                child: const Icon(Icons.hourglass_empty, color: Colors.blue, size: 28),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "Pago en Revisión",
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF1E1E1E)),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      "Comprobante recibido",
                      style: TextStyle(fontSize: 14, color: Colors.blue[700], fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(color: Colors.blue, borderRadius: BorderRadius.circular(20)),
                child: const Text(
                  "Pendiente",
                  style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: Colors.blue.shade50, borderRadius: BorderRadius.circular(8)),
            child: Row(
              children: [
                Icon(Icons.info_outline, color: Colors.blue.shade700, size: 20),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    "Tu comprobante de pago está siendo revisado por el administrador. Serás notificado cuando tu suscripción sea aprobada.",
                    style: TextStyle(color: Colors.black87, fontSize: 12),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNoSubscriptionCard() {
    // Verificar si hay un documento pendiente de revisión
    final hasPendingDocument = subscription?['has_pending_document'] ?? false;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: hasPendingDocument ? Colors.blue : Colors.orange, width: 2),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 6, offset: const Offset(0, 2))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: (hasPendingDocument ? Colors.blue : Colors.orange).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  hasPendingDocument ? Icons.hourglass_empty : Icons.error_outline,
                  color: hasPendingDocument ? Colors.blue : Colors.orange,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      hasPendingDocument ? "Pago en Revisión" : "Sin Suscripción",
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF1E1E1E)),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      hasPendingDocument ? "Comprobante recibido" : "No tienes una suscripción activa",
                      style: TextStyle(
                        fontSize: 12,
                        color: hasPendingDocument ? Colors.blue : Colors.orange,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: (hasPendingDocument ? Colors.blue.shade50 : Colors.orange.shade50),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.info_outline,
                  color: hasPendingDocument ? Colors.blue.shade700 : Colors.orange.shade700,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    hasPendingDocument
                        ? "Tu comprobante de pago está siendo revisado por el administrador. Serás notificado cuando tu suscripción sea aprobada y puedas volver a recibir pedidos."
                        : "Contacta al administrador para activar tu suscripción y poder recibir pedidos.",
                    style: const TextStyle(color: Colors.black87, fontSize: 12),
                  ),
                ),
              ],
            ),
          ),
          // Botón para subir comprobante si no hay documento pendiente
          if (!hasPendingDocument) ...[
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: uploadPaymentProof,
                icon: const Icon(Icons.upload_file, size: 18),
                label: const Text("Subir Comprobante"),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2563EB),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSubscriptionInfo({required IconData icon, required String label, required String value}) {
    return Row(
      children: [
        Icon(icon, size: 18, color: Colors.grey[600]),
        const SizedBox(width: 8),
        Text(label, style: TextStyle(fontSize: 14, color: Colors.grey[600])),
        const SizedBox(width: 8),
        Text(
          value,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF1E1E1E)),
        ),
      ],
    );
  }

  String _formatDate(String dateString) {
    try {
      final date = DateTime.parse(dateString);
      final months = ['Ene', 'Feb', 'Mar', 'Abr', 'May', 'Jun', 'Jul', 'Ago', 'Sep', 'Oct', 'Nov', 'Dic'];
      return '${date.day} ${months[date.month - 1]} ${date.year}';
    } catch (e) {
      return dateString;
    }
  }
}

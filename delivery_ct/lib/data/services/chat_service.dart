import 'dart:async';
import 'dart:convert';
import 'package:delivery_ct/config/env.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

class ChatService {
  WebSocketChannel? _channel;
  final _messageController = StreamController<Map<String, dynamic>>.broadcast();

  Stream<Map<String, dynamic>> get messageStream => _messageController.stream;
  bool get isConnected => _channel != null;

  /// Obtiene o crea una conversación para un pedido.
  /// Retorna el JSON de la conversación con el campo "id" (UUID).
  Future<Map<String, dynamic>?> getOrCreateConversation({
    required int orderId,
    required int otherUserId,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString("accessToken");

    final response = await http.post(
      Uri.parse("${ENV.API_URL}/api/chat/conversations/get_or_create/"),
      headers: {
        "Content-Type": "application/json",
        "Authorization": "Bearer $token",
      },
      body: jsonEncode({
        "order_id": orderId,
        "other_user_id": otherUserId,
      }),
    );

    if (response.statusCode == 200 || response.statusCode == 201) {
      return jsonDecode(response.body);
    }
    return null;
  }

  /// Obtiene el historial de mensajes de una conversación.
  Future<List<Map<String, dynamic>>> getMessages(String conversationId) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString("accessToken");

    final response = await http.get(
      Uri.parse(
          "${ENV.API_URL}/api/chat/conversations/$conversationId/messages/"),
      headers: {
        "Content-Type": "application/json",
        "Authorization": "Bearer $token",
      },
    );

    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body);
      return data.cast<Map<String, dynamic>>();
    }
    return [];
  }

  /// Conecta al WebSocket de una conversación.
  Future<void> connect(String conversationId) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString("accessToken");

    // Construir la URL del WebSocket
    String wsBase = ENV.API_URL.replaceFirst("http://", "ws://")
        .replaceFirst("https://", "wss://");
    if (wsBase.endsWith("/")) {
      wsBase = wsBase.substring(0, wsBase.length - 1);
    }
    final wsUrl = "$wsBase/ws/chat/$conversationId/?token=$token";

    disconnect();

    _channel = WebSocketChannel.connect(Uri.parse(wsUrl));

    _channel!.stream.listen(
      (data) {
        try {
          final message = jsonDecode(data as String);
          _messageController.add(Map<String, dynamic>.from(message));
        } catch (_) {}
      },
      onError: (error) {
        disconnect();
      },
      onDone: () {
        _channel = null;
      },
    );
  }

  /// Envía un mensaje por WebSocket.
  void sendMessage(String text) {
    if (_channel != null) {
      _channel!.sink.add(jsonEncode({"message": text}));
    }
  }

  /// Cierra la conexión WebSocket.
  void disconnect() {
    _channel?.sink.close();
    _channel = null;
  }

  /// Libera recursos.
  void dispose() {
    disconnect();
    _messageController.close();
  }
}

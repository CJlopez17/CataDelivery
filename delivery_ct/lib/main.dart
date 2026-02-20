import 'package:delivery_ct/controllers/cart_item.dart';
import 'package:delivery_ct/routes/app_routes.dart';
import 'package:delivery_ct/services/notification_service.dart';
import 'package:delivery_ct/firebase_options.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'package:provider/provider.dart';

// GlobalKey para acceder al Navigator desde cualquier parte
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await setup();
  runApp(
    MultiProvider(
      providers: [ChangeNotifierProvider(create: (_) => CartProvider())],
      child: const MyApp(),
    ),
  );
}

Future<void> setup() async {
  // Cargar variables de entorno
  await dotenv.load(fileName: ".env");
  MapboxOptions.setAccessToken(dotenv.env['MAPBOX_ACCESS_TOKEN']!);
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: navigatorKey, // Agregar GlobalKey para navegación desde notificaciones
      debugShowCheckedModeBanner: false,
      title: 'DeliveryCT',
      initialRoute: AppRoutes.selectAccount,
      onGenerateRoute: AppRoutes.generateRoute,
    );
  }
}

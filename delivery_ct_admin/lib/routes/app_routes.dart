import 'package:delivery_ct_admin/screens/auth/login.dart';
import 'package:delivery_ct_admin/screens/home.dart';
import 'package:delivery_ct_admin/screens/new_product.dart';
import 'package:delivery_ct_admin/widgets/button_panel.dart';
import 'package:delivery_ct_admin/widgets/button_panel_delivery.dart';
import 'package:flutter/material.dart';

class AppRoutes {
  static const String login = '/login';
  static const String home = '/home';
  static const String newProduct = 'newProduct';
  static const String butonPanel = '/butonPanel';
  static const String deliveryPanel = '/deliveryPanel';

  static Route<dynamic> generateRoute(RouteSettings settings) {
    switch (settings.name) {
      case login:
        return MaterialPageRoute(builder: (_) => const LoginPage());
      case home:
        return MaterialPageRoute(builder: (_) =>  Home());
      case butonPanel:
        return MaterialPageRoute(builder: (_) => const Button_Panel());
      case deliveryPanel:
        return MaterialPageRoute(builder: (_) => const ButtonPanelDelivery());
      default:
        return MaterialPageRoute(
          builder: (_) => const Scaffold(
            body: Center(child: Text('Pagina no encontrada')),
          ),
        );
    }
  }
}
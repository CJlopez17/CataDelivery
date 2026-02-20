import 'package:delivery_ct/screens/auth/change_password.dart';
import 'package:delivery_ct/screens/auth/login.dart';
import 'package:delivery_ct/screens/auth/profile.dart';
import 'package:delivery_ct/screens/auth/register.dart';
import 'package:delivery_ct/screens/auth/select_account.dart';
import 'package:delivery_ct/screens/user/address/create_address.dart';
import 'package:delivery_ct/screens/user/home_user.dart';
import 'package:delivery_ct/screens/user/address/list_address.dart';
import 'package:delivery_ct/screens/user/order_history.dart';
import 'package:delivery_ct/screens/user/order_tracking.dart';
import 'package:delivery_ct/screens/user/stores_list.dart';
import 'package:delivery_ct/screens/user/work_with_us.dart';
import 'package:delivery_ct/widgets/button_panel_user.dart';
import 'package:flutter/material.dart';

class AppRoutes {
  static const String initial = '/';
  static const String profile = '/profile';
  static const String login = '/login';
  static const String selectAccount = '/select_account';
  static const String register = '/register';
  static const String homeScreenUser = '/homeScreenUser';
  static const String butonPanelUser = '/butonPanelUser';
  static const String orderHistory = '/orderHistory';
  static const String buttonpaneluser = '/buttonpaneluser';
  static const String workWithUs = '/workWithUs';
  static const String storeList = '/storeList';
  static const String addressesList = '/addressesList';
  static const String createAddress = '/createAddress';
  static const String editAddress = '/editAddress';
  static const String changePasswordPage = '/changePasswordPage';
  static const String payment = '/payment';
  static const String orderTracking = '/orderTracking';


  static Route<dynamic> generateRoute(RouteSettings settings) {
    switch (settings.name) {
      //auth
      case selectAccount:
        return MaterialPageRoute(builder: (_) => const SelectAccount());
      case login:
        return MaterialPageRoute(builder: (_) => const LoginPage());
      case register:
        return MaterialPageRoute(builder: (_) => const RegisterPage());
      case changePasswordPage:
        return MaterialPageRoute(builder: (_) => const ChangePasswordPage());

      //user
      case buttonpaneluser:
        return MaterialPageRoute(builder: (_) => const Button_Panel_User());
      case homeScreenUser:
        return MaterialPageRoute(builder: (_) => const HomeScreenUser());
      case orderHistory:
        return MaterialPageRoute(builder: (_) => const OrderHistory());
      case workWithUs:
        return MaterialPageRoute(builder: (_) => const RequestRoleScreen());
      case storeList:
        return MaterialPageRoute(builder: (_) => const StoresListPage());
      case addressesList:
        return MaterialPageRoute(builder: (_) => const AddressesList());
      case createAddress:
        return MaterialPageRoute(builder: (_) => const AddAddressPage());
      case orderTracking:
        final orderId = settings.arguments as int;
        return MaterialPageRoute(
          builder: (_) => OrderTrackingScreen(orderId: orderId),
        );



      // all users
      case profile:
        return MaterialPageRoute(builder: (_) => const Profile());

      default:
        return MaterialPageRoute(builder: (_) => const SelectAccount());
    }
  }
}

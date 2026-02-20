import 'package:delivery_ct_admin/screens/home.dart';
import 'package:delivery_ct_admin/screens/orders.dart';
import 'package:delivery_ct_admin/screens/auth/profile_store.dart';
import 'package:flutter/material.dart';
import 'package:persistent_bottom_nav_bar/persistent_bottom_nav_bar.dart';

class Button_Panel extends StatefulWidget {
  const Button_Panel({super.key});

  @override
  State<Button_Panel> createState() => _Button_Panel_State();
}

class _Button_Panel_State extends State<Button_Panel> {
  late PersistentTabController _controller;

  @override
  void initState() {
    super.initState();
    _controller = PersistentTabController(initialIndex: 0);
  }

  List<Widget> _buildScreens() {
    return [
      const Home(),
      const OrdersPage(),
      const ProfileStore(),
    ];
  }

  List<PersistentBottomNavBarItem> _navBarsItems() {
    return [
      PersistentBottomNavBarItem(
        icon: const Icon(Icons.card_membership),
        title: ("Productos"),
        activeColorPrimary: const Color(0xFF000000),
        inactiveColorPrimary: const Color(0xFF3F3F3F),
      ),
      PersistentBottomNavBarItem(
        icon: const Icon(Icons.inventory),
        title: ("Ordenes"),
        activeColorPrimary: const Color(0xFFFF0000),
        inactiveColorPrimary: const Color(0xFF3F3F3F),
      ),
      PersistentBottomNavBarItem(
        icon: const Icon(Icons.person),
        title: ("Perfil"),
        activeColorPrimary: const Color(0xFFFF0000),
        inactiveColorPrimary: const Color(0xFF3F3F3F),
      ),
    ];
  }
  @override
  Widget build(BuildContext context) {
    return PersistentTabView(
      context,
      controller: _controller,
      screens: _buildScreens(),
      items: _navBarsItems(),
      confineToSafeArea: true,
      backgroundColor: Colors.white,
      handleAndroidBackButtonPress: true,
      resizeToAvoidBottomInset: true,
      stateManagement: true,
      navBarHeight: 60.0,
      decoration: const NavBarDecoration(
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(10.0),
          topRight: Radius.circular(10.0),
        ),
        colorBehindNavBar: Colors.white,
      ),
      navBarStyle: NavBarStyle.style3,
    );
  }
}
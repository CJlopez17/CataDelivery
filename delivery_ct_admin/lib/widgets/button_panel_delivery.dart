import 'package:delivery_ct_admin/screens/delivery/home_delivery.dart';
import 'package:delivery_ct_admin/screens/delivery/profile_delivery.dart';
import 'package:flutter/material.dart';
import 'package:persistent_bottom_nav_bar/persistent_bottom_nav_bar.dart';

class ButtonPanelDelivery extends StatefulWidget {
  const ButtonPanelDelivery({super.key});

  @override
  State<ButtonPanelDelivery> createState() => _ButtonPanelDeliveryState();
}

class _ButtonPanelDeliveryState extends State<ButtonPanelDelivery> {
  late PersistentTabController _controller;

  @override
  void initState() {
    super.initState();
    _controller = PersistentTabController(initialIndex: 0);
  }

  List<Widget> _buildScreens() {
    return [
      const HomeDelivery(),
      const ProfileDelivery(),
    ];
  }

  List<PersistentBottomNavBarItem> _navBarsItems() {
    return [
      PersistentBottomNavBarItem(
        icon: const Icon(Icons.home),
        title: ("Inicio"),
        activeColorPrimary: const Color(0xFF2563EB),
        inactiveColorPrimary: const Color(0xFF3F3F3F),
      ),
      PersistentBottomNavBarItem(
        icon: const Icon(Icons.person),
        title: ("Perfil"),
        activeColorPrimary: const Color(0xFF2563EB),
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

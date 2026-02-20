import 'package:flutter/material.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({Key? key}) : super(key: key);

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  MapboxMap? mapboxController;

  @override
  Widget build(BuildContext context) {
    return Scaffold(body: MapWidget(onMapCreated: _onMapCreated));
  }

  void _onMapCreated(MapboxMap controller) {
    setState(() {
      mapboxController = controller;
    });

    mapboxController?.location.updateSettings(
      LocationComponentSettings(enabled: true,
      pulsingEnabled: true),
    );
  } 
}

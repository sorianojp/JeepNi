import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';

class AppMapTileLayer extends StatelessWidget {
  const AppMapTileLayer({super.key});

  @override
  Widget build(BuildContext context) {
    return TileLayer(
      urlTemplate: 'https://{s}.basemaps.cartocdn.com/light_all/{z}/{x}/{y}.png',
      fallbackUrl: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
      subdomains: const ['a', 'b', 'c', 'd'],
      userAgentPackageName: 'com.arzatech.ejeep',
      errorTileCallback: (tile, error, stackTrace) {
        debugPrint('Map tile failed: ${tile.coordinates} $error');
      },
    );
  }
}

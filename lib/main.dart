import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';

import 'data/repositories/marine_repository.dart';
import 'data/services/api_service.dart';
import 'logic/providers/marine_provider.dart';

void main() {
  runApp(const MarineApp());
}

class MarineApp extends StatelessWidget {
  const MarineApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => MarineProvider(MarineRepository(MarineApiService())),
      child: MaterialApp(title: 'Marine Safety', home: const HomeScreen()),
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, this.tileProvider});

  /// Overridable so widget tests can avoid hitting the real tile network.
  final TileProvider? tileProvider;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.only(left: 15, right: 15, top: 70),
        child: Column(
          children: [
            SizedBox(
              height: 250,
              child: FlutterMap(
                options: MapOptions(
                  initialCenter: LatLng(38.3, 26.3),
                  initialZoom: 5.0,
                ),
                children: [
                  TileLayer(
                    urlTemplate: "https://tile.openstreetmap.org/{z}/{x}/{y}.png",
                    userAgentPackageName: "io.beachiq.app",
                    tileProvider: widget.tileProvider ?? NetworkTileProvider(),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

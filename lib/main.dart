import 'package:flutter/material.dart';
import 'data/services/api_service.dart';

void main() {
  runApp(const MarineApp());
}

class MarineApp extends StatelessWidget {
  const MarineApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Marine Safety',
      home: const HomeScreen(),
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final MarineApiService _apiService = MarineApiService();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: FutureBuilder<Map<String, dynamic>>(
        // Java'daki CompletableFuture.thenApply() gibi düşün
        future: _apiService.getSeaData(36.0801, 35.976), // Samandag koordinatları
        builder: (context, snapshot) {
          // 1. Durum: Veri yükleniyor (Loading)
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          // 2. Durum: Hata oluştu (Error Handling)
          if (snapshot.hasError) {
            return Center(child: Text("Hata: ${snapshot.error}"));
          }

          // 3. Durum: Veri geldi (Success)
          final data = snapshot.data!;
          final waveHeight = data['current']['wave_height'];
          final waveDirection = data['current']['wave_direction'];
          final wavePeriod = data['current']['wave_period'];


          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text("Anlık Dalga Boyu:", style: TextStyle(fontSize: 20)),
                Text("$waveHeight metre \n $waveDirection° \n $wavePeriod second",
                    style: const TextStyle(fontSize: 48, fontWeight: FontWeight.bold, color: Colors.blueAccent)),
                const SizedBox(height: 20),
              ],
            ),
          );
        },
      ),
    );
  }

}
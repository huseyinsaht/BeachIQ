import 'package:flutter/material.dart';
import 'domain/interfaces/i_network_service.dart';
import 'domain/interfaces/i_storage_service.dart';
import 'data/services/network_service.dart';
import 'data/services/shared_storage_service.dart';

void main() async {
  // 1. Flutter Engine'i OpenEMS'teki 'activate' gibi uyandırıyoruz
  WidgetsFlutterBinding.ensureInitialized();

  // 2. Servisleri instantiate ediyoruz (Singleton gibi düşünebilirsin)
  final IStorageService storage = SharedStorageService();
  final INetworkService network = NetworkService("https://jsonplaceholder.typicode.com");

  // 3. TEST İÇİN: Hafızaya sahte bir token yazalım (Sadece bir kez çalışması yeterli)
  // Normalde bunu LoginService yapar.
  await storage.saveString("auth_token", "OPENEMS_STYLE_TOKEN_123");

  // 4. Hafızadan token'ı geri oku ve Network servisine enjekte et
  final String? savedToken = await storage.getString("auth_token");
  if (savedToken != null) {
    network.setToken(savedToken);
    print("Token başarıyla yüklendi: $savedToken");
  }

  // 5. Uygulamayı başlat ve ana servisi enjekte et
  runApp(MyApp(networkService: network));
}

class MyApp extends StatelessWidget {
  final INetworkService networkService;

  const MyApp({super.key, required this.networkService});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Flutter API Architecture',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        useMaterial3: true,
      ),
      home: HomePage(network: networkService),
    );
  }
}

class HomePage extends StatefulWidget {
  final INetworkService network;
  const HomePage({super.key, required this.network});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  List<dynamic> posts = [];
  bool isLoading = false;
  String errorMessage = "";

  // PARALEL SORGÜ TESTİ: Birden fazla endpoint'ten aynı anda veri çekme
  Future<void> handleParallelFetch() async {
    setState(() {
      isLoading = true;
      errorMessage = "";
    });

    try {
      // 'buildJsonApiRoutes' mantığıyla paralel istek atıyoruz
      final results = await widget.network.fetchParallel([
        'posts/1',
        'posts/2',
        'posts/3',
      ]);

      setState(() {
        posts = results;
        isLoading = false;
      });
    } catch (e) {
      setState(() {
        errorMessage = e.toString();
        isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("OpenEMS Architecture"),
        backgroundColor: Colors.blueGrey[50],
      ),
      body: Center(
        child: isLoading
            ? const CircularProgressIndicator()
            : errorMessage.isNotEmpty
            ? Text("Hata: $errorMessage", style: const TextStyle(color: Colors.red))
            : posts.isEmpty
            ? const Text("Veri çekmek için butona basın")
            : ListView.builder(
          itemCount: posts.length,
          shrinkWrap: true,
          itemBuilder: (context, index) {
            return ListTile(
              leading: CircleAvatar(child: Text("${index + 1}")),
              title: Text(posts[index]['title']),
              subtitle: const Text("API'den paralel geldi"),
            );
          },
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: handleParallelFetch,
        label: const Text("Paralel Veri Çek"),
        icon: const Icon(Icons.cloud_download),
      ),
    );
  }
}
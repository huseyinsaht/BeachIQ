import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../domain/interfaces/i_network_service.dart';

class NetworkService extends INetworkService {
  String? _authToken;

  NetworkService(super.baseUrl);

  @override
  void setToken(String token) {
    _authToken = token;
  }

  // Yardımcı metod: Header'ları merkezi olarak yönetir
  Map<String, String> _getHeaders() {
    final headers = {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };

    // Eğer token varsa header'a ekle (Bearer Token standardı)
    if (_authToken != null) {
      headers['Authorization'] = 'Bearer $_authToken';
      // Not: Bazı sistemler 'x-auth-token' veya direkt 'token' bekleyebilir.
    }
    return headers;
  }

  @override
  Future<dynamic> get(String path) async {
    final response = await http.get(
      Uri.parse('$baseUrl/$path'),
      headers: _getHeaders(), // Otomatik ekleniyor
    );
    return _processResponse(response);
  }

  @override
  Future<dynamic> post(String path, {required Map<String, dynamic> body}) async {
    final response = await http.post(
      Uri.parse('$baseUrl/$path'),
      headers: _getHeaders(),
      body: jsonEncode(body),
    );
    return _processResponse(response);
  }

  // ... fetchParallel metodun aynı kalabilir, çünkü get'i çağırıyor ...

  dynamic _processResponse(http.Response response) {
    if (response.statusCode == 401) {
      // OpenEMS'ten 401 Unauthorized dönerse burası tetiklenir
      throw Exception("Yetkisiz Erişim! Lütfen giriş yapın.");
    }
    // Diğer kontroller...
    return jsonDecode(response.body);
  }
// lib/data/services/network_service.dart içinde...

  @override
  Future<List<dynamic>> fetchParallel(List<String> paths) async {
    // Tüm path'leri Future listesine map ediyoruz
    // Her biri kendi içinde _getHeaders() kullanarak güvenli istek atacak
    final List<Future<dynamic>> requests = paths.map((path) => get(path)).toList();

    try {
      // Hepsi paralel olarak başlar, en uzunu bitince sonuç döner
      return await Future.wait(requests);
    } catch (e) {
      throw Exception("Paralel sorgu sırasında hata: $e");
    }
  }

}
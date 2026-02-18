abstract class INetworkService {
  final String baseUrl;
  // Auth token'ı burada tutabiliriz veya bir 'TokenManager'dan çekebiliriz
  String? _token;

  INetworkService(this.baseUrl);

  // Token'ı dışarıdan set etmek için (Login başarılı olduğunda)
  void setToken(String token);

  Future<dynamic> get(String path);
  Future<dynamic> post(String path, {required Map<String, dynamic> body});
  Future<List<dynamic>> fetchParallel(List<String> paths);

}


abstract class IStorageService {
  Future<void> saveString(String key, String value);
  Future<String?> getString(String key);
  Future<void> remove(String key);
}
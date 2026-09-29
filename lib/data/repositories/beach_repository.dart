import 'package:beachiq/data/models/beach.dart';
import 'package:beachiq/data/static_beaches.dart';

/// Returns the static beach list for now — makes it easy to swap in a
/// real API later without changing the callers of this repository.
class BeachRepository {
  Future<List<Beach>> getBeaches() async {
    return staticBeaches;
  }
}

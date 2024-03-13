import 'package:shared_preferences/shared_preferences.dart';

class PreferencesManager {
  Future<bool> useHashCache() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    return prefs.getBool('use_hash_cache') ?? true;
  }

  Future setUseHashCache(bool value) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    prefs.setBool('use_hash_cache', value);
  }
}

import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/keyword_config.dart';

class SettingsService {
  static const _key = 'keyword_config';
  static SettingsService? _instance;
  late SharedPreferences _prefs;
  KeywordConfig _config = KeywordConfig.defaults;

  SettingsService._();

  static Future<SettingsService> getInstance() async {
    if (_instance == null) {
      _instance = SettingsService._();
      await _instance!._init();
    }
    return _instance!;
  }

  Future<void> _init() async {
    _prefs = await SharedPreferences.getInstance();
    final stored = _prefs.getString(_key);
    if (stored != null) {
      try {
        _config = KeywordConfig.fromJson(jsonDecode(stored));
      } catch (_) {
        _config = KeywordConfig.defaults;
      }
    }
  }

  KeywordConfig get config => _config;

  Future<void> saveConfig(KeywordConfig config) async {
    _config = config;
    await _prefs.setString(_key, jsonEncode(config.toJson()));
  }

  Future<void> resetToDefaults() async {
    await saveConfig(KeywordConfig.defaults);
  }
}

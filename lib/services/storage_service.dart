import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/book.dart';
import '../models/settings_model.dart';

class StorageService {
  static const String _keySettings = 'cornigrum_settings';
  static const String _keyBooks = 'cornigrum_books';
  static const String _keyAnalytics = 'cornigrum_analytics';

  final SharedPreferences _prefs;

  StorageService(this._prefs);

  static Future<StorageService> init() async {
    final prefs = await SharedPreferences.getInstance();
    return StorageService(prefs);
  }

  // ─── Settings ─────────────────────────────────────────────
  Future<void> saveSettings(SettingsModel settings) async {
    await _prefs.setString(_keySettings, jsonEncode(settings.toJson()));
  }

  SettingsModel loadSettings() {
    final jsonStr = _prefs.getString(_keySettings);
    if (jsonStr == null) return const SettingsModel();
    try {
      return SettingsModel.fromJson(jsonDecode(jsonStr));
    } catch (_) {
      return const SettingsModel();
    }
  }

  // ─── Books Library ─────────────────────────────────────────
  Future<void> saveBooks(List<Book> books) async {
    final list = books.map((b) => b.toJson()).toList();
    await _prefs.setString(_keyBooks, jsonEncode(list));
  }

  List<Book> loadBooks() {
    final jsonStr = _prefs.getString(_keyBooks);
    if (jsonStr == null) return [];
    try {
      final list = jsonDecode(jsonStr) as List;
      return list.map((item) => Book.fromJson(item)).toList();
    } catch (_) {
      return [];
    }
  }

  // ─── Analytics Data ───────────────────────────────────────
  Future<void> saveAnalytics(Map<String, dynamic> data) async {
    await _prefs.setString(_keyAnalytics, jsonEncode(data));
  }

  Map<String, dynamic> loadAnalytics() {
    final jsonStr = _prefs.getString(_keyAnalytics);
    if (jsonStr == null) return {};
    try {
      return jsonDecode(jsonStr) as Map<String, dynamic>;
    } catch (_) {
      return {};
    }
  }
}

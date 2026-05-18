import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsService extends ChangeNotifier {
  static const String _keyLoadWhilePlaying = 'load_while_playing';
  static const String _keyConcurrentDownloads = 'concurrent_downloads';
  static const String _keySkipDuration = 'skip_duration';
  static const String _keyAutoUpdateInterval = 'auto_update_interval';
  static const String _keyNotesDisplayDuration = 'notes_display_duration';
  static const String _keyExplanationDisplayDuration = 'explanation_display_duration';
  static const String _keyPinLastSubject = 'pin_last_subject';
  static const String _keyShowMySolutions = 'show_my_solutions';
  static const String _keyTextSize = 'text_size';

  final SharedPreferences _prefs;

  SettingsService(this._prefs);

  bool get loadWhilePlaying => _prefs.getBool(_keyLoadWhilePlaying) ?? false;
  int get concurrentDownloads => _prefs.getInt(_keyConcurrentDownloads) ?? 1;
  int get skipDuration => _prefs.getInt(_keySkipDuration) ?? 10;
  int get autoUpdateInterval => _prefs.getInt(_keyAutoUpdateInterval) ?? 10;
  int get notesDisplayDuration => _prefs.getInt(_keyNotesDisplayDuration) ?? 5;
  int get explanationDisplayDuration => _prefs.getInt(_keyExplanationDisplayDuration) ?? 5;
  bool get pinLastSubject => _prefs.getBool(_keyPinLastSubject) ?? false;
  bool get showMySolutions => _prefs.getBool(_keyShowMySolutions) ?? true;
  String get textSize => _prefs.getString(_keyTextSize) ?? 'default';

  Future<void> setLoadWhilePlaying(bool value) async {
    await _prefs.setBool(_keyLoadWhilePlaying, value);
    notifyListeners();
  }

  Future<void> setConcurrentDownloads(int value) async {
    await _prefs.setInt(_keyConcurrentDownloads, value);
    notifyListeners();
  }

  Future<void> setSkipDuration(int value) async {
    await _prefs.setInt(_keySkipDuration, value);
    notifyListeners();
  }

  Future<void> setAutoUpdateInterval(int value) async {
    await _prefs.setInt(_keyAutoUpdateInterval, value);
    notifyListeners();
  }

  Future<void> setNotesDisplayDuration(int value) async {
    await _prefs.setInt(_keyNotesDisplayDuration, value);
    notifyListeners();
  }

  Future<void> setExplanationDisplayDuration(int value) async {
    await _prefs.setInt(_keyExplanationDisplayDuration, value);
    notifyListeners();
  }

  Future<void> setPinLastSubject(bool value) async {
    await _prefs.setBool(_keyPinLastSubject, value);
    notifyListeners();
  }

  Future<void> setShowMySolutions(bool value) async {
    await _prefs.setBool(_keyShowMySolutions, value);
    notifyListeners();
  }

  Future<void> setTextSize(String value) async {
    await _prefs.setString(_keyTextSize, value);
    notifyListeners();
  }
}

import 'package:flutter/foundation.dart';
import '../services/nurtura_api.dart';

class AppProvider extends ChangeNotifier {
  AppProvider({NurturaApi? api}) : _api = api ?? NurturaApi();

  final NurturaApi _api;

  int? userId;
  Map<String, dynamic>? user;
  Map<String, dynamic>? home;
  bool loading = false;
  String? error;
  bool apiConnected = false;

  Future<void> init() async {
    await checkHealth();
    if (userId != null) {
      await loadUserData();
    }
  }

  Future<void> checkHealth() async {
    try {
      await _api.health();
      apiConnected = true;
      error = null;
    } catch (e) {
      apiConnected = false;
      error = 'API not reachable. Start the server: cd api && npm start';
    }
    notifyListeners();
  }

  Future<void> loadUserData() async {
    if (userId == null) return;
    loading = true;
    notifyListeners();
    try {
      user = await _api.getUser(userId!);
      home = await _api.getHome(userId!);
      error = null;
    } catch (e) {
      error = e.toString();
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  Future<bool> register({
    required String name,
    String? dueDate,
    int pregnancyWeek = 24,
    String preferredLanguage = 'English',
  }) async {
    loading = true;
    notifyListeners();
    try {
      final result = await _api.registerUser(
        name: name,
        dueDate: dueDate,
        pregnancyWeek: pregnancyWeek,
        preferredLanguage: preferredLanguage,
      );
      userId = result['id'] as int;
      user = result;
      await loadUserData();
      return true;
    } catch (e) {
      error = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<void> loginDemo() async {
    loading = true;
    notifyListeners();
    try {
      userId = 1;
      await loadUserData();
    } catch (e) {
      error = e.toString();
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  Future<void> logout() async {
    userId = null;
    user = null;
    home = null;
    notifyListeners();
  }
}

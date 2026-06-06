import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';

class NurturaApi {
  NurturaApi({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;
  final String _base = ApiConfig.baseUrl;
  static const _timeout = Duration(seconds: 8);
  static const _chatTimeout = Duration(seconds: 60);

  Future<http.Response> _get(Uri uri) =>
      _client.get(uri, headers: _headers).timeout(_timeout);

  Future<http.Response> _post(Uri uri, {required String body}) =>
      _client.post(uri, headers: _headers, body: body).timeout(_timeout);

  Future<http.Response> _put(Uri uri, {required String body}) =>
      _client.put(uri, headers: _headers, body: body).timeout(_timeout);

  Future<Map<String, dynamic>> health() async {
    final res = await _get(Uri.parse('$_base/health'));
    return _decode(res);
  }

  Future<Map<String, dynamic>> registerUser({
    required String name,
    String? dueDate,
    int pregnancyWeek = 24,
    String preferredLanguage = 'English',
    bool disclaimerAccepted = true,
  }) async {
    final res = await _post(
      Uri.parse('$_base/users/register'),
      body: jsonEncode({
        'name': name,
        'dueDate': dueDate,
        'pregnancyWeek': pregnancyWeek,
        'preferredLanguage': preferredLanguage,
        'disclaimerAccepted': disclaimerAccepted,
      }),
    );
    return _decode(res);
  }

  Future<Map<String, dynamic>> getUser(int id) async {
    final res = await _get(Uri.parse('$_base/users/$id'));
    return _decode(res);
  }

  Future<Map<String, dynamic>> getHome(int userId) async {
    final res = await _get(Uri.parse('$_base/home/$userId'));
    return _decode(res);
  }

  Future<Map<String, dynamic>> getPregnancyWeek(int week) async {
    final res = await _get(Uri.parse('$_base/pregnancy/weeks/$week'));
    return _decode(res);
  }

  Future<List<int>> getPregnancyWeeks() async {
    final res = await _get(Uri.parse('$_base/pregnancy/weeks'));
    final data = _decodeList(res);
    return data.map((e) => e as int).toList();
  }

  Future<List<Map<String, dynamic>>> getDietCategories() async {
    final res = await _get(Uri.parse('$_base/diet/categories'));
    return _decodeList(res).cast<Map<String, dynamic>>();
  }

  Future<Map<String, dynamic>> getDietFoods() async {
    final res = await _get(Uri.parse('$_base/diet/foods'));
    return _decode(res);
  }

  Future<Map<String, dynamic>> getWater(int userId) async {
    final res = await _get(Uri.parse('$_base/diet/water/$userId'));
    return _decode(res);
  }

  Future<Map<String, dynamic>> updateWater(int userId, int glasses) async {
    final res = await _put(
      Uri.parse('$_base/diet/water/$userId'),
      body: jsonEncode({'glasses': glasses}),
    );
    return _decode(res);
  }

  Future<List<Map<String, dynamic>>> getEmergencySymptoms() async {
    final res = await _get(Uri.parse('$_base/emergency/symptoms'));
    return _decodeList(res).cast<Map<String, dynamic>>();
  }

  Future<List<Map<String, dynamic>>> getAppointments(int userId, {bool? upcoming}) async {
    var url = '$_base/appointments/$userId';
    if (upcoming != null) url += '?upcoming=$upcoming';
    final res = await _get(Uri.parse(url));
    return _decodeList(res).cast<Map<String, dynamic>>();
  }

  Future<Map<String, dynamic>> addAppointment(
    int userId, {
    required String title,
    required String date,
    required String time,
    required String doctorName,
  }) async {
    final res = await _post(
      Uri.parse('$_base/appointments/$userId'),
      body: jsonEncode({
        'title': title,
        'date': date,
        'time': time,
        'doctorName': doctorName,
      }),
    );
    return _decode(res);
  }

  Future<List<String>> getChatPrompts() async {
    final res = await _get(Uri.parse('$_base/chat/prompts'));
    return _decodeList(res).cast<String>();
  }

  Future<List<Map<String, dynamic>>> getChatThreads(int userId) async {
    final res = await _get(Uri.parse('$_base/chat/$userId/threads'));
    return _decodeList(res).cast<Map<String, dynamic>>();
  }

  Future<Map<String, dynamic>> createChatThread(int userId, {String title = 'New chat'}) async {
    final res = await _post(
      Uri.parse('$_base/chat/$userId/threads'),
      body: jsonEncode({'title': title}),
    );
    return _decode(res);
  }

  Future<void> deleteChatThread(int userId, int threadId) async {
    final res = await _client
        .delete(
          Uri.parse('$_base/chat/$userId/threads/$threadId'),
          headers: _headers,
        )
        .timeout(_timeout);
    if (res.statusCode >= 400) {
      throw ApiException(_errorFromResponse(res));
    }
  }

  Future<List<Map<String, dynamic>>> getChatMessages(int userId, int threadId) async {
    final res = await _get(Uri.parse('$_base/chat/$userId/threads/$threadId/messages'));
    return _decodeList(res).cast<Map<String, dynamic>>();
  }

  Future<Map<String, dynamic>> sendChatMessage(int userId, int threadId, String message) async {
    final res = await _post(
      Uri.parse('$_base/chat/$userId/threads/$threadId'),
      body: jsonEncode({'message': message}),
    ).timeout(_chatTimeout);
    return _decode(res);
  }

  Stream<ChatStreamEvent> streamChatMessage(int userId, int threadId, String message) async* {
    final request = http.Request('POST', Uri.parse('$_base/chat/$userId/threads/$threadId/stream'));
    request.headers.addAll(_headers);
    request.body = jsonEncode({'message': message});

    final response = await _client.send(request).timeout(_chatTimeout);
    if (response.statusCode >= 400) {
      final body = await response.stream.bytesToString();
      if (body.trimLeft().startsWith('<')) {
        throw ApiException(
          'API returned HTML instead of JSON. Restart the backend: cd api && npm start',
        );
      }
      try {
        final decoded = jsonDecode(body) as Map<String, dynamic>;
        throw ApiException(decoded['error']?.toString() ?? 'Chat request failed');
      } catch (e) {
        if (e is ApiException) rethrow;
        throw ApiException('Chat request failed (${response.statusCode})');
      }
    }

    var buffer = '';
    await for (final chunk in response.stream.transform(utf8.decoder)) {
      buffer += chunk;
      while (buffer.contains('\n\n')) {
        final split = buffer.indexOf('\n\n');
        final block = buffer.substring(0, split);
        buffer = buffer.substring(split + 2);
        for (final line in block.split('\n')) {
          if (!line.startsWith('data: ')) continue;
          final data = jsonDecode(line.substring(6)) as Map<String, dynamic>;
          yield ChatStreamEvent.fromJson(data);
        }
      }
    }
  }

  Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      };

  dynamic _parseBody(http.Response res) {
    final body = res.body.trim();
    if (body.isEmpty) return null;
    if (body.startsWith('<!DOCTYPE') || body.startsWith('<html') || body.startsWith('<')) {
      throw ApiException(
        'API returned HTML instead of JSON. Restart the backend: cd api && npm start',
      );
    }
    try {
      return jsonDecode(body);
    } on FormatException catch (e) {
      throw ApiException('Invalid API response: ${e.message}');
    }
  }

  String _errorFromResponse(http.Response res) {
    try {
      final body = _parseBody(res);
      if (body is Map && body['error'] != null) {
        return body['error'].toString();
      }
    } catch (e) {
      if (e is ApiException) return e.message;
    }
    if (res.statusCode == 404) {
      return 'API endpoint not found. Restart the backend: cd api && npm start';
    }
    return 'Request failed (${res.statusCode})';
  }

  Map<String, dynamic> _decode(http.Response res) {
    if (res.statusCode >= 400) {
      throw ApiException(_errorFromResponse(res));
    }
    final body = _parseBody(res);
    if (body is! Map<String, dynamic>) {
      throw ApiException('Unexpected API response format');
    }
    return body;
  }

  List<dynamic> _decodeList(http.Response res) {
    if (res.statusCode >= 400) {
      throw ApiException(_errorFromResponse(res));
    }
    final body = _parseBody(res);
    if (body is! List<dynamic>) {
      throw ApiException('Unexpected API response format');
    }
    return body;
  }
}

class ApiException implements Exception {
  ApiException(this.message);
  final String message;

  @override
  String toString() => message;
}

class ChatStreamEvent {
  ChatStreamEvent({
    this.userMessage,
    this.delta,
    this.aiMessage,
    this.error,
    this.done = false,
  });

  final String? userMessage;
  final String? delta;
  final Map<String, dynamic>? aiMessage;
  final String? error;
  final bool done;

  factory ChatStreamEvent.fromJson(Map<String, dynamic> json) {
    return ChatStreamEvent(
      userMessage: json['userMessage'] as String?,
      delta: json['delta'] as String?,
      aiMessage: json['aiMessage'] as Map<String, dynamic>?,
      error: json['error'] as String?,
      done: json['done'] == true,
    );
  }
}

import 'dart:convert';
import 'dart:io';
import '../../../core/api_config.dart';
import '../domain/wa_user_model.dart';

class WaUserRepository {
  Future<List<WaUser>> fetchUsers() async {
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 10);
    try {
      final uri = Uri.parse('${ApiConfig.apiUrl}?action=users');
      final req = await client.getUrl(uri);
      final resp = await req.close();
      final body = await resp.transform(utf8.decoder).join();
      final decoded = jsonDecode(body) as Map<String, dynamic>;
      if (decoded['ok'] == true) {
        return _parseUsers(decoded['allowed_users']);
      }
      throw Exception(decoded['error'] ?? 'Gagal memuat daftar nomor WA.');
    } finally {
      client.close();
    }
  }

  Future<List<WaUser>> addUser({
    required String name,
    required String phone,
  }) async {
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 12);
    try {
      final uri = Uri.parse('${ApiConfig.apiUrl}?action=add_user');
      final req = await client.postUrl(uri);
      req.headers.contentType = ContentType.json;
      req.write(jsonEncode({'name': name, 'phone': phone}));
      final resp = await req.close();
      final body = await resp.transform(utf8.decoder).join();
      final decoded = jsonDecode(body) as Map<String, dynamic>;
      if (decoded['ok'] == true) {
        return _parseUsers(decoded['allowed_users']);
      }
      throw Exception(decoded['error'] ?? 'Gagal menambahkan nomor WA.');
    } finally {
      client.close();
    }
  }

  Future<List<WaUser>> toggleUser(int id) async {
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 12);
    try {
      final uri = Uri.parse('${ApiConfig.apiUrl}?action=toggle_user&id=$id');
      final req = await client.postUrl(uri);
      final resp = await req.close();
      final body = await resp.transform(utf8.decoder).join();
      final decoded = jsonDecode(body) as Map<String, dynamic>;
      if (decoded['ok'] == true) {
        return _parseUsers(decoded['allowed_users']);
      }
      throw Exception(decoded['error'] ?? 'Gagal mengubah status nomor WA.');
    } finally {
      client.close();
    }
  }

  Future<List<WaUser>> deleteUser(int id) async {
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 12);
    try {
      final uri = Uri.parse('${ApiConfig.apiUrl}?action=delete_user&id=$id');
      final req = await client.postUrl(uri);
      final resp = await req.close();
      final body = await resp.transform(utf8.decoder).join();
      final decoded = jsonDecode(body) as Map<String, dynamic>;
      if (decoded['ok'] == true) {
        return _parseUsers(decoded['allowed_users']);
      }
      throw Exception(decoded['error'] ?? 'Gagal menghapus nomor WA.');
    } finally {
      client.close();
    }
  }

  List<WaUser> _parseUsers(dynamic raw) {
    final list = raw as List<dynamic>? ?? [];
    return list
        .map((e) => WaUser.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }
}

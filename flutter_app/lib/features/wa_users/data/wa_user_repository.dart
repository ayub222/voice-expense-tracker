import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../../core/api_config.dart';
import '../domain/wa_user_model.dart';

class WaUserRepository {
  Future<List<WaUser>> fetchUsers() async {
    final uri = Uri.parse('${ApiConfig.apiUrl}?action=users');
    final resp = await http.get(uri).timeout(const Duration(seconds: 12));
    final decoded = jsonDecode(resp.body) as Map<String, dynamic>;
    if (decoded['ok'] == true) {
      return _parseUsers(decoded['allowed_users']);
    }
    throw Exception(decoded['error'] ?? 'Gagal memuat daftar nomor WA.');
  }

  Future<List<WaUser>> addUser({
    required String name,
    required String phone,
  }) async {
    final uri = Uri.parse('${ApiConfig.apiUrl}?action=add_user');
    final resp = await http
        .post(
          uri,
          headers: const {'Content-Type': 'application/json'},
          body: jsonEncode({'name': name, 'phone': phone}),
        )
        .timeout(const Duration(seconds: 15));
    final decoded = jsonDecode(resp.body) as Map<String, dynamic>;
    if (decoded['ok'] == true) {
      return _parseUsers(decoded['allowed_users']);
    }
    throw Exception(decoded['error'] ?? 'Gagal menambahkan nomor WA.');
  }

  Future<List<WaUser>> toggleUser(int id) async {
    final uri = Uri.parse('${ApiConfig.apiUrl}?action=toggle_user&id=$id');
    final resp = await http.post(uri).timeout(const Duration(seconds: 15));
    final decoded = jsonDecode(resp.body) as Map<String, dynamic>;
    if (decoded['ok'] == true) {
      return _parseUsers(decoded['allowed_users']);
    }
    throw Exception(decoded['error'] ?? 'Gagal mengubah status nomor WA.');
  }

  Future<List<WaUser>> deleteUser(int id) async {
    final uri = Uri.parse('${ApiConfig.apiUrl}?action=delete_user&id=$id');
    final resp = await http.post(uri).timeout(const Duration(seconds: 15));
    final decoded = jsonDecode(resp.body) as Map<String, dynamic>;
    if (decoded['ok'] == true) {
      return _parseUsers(decoded['allowed_users']);
    }
    throw Exception(decoded['error'] ?? 'Gagal menghapus nomor WA.');
  }

  List<WaUser> _parseUsers(dynamic raw) {
    final list = raw as List<dynamic>? ?? [];
    return list
        .map((e) => WaUser.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }
}

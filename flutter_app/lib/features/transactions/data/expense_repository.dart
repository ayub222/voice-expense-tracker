import 'dart:convert';
import 'dart:io';
import '../../../core/api_config.dart';
import '../domain/expense_models.dart';

class ExpenseRepository {
  Future<FinancialSummary> fetchSummary() async {
    final client = HttpClient();
    client.connectionTimeout = const Duration(seconds: 8);
    try {
      final uri = Uri.parse('${ApiConfig.apiUrl}?action=summary');
      final req = await client.getUrl(uri);
      final resp = await req.close();
      final body = await resp.transform(utf8.decoder).join();
      final decoded = jsonDecode(body) as Map<String, dynamic>;
      if (decoded['ok'] == true && decoded['data'] is Map) {
        return FinancialSummary.fromJson(
          Map<String, dynamic>.from(decoded['data'] as Map),
        );
      }
      throw Exception(decoded['error'] ?? 'Gagal memuat data.');
    } finally {
      client.close();
    }
  }

  Future<Map<String, dynamic>> submitSmartEntry(String text) async {
    final client = HttpClient();
    client.connectionTimeout = const Duration(seconds: 15);
    try {
      final uri = Uri.parse('${ApiConfig.apiUrl}?action=smart_entry');
      final req = await client.postUrl(uri);
      req.headers.contentType = ContentType.json;
      req.write(jsonEncode({
        'text': text,
        'source': 'flutter',
        'phone': '0895374884648',
      }));
      final resp = await req.close();
      final body = await resp.transform(utf8.decoder).join();
      return jsonDecode(body) as Map<String, dynamic>;
    } finally {
      client.close();
    }
  }

  Future<FinancialSummary> deleteTransaction(int id) async {
    final client = HttpClient();
    try {
      final uri = Uri.parse('${ApiConfig.apiUrl}?action=delete&id=$id');
      final req = await client.postUrl(uri);
      final resp = await req.close();
      final body = await resp.transform(utf8.decoder).join();
      final decoded = jsonDecode(body) as Map<String, dynamic>;
      if (decoded['ok'] == true && decoded['summary'] is Map) {
        return FinancialSummary.fromJson(
          Map<String, dynamic>.from(decoded['summary'] as Map),
        );
      }
      return fetchSummary();
    } finally {
      client.close();
    }
  }
}

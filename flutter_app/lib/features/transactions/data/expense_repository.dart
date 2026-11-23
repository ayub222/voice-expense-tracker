import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../../core/api_config.dart';
import '../domain/expense_models.dart';

class ExpenseRepository {
  Future<FinancialSummary> fetchSummary() async {
    final uri = Uri.parse('${ApiConfig.apiUrl}?action=summary');
    final resp = await http.get(uri).timeout(const Duration(seconds: 12));
    final decoded = jsonDecode(resp.body) as Map<String, dynamic>;
    if (decoded['ok'] == true && decoded['data'] is Map) {
      return FinancialSummary.fromJson(
        Map<String, dynamic>.from(decoded['data'] as Map),
      );
    }
    throw Exception(decoded['error'] ?? 'Gagal memuat data.');
  }

  Future<Map<String, dynamic>> submitSmartEntry(String text) async {
    final uri = Uri.parse('${ApiConfig.apiUrl}?action=smart_entry');
    final resp = await http
        .post(
          uri,
          headers: const {'Content-Type': 'application/json'},
          body: jsonEncode({
            'text': text,
            'source': 'flutter',
            'phone': '0895374884648',
          }),
        )
        .timeout(const Duration(seconds: 20));
    return jsonDecode(resp.body) as Map<String, dynamic>;
  }

  Future<FinancialSummary> deleteTransaction(int id) async {
    final uri = Uri.parse('${ApiConfig.apiUrl}?action=delete&id=$id');
    final resp = await http.post(uri).timeout(const Duration(seconds: 12));
    final decoded = jsonDecode(resp.body) as Map<String, dynamic>;
    if (decoded['ok'] == true && decoded['summary'] is Map) {
      return FinancialSummary.fromJson(
        Map<String, dynamic>.from(decoded['summary'] as Map),
      );
    }
    return fetchSummary();
  }
}

import 'package:flutter/material.dart';
import '../../../core/api_config.dart';
import '../data/expense_repository.dart';
import '../domain/expense_models.dart';

class ExpenseDashboardPage extends StatefulWidget {
  const ExpenseDashboardPage({super.key});

  @override
  State<ExpenseDashboardPage> createState() => _ExpenseDashboardPageState();
}

class _ExpenseDashboardPageState extends State<ExpenseDashboardPage> {
  final ExpenseRepository _repo = ExpenseRepository();
  final TextEditingController _inputCtrl = TextEditingController();

  FinancialSummary _summary = FinancialSummary.empty();
  bool _loading = false;
  bool _submitting = false;
  String? _statusMessage;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _inputCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    try {
      final data = await _repo.fetchSummary();
      if (mounted) {
        setState(() {
          _summary = data;
          _statusMessage = null;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _statusMessage = 'Info koneksi: $e');
      }
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _submitSmartText([String? preset]) async {
    final text = (preset ?? _inputCtrl.text).trim();
    if (text.isEmpty) return;

    setState(() {
      _submitting = true;
      _statusMessage = null;
    });

    try {
      final res = await _repo.submitSmartEntry(text);
      if (!mounted) return;
      if (res['ok'] == true) {
        _inputCtrl.clear();
        if (res['summary'] is Map) {
          _summary = FinancialSummary.fromJson(
            Map<String, dynamic>.from(res['summary'] as Map),
          );
        } else {
          await _loadData();
        }
        final count = (res['saved_transactions'] as List?)?.length ?? 1;
        setState(() {
          _statusMessage = '✅ Tercatat $count transaksi via AI!';
        });
      } else {
        setState(() {
          _statusMessage = (res['error'] ?? 'Gagal mencatat transaksi.').toString();
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _statusMessage = 'Gagal terhubung ke server: $e');
      }
    } finally {
      if (mounted) {
        setState(() => _submitting = false);
      }
    }
  }

  Future<void> _deleteItem(int id) async {
    try {
      final next = await _repo.deleteTransaction(id);
      if (mounted) {
        setState(() => _summary = next);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _statusMessage = 'Gagal menghapus: $e');
      }
    }
  }

  void _showServerDialog() {
    final ctrl = TextEditingController(text: ApiConfig.apiUrl);
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF171A23),
        title: const Text('Endpoint Server API', style: TextStyle(color: Colors.white)),
        content: TextField(
          controller: ctrl,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(
            hintText: 'http://192.168.1.x/voice-expense-tracker/api.php',
            hintStyle: TextStyle(color: Colors.white38),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () {
              ApiConfig.customBaseUrl = ctrl.text.trim();
              Navigator.pop(ctx);
              _loadData();
            },
            child: const Text('Simpan'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F1117),
      appBar: AppBar(
        backgroundColor: const Color(0xFF171A23),
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Voice Expense Tracker AI',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Colors.white),
            ),
            Text(
              'Ayub • WA Sync: 0895374884648',
              style: TextStyle(fontSize: 11, color: Color(0xFF5EEAD4)),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_ethernet, color: Colors.white70),
            tooltip: 'Atur URL Server',
            onPressed: _showServerDialog,
          ),
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white70),
            tooltip: 'Refresh',
            onPressed: _loadData,
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadData,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _buildSmartInputCard(),
            const SizedBox(height: 16),
            _buildSummaryGrid(),
            const SizedBox(height: 18),
            const Text(
              'Riwayat Transaksi Terbaru',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white),
            ),
            const SizedBox(height: 10),
            if (_loading && _summary.recentTransactions.isEmpty)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: CircularProgressIndicator(),
                ),
              )
            else if (_summary.recentTransactions.isEmpty)
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: const Color(0xFF171A23),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text(
                  'Belum ada transaksi. Ketik contoh kalimat pengeluaran di atas!',
                  style: TextStyle(color: Colors.white54),
                ),
              )
            else
              ..._summary.recentTransactions.map(_buildTransactionTile),
          ],
        ),
      ),
    );
  }

  Widget _buildSmartInputCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF171A23),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF5EEAD4).withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '⚡ Catat Cepat dengan AI (Suara / Teks)',
            style: TextStyle(color: Color(0xFF5EEAD4), fontWeight: FontWeight.w600, fontSize: 13),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _inputCtrl,
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                  onSubmitted: (_) => _submitSmartText(),
                  decoration: InputDecoration(
                    hintText: 'Misal: Beli bensin 30 ribu sama kopi 18 ribu',
                    hintStyle: const TextStyle(color: Colors.white38, fontSize: 13),
                    filled: true,
                    fillColor: const Color(0xFF0F1117),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF14B8A6),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: _submitting ? null : () => _submitSmartText(),
                child: Text(_submitting ? '...' : 'Catat'),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              _buildSampleChip('Beli bensin 30 ribu sama kopi 18 ribu'),
              _buildSampleChip('Makan siang 25rb & parkir 3rb'),
            ],
          ),
          if (_statusMessage != null) ...[
            const SizedBox(height: 10),
            Text(
              _statusMessage!,
              style: const TextStyle(color: Color(0xFF6EE7B7), fontSize: 12),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSampleChip(String label) {
    return InkWell(
      onTap: () {
        _inputCtrl.text = label;
        _submitSmartText(label);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          label,
          style: const TextStyle(color: Colors.white70, fontSize: 11),
        ),
      ),
    );
  }

  Widget _buildSummaryGrid() {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: 2.1,
      children: [
        _buildStatCard('Saldo Bersih', _summary.balanceFormatted, const Color(0xFF5EEAD4)),
        _buildStatCard('Hari Ini', _summary.todayExpenseFormatted, const Color(0xFFFBBF24)),
        _buildStatCard('Bulan Ini', _summary.monthExpenseFormatted, const Color(0xFFFB7185)),
        _buildStatCard('Pemasukan', _summary.totalIncomeFormatted, const Color(0xFF34D399)),
      ],
    );
  }

  Widget _buildStatCard(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF171A23),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(label, style: const TextStyle(color: Colors.white54, fontSize: 11)),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              style: TextStyle(color: color, fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTransactionTile(TransactionItem item) {
    final isIncome = item.type == 'income';
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF171A23),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Text(item.categoryIcon, style: const TextStyle(fontSize: 22)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.description,
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 14),
                ),
                Text(
                  '${item.categoryName} • ${item.transactionDate} • ${item.source.toUpperCase()}',
                  style: const TextStyle(color: Colors.white54, fontSize: 11),
                ),
              ],
            ),
          ),
          Text(
            '${isIncome ? '+' : '-'}${item.amountFormatted}',
            style: TextStyle(
              color: isIncome ? const Color(0xFF34D399) : const Color(0xFFFB7185),
              fontWeight: FontWeight.bold,
              fontSize: 13,
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, size: 16, color: Colors.white38),
            onPressed: () => _deleteItem(item.id),
          ),
        ],
      ),
    );
  }
}

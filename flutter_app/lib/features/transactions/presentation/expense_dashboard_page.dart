import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
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
  bool _isError = false;

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
    setState(() {
      _loading = true;
      _isError = false;
    });
    try {
      final data = await _repo.fetchSummary();
      if (mounted) {
        setState(() {
          _summary = data;
          _statusMessage = null;
          _isError = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _statusMessage = 'Gagal terhubung ke Vercel API: $e';
          _isError = true;
        });
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
      _isError = false;
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
          _statusMessage = 'Tercatat $count transaksi berhasil disimpan.';
          _isError = false;
        });
      } else {
        setState(() {
          _statusMessage = (res['error'] ?? 'Gagal mencatat transaksi.').toString();
          _isError = true;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _statusMessage = 'Gagal terhubung ke server: $e';
          _isError = true;
        });
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
        setState(() {
          _statusMessage = 'Gagal menghapus: $e';
          _isError = true;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return SafeArea(
      child: RefreshIndicator(
        onRefresh: _loadData,
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.md),
          children: [
            _SmartEntryCard(
              controller: _inputCtrl,
              submitting: _submitting,
              statusMessage: _statusMessage,
              isError: _isError,
              onSubmit: () => _submitSmartText(),
            ),
            const SizedBox(height: AppSpacing.md),
            _SummaryGrid(summary: _summary),
            if (_summary.byCategory.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.lg),
              Text(
                'Rekap Per Kategori',
                style: tt.titleMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: AppSpacing.sm),
              _CategoryBreakdownCard(categories: _summary.byCategory),
            ],
            const SizedBox(height: AppSpacing.lg),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Riwayat Transaksi Terbaru',
                  style: tt.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                ),
                IconButton(
                  onPressed: _loading ? null : _loadData,
                  tooltip: 'Refresh transaksi',
                  icon: const Icon(Icons.refresh),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            if (_loading && _summary.recentTransactions.isEmpty)
              const Padding(
                padding: EdgeInsets.all(AppSpacing.xl),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_isError && _summary.recentTransactions.isEmpty)
              Container(
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: cs.surfaceContainerLow,
                  borderRadius: AppRadius.lg,
                  border: Border.all(color: cs.error.withValues(alpha: 0.5)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _statusMessage ?? 'Gagal memuat transaksi.',
                      style: tt.bodyMedium?.copyWith(color: cs.error),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    FilledButton.tonalIcon(
                      onPressed: _loadData,
                      icon: const Icon(Icons.refresh),
                      label: const Text('Coba Lagi'),
                    ),
                  ],
                ),
              )
            else if (_summary.recentTransactions.isEmpty)
              Container(
                padding: const EdgeInsets.all(AppSpacing.lg),
                decoration: BoxDecoration(
                  color: cs.surfaceContainerLow,
                  borderRadius: AppRadius.lg,
                  border: Border.all(color: cs.outlineVariant),
                ),
                child: Text(
                  'Belum ada transaksi. Kirim Voice Note di WA atau ketik kalimat transaksi di atas.',
                  style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
                ),
              )
            else
              ..._summary.recentTransactions.map(
                (item) => _TransactionTile(
                  item: item,
                  onDelete: () => _deleteItem(item.id),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _SmartEntryCard extends StatelessWidget {
  final TextEditingController controller;
  final bool submitting;
  final String? statusMessage;
  final bool isError;
  final VoidCallback onSubmit;

  const _SmartEntryCard({
    required this.controller,
    required this.submitting,
    required this.statusMessage,
    required this.isError,
    required this.onSubmit,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: cs.surfaceContainerLow,
        borderRadius: AppRadius.lg,
        border: Border.all(color: cs.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.edit_note, color: cs.primary, size: 20),
              const SizedBox(width: AppSpacing.sm),
              Text(
                'Catat Transaksi',
                style: tt.titleSmall?.copyWith(
                  color: cs.primary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: controller,
                  onSubmitted: (_) => onSubmit(),
                  decoration: const InputDecoration(
                    hintText: 'Tulis transaksi, misal: Beli kopi 15rb',
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              SizedBox(
                height: 48,
                child: FilledButton(
                  onPressed: submitting ? null : onSubmit,
                  child: Text(submitting ? '...' : 'Catat'),
                ),
              ),
            ],
          ),
          if (statusMessage != null) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              statusMessage!,
              style: tt.bodySmall?.copyWith(
                color: isError ? cs.error : cs.primary,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _SummaryGrid extends StatelessWidget {
  final FinancialSummary summary;

  const _SummaryGrid({required this.summary});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: AppSpacing.sm,
      mainAxisSpacing: AppSpacing.sm,
      childAspectRatio: 2.0,
      children: [
        _StatCard(
          label: 'Saldo Bersih',
          value: summary.balanceFormatted,
          accent: cs.primary,
        ),
        _StatCard(
          label: 'Pengeluaran Hari Ini',
          value: summary.todayExpenseFormatted,
          accent: cs.error,
        ),
        _StatCard(
          label: 'Total Pemasukan',
          value: summary.totalIncomeFormatted,
          accent: cs.tertiary,
        ),
        _StatCard(
          label: 'Pengeluaran Bulan Ini',
          value: summary.monthExpenseFormatted,
          accent: cs.secondary,
        ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final Color accent;

  const _StatCard({
    required this.label,
    required this.value,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: cs.surfaceContainerLow,
        borderRadius: AppRadius.lg,
        border: Border.all(color: cs.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: tt.labelSmall?.copyWith(color: cs.onSurfaceVariant),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: tt.titleMedium?.copyWith(
              color: accent,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _CategoryBreakdownCard extends StatelessWidget {
  final List<CategorySummary> categories;

  const _CategoryBreakdownCard({required this.categories});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final maxTotal = categories.fold<double>(
      1,
      (prev, item) => item.total > prev ? item.total : prev,
    );

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: cs.surfaceContainerLow,
        borderRadius: AppRadius.lg,
        border: Border.all(color: cs.outlineVariant),
      ),
      child: Column(
        children: categories.take(5).map((cat) {
          final ratio = (cat.total / maxTotal).clamp(0.05, 1.0);
          return Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '${cat.name} (${cat.count}x)',
                      style: tt.bodySmall?.copyWith(fontWeight: FontWeight.w600),
                    ),
                    Text(
                      'Rp ${cat.total.toStringAsFixed(0)}',
                      style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                ClipRRect(
                  borderRadius: AppRadius.full,
                  child: LinearProgressIndicator(
                    value: ratio,
                    minHeight: 6,
                    backgroundColor: cs.surfaceContainerHighest,
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _TransactionTile extends StatelessWidget {
  final TransactionItem item;
  final VoidCallback onDelete;

  const _TransactionTile({
    required this.item,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final isIncome = item.type.toLowerCase() == 'income';

    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: 12,
      ),
      decoration: BoxDecoration(
        color: cs.surfaceContainerLow,
        borderRadius: AppRadius.lg,
        border: Border.all(color: cs.outlineVariant),
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: (isIncome ? cs.primary : cs.error).withValues(alpha: 0.16),
            child: Icon(
              isIncome ? Icons.arrow_downward : Icons.arrow_upward,
              color: isIncome ? cs.primary : cs.error,
              size: 18,
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.description,
                  style: tt.titleSmall?.copyWith(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 2),
                Text(
                  '${item.categoryName} • ${item.source}',
                  style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                item.amountFormatted,
                style: tt.titleSmall?.copyWith(
                  color: isIncome ? cs.primary : cs.error,
                  fontWeight: FontWeight.w700,
                ),
              ),
              if (item.transactionDate.isNotEmpty)
                Text(
                  item.transactionDate,
                  style: tt.labelSmall?.copyWith(color: cs.onSurfaceVariant),
                ),
            ],
          ),
          IconButton(
            onPressed: onDelete,
            tooltip: 'Hapus transaksi',
            icon: Icon(Icons.delete_outline, color: cs.onSurfaceVariant, size: 20),
          ),
        ],
      ),
    );
  }
}

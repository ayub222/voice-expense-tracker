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
          _statusMessage = 'Gagal terhubung ke server: $e';
          _isError = true;
        });
      }
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _submitSmartText() async {
    final text = _inputCtrl.text.trim();
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
          _statusMessage =
              (res['error'] ?? 'Gagal mencatat transaksi.').toString();
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
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: ListView(
              padding: const EdgeInsets.all(AppSpacing.md),
              children: [
                _HeroBalanceCard(summary: _summary),
                const SizedBox(height: AppSpacing.md),
                _QuickEntryCard(
                  controller: _inputCtrl,
                  submitting: _submitting,
                  statusMessage: _statusMessage,
                  isError: _isError,
                  onSubmit: _submitSmartText,
                ),
                if (_summary.byCategory.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.lg),
                  Text(
                    'Rekap Kategori',
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
                      'Riwayat Transaksi',
                      style:
                          tt.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    IconButton(
                      onPressed: _loading ? null : _loadData,
                      tooltip: 'Muat ulang',
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
                      border: Border.all(color: cs.error.withValues(alpha: 0.4)),
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
                      'Belum ada transaksi. Catat transaksi di atas atau kirim Voice Note lewat WhatsApp.',
                      style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
                    ),
                  )
                else
                  Container(
                    decoration: BoxDecoration(
                      color: cs.surfaceContainerLow,
                      borderRadius: AppRadius.lg,
                      border: Border.all(color: cs.outlineVariant),
                    ),
                    child: ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _summary.recentTransactions.length,
                      separatorBuilder: (_, __) => Divider(
                        height: 1,
                        color: cs.outlineVariant,
                      ),
                      itemBuilder: (context, index) {
                        final item = _summary.recentTransactions[index];
                        return _TransactionRow(
                          item: item,
                          onDelete: () => _deleteItem(item.id),
                        );
                      },
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _HeroBalanceCard extends StatelessWidget {
  final FinancialSummary summary;

  const _HeroBalanceCard({required this.summary});

  @override
  Widget build(BuildContext context) {
    final sem = Theme.of(context).extension<AppSemanticColors>()!;
    final tt = Theme.of(context).textTheme;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: sem.heroBg,
        borderRadius: AppRadius.lg,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Saldo Bersih',
            style: tt.labelLarge?.copyWith(
              color: sem.heroFg.withValues(alpha: 0.85),
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            summary.balanceFormatted,
            style: tt.headlineMedium?.copyWith(
              color: sem.heroFg,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Expanded(
                child: _HeroMetricPill(
                  icon: Icons.south_west_rounded,
                  label: 'Pemasukan',
                  value: summary.totalIncomeFormatted,
                  fg: sem.heroFg,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: _HeroMetricPill(
                  icon: Icons.north_east_rounded,
                  label: 'Bulan Ini',
                  value: summary.monthExpenseFormatted,
                  fg: sem.heroFg,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: _HeroMetricPill(
                  icon: Icons.today_outlined,
                  label: 'Hari Ini',
                  value: summary.todayExpenseFormatted,
                  fg: sem.heroFg,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _HeroMetricPill extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color fg;

  const _HeroMetricPill({
    required this.icon,
    required this.label,
    required this.value,
    required this.fg,
  });

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color: fg.withValues(alpha: 0.14),
        borderRadius: AppRadius.md,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 14, color: fg.withValues(alpha: 0.85)),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: tt.labelSmall?.copyWith(
                    color: fg.withValues(alpha: 0.85),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: tt.labelLarge?.copyWith(
              color: fg,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _QuickEntryCard extends StatelessWidget {
  final TextEditingController controller;
  final bool submitting;
  final String? statusMessage;
  final bool isError;
  final VoidCallback onSubmit;

  const _QuickEntryCard({
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
          Text(
            'Catat Transaksi',
            style: tt.titleSmall?.copyWith(fontWeight: FontWeight.w700),
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
              FilledButton(
                onPressed: submitting ? null : onSubmit,
                child: Text(submitting ? '...' : 'Catat'),
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
            padding: const EdgeInsets.only(bottom: 10),
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
                      style: tt.bodySmall?.copyWith(
                        color: cs.onSurfaceVariant,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: AppRadius.full,
                  child: LinearProgressIndicator(
                    value: ratio,
                    minHeight: 7,
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

class _TransactionRow extends StatelessWidget {
  final TransactionItem item;
  final VoidCallback onDelete;

  const _TransactionRow({
    required this.item,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final sem = Theme.of(context).extension<AppSemanticColors>()!;
    final tt = Theme.of(context).textTheme;
    final isIncome = item.type.toLowerCase() == 'income';
    final amountColor = isIncome ? sem.income : sem.expense;

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: 12,
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: amountColor.withValues(alpha: 0.1),
              borderRadius: AppRadius.md,
            ),
            child: Icon(
              isIncome ? Icons.south_west_rounded : Icons.north_east_rounded,
              color: amountColor,
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
                  color: amountColor,
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

class TransactionItem {
  final int id;
  final double amount;
  final String amountFormatted;
  final String type;
  final String description;
  final String categoryName;
  final String categoryIcon;
  final String source;
  final String transactionDate;

  const TransactionItem({
    required this.id,
    required this.amount,
    required this.amountFormatted,
    required this.type,
    required this.description,
    required this.categoryName,
    required this.categoryIcon,
    required this.source,
    required this.transactionDate,
  });

  factory TransactionItem.fromJson(Map<String, dynamic> json) {
    return TransactionItem(
      id: int.tryParse(json['id'].toString()) ?? 0,
      amount: double.tryParse(json['amount'].toString()) ?? 0,
      amountFormatted: (json['amount_formatted'] ?? 'Rp 0').toString(),
      type: (json['type'] ?? 'expense').toString(),
      description: (json['description'] ?? 'Transaksi').toString(),
      categoryName: (json['category_name'] ?? 'Lainnya').toString(),
      categoryIcon: (json['category_icon'] ?? '💸').toString(),
      source: (json['source'] ?? 'flutter').toString(),
      transactionDate: (json['transaction_date'] ?? '').toString(),
    );
  }
}

class CategorySummary {
  final String name;
  final String icon;
  final double total;
  final int count;

  const CategorySummary({
    required this.name,
    required this.icon,
    required this.total,
    required this.count,
  });

  factory CategorySummary.fromJson(Map<String, dynamic> json) {
    return CategorySummary(
      name: (json['name'] ?? 'Lainnya').toString(),
      icon: (json['icon'] ?? '📦').toString(),
      total: double.tryParse(json['total'].toString()) ?? 0,
      count: int.tryParse(json['tx_count'].toString()) ?? 0,
    );
  }
}

class FinancialSummary {
  final String balanceFormatted;
  final String todayExpenseFormatted;
  final String monthExpenseFormatted;
  final String totalIncomeFormatted;
  final List<CategorySummary> byCategory;
  final List<TransactionItem> recentTransactions;

  const FinancialSummary({
    required this.balanceFormatted,
    required this.todayExpenseFormatted,
    required this.monthExpenseFormatted,
    required this.totalIncomeFormatted,
    required this.byCategory,
    required this.recentTransactions,
  });

  factory FinancialSummary.empty() {
    return const FinancialSummary(
      balanceFormatted: 'Rp 0',
      todayExpenseFormatted: 'Rp 0',
      monthExpenseFormatted: 'Rp 0',
      totalIncomeFormatted: 'Rp 0',
      byCategory: [],
      recentTransactions: [],
    );
  }

  factory FinancialSummary.fromJson(Map<String, dynamic> json) {
    final cats = (json['by_category'] as List<dynamic>? ?? [])
        .map((e) => CategorySummary.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
    final txs = (json['recent_transactions'] as List<dynamic>? ?? [])
        .map((e) => TransactionItem.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();

    return FinancialSummary(
      balanceFormatted: (json['balance_formatted'] ?? 'Rp 0').toString(),
      todayExpenseFormatted: (json['today_expense_formatted'] ?? 'Rp 0').toString(),
      monthExpenseFormatted: (json['month_expense_formatted'] ?? 'Rp 0').toString(),
      totalIncomeFormatted: (json['total_income_formatted'] ?? 'Rp 0').toString(),
      byCategory: cats,
      recentTransactions: txs,
    );
  }
}

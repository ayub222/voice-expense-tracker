import 'package:flutter/material.dart';
import 'features/transactions/presentation/expense_dashboard_page.dart';

void main() {
  runApp(const VoiceExpenseApp());
}

class VoiceExpenseApp extends StatelessWidget {
  const VoiceExpenseApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Voice Expense Tracker AI',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark(useMaterial3: true).copyWith(
        scaffoldBackgroundColor: const Color(0xFF0F1117),
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF14B8A6),
          brightness: Brightness.dark,
        ),
      ),
      home: const ExpenseDashboardPage(),
    );
  }
}

import 'package:flutter/material.dart';
import 'core/api_config.dart';
import 'core/theme/app_theme.dart';
import 'features/transactions/presentation/expense_dashboard_page.dart';
import 'features/wa_users/presentation/wa_bot_page.dart';

void main() {
  runApp(const VoiceExpenseApp());
}

class VoiceExpenseApp extends StatelessWidget {
  const VoiceExpenseApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Catatan Keuangan',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme(),
      home: const HomeShellPage(),
    );
  }
}

class HomeShellPage extends StatefulWidget {
  const HomeShellPage({super.key});

  @override
  State<HomeShellPage> createState() => _HomeShellPageState();
}

class _HomeShellPageState extends State<HomeShellPage> {
  void _showServerDialog() {
    final ctrl = TextEditingController(text: ApiConfig.apiUrl);
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Endpoint API Cloud'),
        content: TextField(
          controller: ctrl,
          decoration: const InputDecoration(
            labelText: 'URL api.php',
            hintText: ApiConfig.defaultProductionUrl,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              ApiConfig.customBaseUrl = '';
              Navigator.pop(ctx);
              setState(() {});
            },
            child: const Text('Reset Default'),
          ),
          FilledButton(
            onPressed: () {
              ApiConfig.customBaseUrl = ctrl.text.trim();
              Navigator.pop(ctx);
              setState(() {});
            },
            child: const Text('Simpan'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: cs.primary.withValues(alpha: 0.12),
                  borderRadius: AppRadius.md,
                ),
                child: Icon(
                  Icons.account_balance_wallet_outlined,
                  color: cs.primary,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Catatan Keuangan',
                    style: tt.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                  ),
                  Text(
                    'Sinkronisasi Cloud & WhatsApp',
                    style: tt.labelSmall?.copyWith(color: cs.onSurfaceVariant),
                  ),
                ],
              ),
            ],
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.tune),
              tooltip: 'Atur URL API',
              onPressed: _showServerDialog,
            ),
          ],
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(49),
            child: Container(
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(color: cs.outlineVariant),
                ),
              ),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 640),
                  child: const TabBar(
                    tabs: [
                      Tab(text: 'Dashboard'),
                      Tab(text: 'WA Bot'),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
        body: const TabBarView(
          children: [
            ExpenseDashboardPage(),
            WaBotPage(),
          ],
        ),
      ),
    );
  }
}

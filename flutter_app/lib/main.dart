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
      title: 'Voice Expense Tracker AI',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme(),
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
  int _index = 0;

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

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Voice Expense Tracker AI',
              style: tt.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
            Text(
              'Vercel + TiDB Cloud • WA Bot Railway',
              style: tt.labelSmall?.copyWith(color: cs.primary),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_ethernet),
            tooltip: 'Atur URL API',
            onPressed: _showServerDialog,
          ),
        ],
      ),
      body: IndexedStack(
        index: _index,
        children: const [
          ExpenseDashboardPage(),
          WaBotPage(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.dashboard_outlined),
            selectedIcon: Icon(Icons.dashboard),
            label: 'Dashboard',
          ),
          NavigationDestination(
            icon: Icon(Icons.chat_outlined),
            selectedIcon: Icon(Icons.chat),
            label: 'WA Bot',
          ),
        ],
      ),
    );
  }
}

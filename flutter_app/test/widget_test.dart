import 'package:flutter_test/flutter_test.dart';
import 'package:voice_expense_app/main.dart';

void main() {
  testWidgets('VoiceExpenseApp renders Dashboard and WA Bot tabs', (WidgetTester tester) async {
    await tester.pumpWidget(const VoiceExpenseApp());

    expect(find.text('Voice Expense Tracker AI'), findsOneWidget);
    expect(find.text('Catat'), findsOneWidget);
    expect(find.text('Dashboard'), findsOneWidget);
    expect(find.text('WA Bot'), findsOneWidget);

    await tester.tap(find.text('WA Bot'));
    await tester.pump();
    expect(find.text('Tambah Nomor WhatsApp'), findsOneWidget);
    expect(find.textContaining('0895374884648'), findsOneWidget);
  });
}

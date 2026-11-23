import 'package:flutter_test/flutter_test.dart';
import 'package:voice_expense_app/main.dart';

void main() {
  testWidgets('VoiceExpenseApp renders fintech Dashboard and WA Bot tabs', (WidgetTester tester) async {
    await tester.pumpWidget(const VoiceExpenseApp());

    expect(find.text('Catatan Keuangan'), findsOneWidget);
    expect(find.text('Saldo Bersih'), findsOneWidget);
    expect(find.text('Catat'), findsOneWidget);
    expect(find.text('Dashboard'), findsOneWidget);
    expect(find.text('WA Bot'), findsOneWidget);

    await tester.tap(find.text('WA Bot'));
    await tester.pumpAndSettle();
    expect(find.text('Tambah Nomor'), findsOneWidget);
    expect(find.textContaining('0895374884648'), findsOneWidget);
  });
}

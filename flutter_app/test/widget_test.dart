import 'package:flutter_test/flutter_test.dart';
import 'package:voice_expense_app/main.dart';

void main() {
  testWidgets('VoiceExpenseApp renders dashboard header and AI input', (WidgetTester tester) async {
    await tester.pumpWidget(const VoiceExpenseApp());
    expect(find.text('Voice Expense Tracker AI'), findsOneWidget);
    expect(find.textContaining('0895374884648'), findsOneWidget);
    expect(find.text('Catat'), findsOneWidget);
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:ancora/main.dart';

void main() {
  testWidgets('App renders without crashing', (WidgetTester tester) async {
    await tester.pumpWidget(const AncoraApp());
    expect(find.text('Ancora'), findsOneWidget);
  });
}

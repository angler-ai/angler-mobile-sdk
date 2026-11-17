import 'package:angler_example/main.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('shows the example buttons', (tester) async {
    await tester.pumpWidget(const ExampleApp());
    expect(find.text('Track product_viewed'), findsOneWidget);
    expect(find.text('Flush'), findsOneWidget);
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:campus_quicksplit/main.dart';

void main() {
  testWidgets('Campus QuickSplit smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const CampusQuickSplitApp());
  });
}
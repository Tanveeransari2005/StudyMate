
import 'package:flutter_test/flutter_test.dart';
import 'package:studymate/main.dart';

void main() {
  testWidgets('StudyMate app starts', (tester) async {
    await tester.pumpWidget(const StudyMateApp());
    await tester.pump();

    expect(find.text('StudyMate'), findsOneWidget);
  });
}

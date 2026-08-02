import 'package:flutter_test/flutter_test.dart';
import 'package:jarvis_app/main.dart';

void main() {
  testWidgets('Jarvis app boots to auth gate', (tester) async {
    await tester.pumpWidget(const JarvisApp());
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.textContaining('JARVIS'), findsWidgets);
  });
}

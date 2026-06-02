import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:vitamin_analyzer/main.dart';

void main() {
  // 初始化 sqflite ffi 用于测试
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  testWidgets('App launches smoke test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const VitaminAnalyzerApp());

    // Verify that our app title is displayed.
    expect(find.text('维生素分析仪'), findsOneWidget);
  });
}

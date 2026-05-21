import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_application_1/table_screen.dart';
import 'package:flutter_application_1/import_screen.dart';

void main() {
  setUp(() {
    // 初始化 SharedPreferences Mock 值
    SharedPreferences.setMockInitialValues({});
  });

  group('CourseParser 解析器單元測試', () {
    test('測試解析單一數字節次', () {
      const text = '9012345 計算機概論 王老師 3.0 必修 二10,11 社科院227';
      final courses = CourseParser.parse(text);
      expect(courses.length, 1);
      
      final course = courses[0];
      expect(course.title, '計算機概論');
      expect(course.subtitle, '王老師');
      expect(course.content, '社科院227');
      expect(course.dayIndex, 1); // 星期二
      expect(course.slots, [10, 11]);
      expect(course.labels, isEmpty);
    });

    test('測試解析單一字母節次', () {
      const text = '9012346 資料結構 李老師 3.0 選修 五C,D 社科院315';
      final courses = CourseParser.parse(text);
      expect(courses.length, 1);

      final course = courses[0];
      expect(course.title, '資料結構');
      expect(course.subtitle, '李老師');
      expect(course.content, '社科院315');
      expect(course.dayIndex, 4); // 星期五
      expect(course.slots, isEmpty);
      expect(course.labels, ['C', 'D']);
    });

    test('測試解析數字與字母範圍及不同格式', () {
      const text = '週一 1-3 國文 王老師 教室A\n星期四 A-C 英文 李老師 教室B';
      final courses = CourseParser.parse(text);
      expect(courses.length, 2);

      final course1 = courses[0];
      expect(course1.title, '國文');
      expect(course1.subtitle, '王老師');
      expect(course1.content, '教室A');
      expect(course1.dayIndex, 0); // 星期一
      expect(course1.slots, [1, 2, 3]);

      final course2 = courses[1];
      expect(course2.title, '英文');
      expect(course2.subtitle, '李老師');
      expect(course2.content, '教室B');
      expect(course2.dayIndex, 3); // 星期四
      expect(course2.labels, ['A', 'B', 'C']);
    });

    test('測試解析中正大學 Kiki 專屬正常開課格式', () {
      const text = '正常開課 2101020 03 210102003 微積分(二) 數學系 二10,11 共同教室大樓201';
      final courses = CourseParser.parse(text);
      expect(courses.length, 1);
      
      final course = courses[0];
      expect(course.title, '微積分(二)');
      expect(course.subtitle, '數學系');
      expect(course.content, '共同教室大樓201');
      expect(course.dayIndex, 1); // 星期二
      expect(course.slots, [10, 11]);
      expect(course.labels, isEmpty);
    });

    test('測試無效格式之字串', () {
      const text = '這是一行完全不包含時間資訊的測試文字';
      final courses = CourseParser.parse(text);
      expect(courses, isEmpty);
    });
  });



  testWidgets('測試課程時間衝突防錯與攔截機制', (WidgetTester tester) async {
    // 建立 TableScreen
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: TableScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // 1. 點擊右下角 FAB（+）新增課程
    final fab = find.byType(FloatingActionButton);
    expect(fab, findsOneWidget);
    await tester.tap(fab);
    await tester.pumpAndSettle();

    // 驗證是否彈出新增課程對話框
    expect(find.text('新增課程'), findsOneWidget);

    // 輸入課堂名稱「課程 A」
    await tester.enterText(find.widgetWithText(TextField, '課堂名稱'), '課程 A');
    await tester.pumpAndSettle();

    // 滾動對話框，讓數字節次 FilterChip 可見
    final dialogScrollable = find.descendant(
      of: find.byType(AlertDialog),
      matching: find.byType(Scrollable),
    );
    await tester.scrollUntilVisible(
      find.widgetWithText(FilterChip, '1'),
      200,
      scrollable: dialogScrollable.first,
    );
    await tester.pumpAndSettle();

    // 勾選數字節次 1
    await tester.tap(find.widgetWithText(FilterChip, '1'));
    await tester.pumpAndSettle();

    // 點擊「新增」按鈕（FilledButton）
    final addBtn = find.byType(FilledButton);
    await tester.tap(addBtn);
    await tester.pumpAndSettle();

    // 驗證對話框已關閉，且畫面上渲染了「課程 A」
    expect(find.text('新增課程'), findsNothing);
    expect(find.text('(1)課程 A'), findsOneWidget);

    // 2. 再次點擊 FAB，嘗試新增一堂有衝突的課程
    await tester.tap(fab);
    await tester.pumpAndSettle();
    expect(find.text('新增課程'), findsOneWidget);

    // 輸入課堂名稱「課程 B」
    await tester.enterText(find.widgetWithText(TextField, '課堂名稱'), '課程 B');
    await tester.pumpAndSettle();

    // 滾動對話框，讓字母節次 FilterChip 可見
    final dialogScrollable2 = find.descendant(
      of: find.byType(AlertDialog),
      matching: find.byType(Scrollable),
    );
    await tester.scrollUntilVisible(
      find.widgetWithText(FilterChip, 'A'),
      200,
      scrollable: dialogScrollable2.first,
    );
    await tester.pumpAndSettle();

    // 勾選字母節次 A（07:15 - 08:30，與數字 1 的 07:10 - 08:00 重疊）
    await tester.tap(find.widgetWithText(FilterChip, 'A'));
    await tester.pumpAndSettle();

    // 點擊「新增」按鈕（FilledButton）
    final addBtn2 = find.byType(FilledButton);
    await tester.tap(addBtn2);
    await tester.pumpAndSettle();

    // 預期彈出「時間衝突」警告對話框
    expect(find.text('時間衝突'), findsOneWidget);
    expect(find.text('該時段已安排「課程 A」，無法加入！'), findsOneWidget);

    // 點擊衝突對話框的「確定」關閉它
    final conflictDialog = find.ancestor(
      of: find.text('時間衝突'),
      matching: find.byType(AlertDialog),
    );
    await tester.tap(find.descendant(
      of: conflictDialog,
      matching: find.text('確定'),
    ));
    await tester.pumpAndSettle();

    // 驗證時間衝突對話框已消失，但新增課程對話框依然存在
    expect(find.text('時間衝突'), findsNothing);
    expect(find.text('新增課程'), findsOneWidget);

    // 點擊取消關閉對話框
    await tester.tap(find.text('取消'));
    await tester.pumpAndSettle();
    expect(find.text('新增課程'), findsNothing);
  });
}

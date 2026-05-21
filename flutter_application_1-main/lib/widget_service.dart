import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:home_widget/home_widget.dart';

class WidgetService {
  // 數字節次開始與結束時間
  static const Map<int, String> numStartTimes = {
    1: "07:10", 2: "08:10", 3: "09:10", 4: "10:10", 5: "11:10",
    6: "12:10", 7: "13:10", 8: "14:10", 9: "15:10", 10: "16:10",
    11: "17:10", 12: "18:10", 13: "19:10", 14: "20:10", 15: "21:10",
  };
  static const Map<int, String> numEndTimes = {
    1: "08:00", 2: "09:00", 3: "10:00", 4: "11:00", 5: "12:00",
    6: "13:00", 7: "14:00", 8: "15:00", 9: "16:00", 10: "17:00",
    11: "18:00", 12: "19:00", 13: "20:00", 14: "21:00", 15: "22:00",
  };

  // 字母節次開始與結束時間
  static const Map<String, String> labelStartTimes = {
    'A': "07:15", 'B': "08:45", 'C': "10:15", 'D': "11:45", 'E': "13:15",
    'F': "14:45", 'G': "16:15", 'H': "17:45", 'I': "19:15", 'J': "20:45",
  };
  static const Map<String, String> labelEndTimes = {
    'A': "08:30", 'B': "10:00", 'C': "11:30", 'D': "13:00", 'E': "14:30",
    'F': "16:00", 'G': "17:30", 'H': "19:00", 'I': "20:30", 'J': "22:00",
  };

  // 更新小工具的主方法
  static Future<void> updateWidget() async {
    final prefs = await SharedPreferences.getInstance();
    final String? data = prefs.getString('schedule');
    
    bool hasClass = false;
    String courseTitle = "";
    String courseTime = "";
    String courseRoom = "";

    if (data != null) {
      final now = DateTime.now();
      final weekday = now.weekday; // 1代表星期一，7代表星期日

      // 小工具目前只支援星期一至星期五 (1-5)
      if (weekday >= 1 && weekday <= 5) {
        final int dayIdx = weekday - 1; // 0-4 對應星期一至星期五
        final Map<String, dynamic> decoded = jsonDecode(data);
        
        if (decoded.containsKey(dayIdx.toString())) {
          final romanMap = decoded[dayIdx.toString()] as Map<String, dynamic>;
          List<_TempCourse> todayCourses = [];

          romanMap.forEach((romanKey, courseList) {
            for (var item in (courseList as List)) {
              final title = item['title'] ?? '';
              final content = item['content'] ?? ''; // 教室
              final List<int> slots = List<int>.from(item['slots'] ?? []);
              final List<String> labels = List<String>.from(item['labels'] ?? []);

              if (title.isNotEmpty) {
                // 計算這堂課的最早開始時間與最晚結束時間
                DateTime? startTime;
                DateTime? endTime;

                // 處理數字節次
                for (int slot in slots) {
                  if (numStartTimes.containsKey(slot)) {
                    final startDt = _parseTime(now, numStartTimes[slot]!);
                    final endDt = _parseTime(now, numEndTimes[slot]!);
                    if (startTime == null || startDt.isBefore(startTime)) startTime = startDt;
                    if (endTime == null || endDt.isAfter(endTime)) endTime = endDt;
                  }
                }

                // 處理字母節次
                for (String label in labels) {
                  if (labelStartTimes.containsKey(label)) {
                    final startDt = _parseTime(now, labelStartTimes[label]!);
                    final endDt = _parseTime(now, labelEndTimes[label]!);
                    if (startTime == null || startDt.isBefore(startTime)) startTime = startDt;
                    if (endTime == null || endDt.isAfter(endTime)) endTime = endDt;
                  }
                }

                if (startTime != null && endTime != null) {
                  todayCourses.add(_TempCourse(
                    title: title,
                    room: content,
                    startTime: startTime,
                    endTime: endTime,
                  ));
                }
              }
            }
          });

          // 排序當天的課程
          todayCourses.sort((a, b) => a.startTime.compareTo(b.startTime));

          // 篩選出「正在進行中」或是「最接近且尚未開始」的課程
          _TempCourse? targetCourse;
          for (var course in todayCourses) {
            // 正在進行中：現在時間在開始與結束之間
            if (now.isAfter(course.startTime) && now.isBefore(course.endTime)) {
              targetCourse = course;
              break;
            }
            // 尚未開始：現在時間在開始之前
            if (now.isBefore(course.startTime)) {
              targetCourse = course;
              break;
            }
          }

          if (targetCourse != null) {
            hasClass = true;
            courseTitle = targetCourse.title;
            
            // 格式化時間區間顯示，例如 "09:10 - 12:00"
            final startStr = "${targetCourse.startTime.hour.toString().padLeft(2, '0')}:${targetCourse.startTime.minute.toString().padLeft(2, '0')}";
            final endStr = "${targetCourse.endTime.hour.toString().padLeft(2, '0')}:${targetCourse.endTime.minute.toString().padLeft(2, '0')}";
            courseTime = "$startStr - $endStr";
            courseRoom = targetCourse.room;
          }
        }
      }
    }

    // 將資料寫入原生小工具 SharedPreferences 儲存區
    await HomeWidget.saveWidgetData<bool>('has_class', hasClass);
    await HomeWidget.saveWidgetData<String>('course_title', courseTitle);
    await HomeWidget.saveWidgetData<String>('course_time', courseTime);
    await HomeWidget.saveWidgetData<String>('course_room', courseRoom);
    await HomeWidget.saveWidgetData<String>('empty_text', "今天的課程都完畢嘍!");

    // 觸發小工具更新
    await HomeWidget.updateWidget(
      name: 'CourseWidgetProvider',
      androidName: 'CourseWidgetProvider',
    );
  }

  static DateTime _parseTime(DateTime date, String timeStr) {
    final parts = timeStr.split(':');
    final hour = int.parse(parts[0]);
    final minute = int.parse(parts[1]);
    return DateTime(date.year, date.month, date.day, hour, minute);
  }
}

class _TempCourse {
  final String title;
  final String room;
  final DateTime startTime;
  final DateTime endTime;

  _TempCourse({
    required this.title,
    required this.room,
    required this.startTime,
    required this.endTime,
  });
}

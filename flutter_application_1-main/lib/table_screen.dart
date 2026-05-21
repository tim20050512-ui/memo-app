import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:flutter_application_1/widget_service.dart';
import 'package:flutter_application_1/import_screen.dart';

// --- 資料模型 ---
class Course {
  String title;    // 課堂名稱
  String subtitle; // 授課教師
  String content;  // 上課教室
  List<int> slots; // 數字節次 1-15
  List<String> labels; // 字母節次 A-J
  int dayIndex;    // 星期天數 (0-4 代表週一到週五，匯入使用)

  Course({
    this.title = '',
    this.subtitle = '',
    this.content = '',
    this.slots = const [],
    this.labels = const [],
    this.dayIndex = 0,
  });

  Map<String, dynamic> toJson() => {
    'title': title,
    'subtitle': subtitle,
    'content': content,
    'slots': slots,
    'labels': labels,
    'dayIndex': dayIndex,
  };

  factory Course.fromJson(Map<String, dynamic> json) => Course(
    title: json['title'] ?? '',
    subtitle: json['subtitle'] ?? '',
    content: json['content'] ?? '',
    slots: List<int>.from(json['slots'] ?? []),
    labels: List<String>.from(json['labels'] ?? []),
    dayIndex: json['dayIndex'] ?? 0,
  );
}

class _TimeInterval {
  final int start;
  final int end;
  _TimeInterval(this.start, this.end);

  bool overlapsWith(_TimeInterval other) {
    return start < other.end && other.start < end;
  }
}

class TableScreen extends StatefulWidget {
  const TableScreen({super.key});

  @override
  State<TableScreen> createState() => _TableScreenState();
}

class _TableScreenState extends State<TableScreen> {
  final List<String> _romanNumerals = ['I', 'II', 'III', 'IV', 'V'];

  int _toMin(String timeStr) {
    final parts = timeStr.split(':');
    return int.parse(parts[0]) * 60 + int.parse(parts[1]);
  }

  List<_TimeInterval> _getCourseIntervals(Course course) {
    List<_TimeInterval> intervals = [];
    for (int slot in course.slots) {
      final startStr = WidgetService.numStartTimes[slot];
      final endStr = WidgetService.numEndTimes[slot];
      if (startStr != null && endStr != null) {
        intervals.add(_TimeInterval(_toMin(startStr), _toMin(endStr)));
      }
    }
    for (String label in course.labels) {
      final startStr = WidgetService.labelStartTimes[label];
      final endStr = WidgetService.labelEndTimes[label];
      if (startStr != null && endStr != null) {
        intervals.add(_TimeInterval(_toMin(startStr), _toMin(endStr)));
      }
    }
    return intervals;
  }

  String? _checkConflict(int dayIndex, List<int> selectedSlots, List<String> selectedLabels) {
    final newCourse = Course(slots: selectedSlots, labels: selectedLabels);
    final newIntervals = _getCourseIntervals(newCourse);
    if (newIntervals.isEmpty) return null;

    final daySchedule = _schedule[dayIndex];
    if (daySchedule == null) return null;

    for (int romanIdx in daySchedule.keys) {
      final courses = daySchedule[romanIdx];
      if (courses == null) continue;

      for (var existingCourse in courses) {
        final existingIntervals = _getCourseIntervals(existingCourse);
        for (var newInt in newIntervals) {
          for (var existInt in existingIntervals) {
            if (newInt.overlapsWith(existInt)) {
              return existingCourse.title.isNotEmpty ? existingCourse.title : '未命名課程';
            }
          }
        }
      }
    }
    return null;
  }
  
  // 數字時間資料
  final List<Map<String, String>> _numTimeData = [
    {'n': '1', 't': '07:10\n08:00'}, {'n': '2', 't': '08:10\n09:00'}, {'n': '3', 't': '09:10\n10:00'},
    {'n': '4', 't': '10:10\n11:00'}, {'n': '5', 't': '11:10\n12:00'}, {'n': '6', 't': '12:10\n13:00'},
    {'n': '7', 't': '13:10\n14:00'}, {'n': '8', 't': '14:10\n15:00'}, {'n': '9', 't': '15:10\n16:00'},
    {'n': '10', 't': '16:10\n17:00'}, {'n': '11', 't': '17:10\n18:00'}, {'n': '12', 't': '18:10\n19:00'},
    {'n': '13', 't': '19:10\n20:00'}, {'n': '14', 't': '20:10\n21:00'}, {'n': '15', 't': '21:10\n22:00'},
  ];

  // 字母時間資料
  final List<Map<String, String>> _labelTimeData = [
    {'n': 'A', 't': '07:15\n08:30'}, {'n': 'B', 't': '08:45\n10:00'},
    {'n': 'C', 't': '10:15\n11:30'}, {'n': 'D', 't': '11:45\n13:00'},
    {'n': 'E', 't': '13:15\n14:30'}, {'n': 'F', 't': '14:45\n16:00'},
    {'n': 'G', 't': '16:15\n17:30'}, {'n': 'H', 't': '17:45\n19:00'},
    {'n': 'I', 't': '19:15\n20:30'}, {'n': 'J', 't': '20:45\n22:00'},
  ];

  final double headerHeight = 50.0;
  final double fixedCellWidth = 140.0; // 右側格子寬度

  // 資料結構：一個時段可以有多個課程 (List)
  late Map<int, Map<int, List<Course>>> _schedule;

  final ScrollController _headerScrollController = ScrollController();
  final ScrollController _bodyScrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _schedule = {};
    _loadSchedule();

    _bodyScrollController.addListener(() {
      if (_headerScrollController.offset != _bodyScrollController.offset) {
        _headerScrollController.jumpTo(_bodyScrollController.offset);
      }
    });
  }

  @override
  void dispose() {
    _headerScrollController.dispose();
    _bodyScrollController.dispose();
    super.dispose();
  }

  // --- 資料存取 ---
  Future<void> _loadSchedule() async {
    final prefs = await SharedPreferences.getInstance();
    final String? data = prefs.getString('schedule');
    if (data != null) {
      final Map<String, dynamic> decoded = jsonDecode(data);
      setState(() {
        _schedule = {};
        decoded.forEach((dayKey, romanMap) {
          int dayIdx = int.parse(dayKey);
          _schedule[dayIdx] = {};
          (romanMap as Map<String, dynamic>).forEach((romanKey, courseList) {
            int romanIdx = int.parse(romanKey);
            _schedule[dayIdx]![romanIdx] = (courseList as List)
                .map((item) => Course.fromJson(item))
                .toList();
          });
        });
      });
    }
  }

  Future<void> _saveSchedule() async {
    final prefs = await SharedPreferences.getInstance();
    Map<String, dynamic> encoded = {};
    _schedule.forEach((dayIdx, romanMap) {
      encoded[dayIdx.toString()] = {};
      romanMap.forEach((romanIdx, list) {
        encoded[dayIdx.toString()][romanIdx.toString()] = list.map((c) => c.toJson()).toList();
      });
    });
    await prefs.setString('schedule', jsonEncode(encoded));
    // 同步更新桌面小工具
    try {
      await WidgetService.updateWidget();
    } catch (e) {
      // 容錯機制
    }
  }

  // --- 新增課程對話框（從 FAB 觸發）---
  void _openAddCourseDialog() {
    final TextEditingController titleCtrl = TextEditingController();
    final TextEditingController subCtrl = TextEditingController();
    final TextEditingController contentCtrl = TextEditingController();
    List<int> selectedSlots = [];
    List<String> selectedLabels = [];
    int selectedDay = 0;
    int selectedRoman = 0;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          int startNum = selectedRoman * 3 + 1;
          List<String> availableLabels = 'ABCDEFGHIJ'.split('').sublist(selectedRoman * 2, selectedRoman * 2 + 2);

          return AlertDialog(
            title: const Text('新增課程'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(controller: titleCtrl, decoration: const InputDecoration(labelText: '課堂名稱')),
                  TextField(controller: subCtrl, decoration: const InputDecoration(labelText: '授課教師')),
                  TextField(controller: contentCtrl, decoration: const InputDecoration(labelText: '上課教室')),
                  const SizedBox(height: 12),
                  const Divider(),
                  const Text('星期', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Wrap(
                    spacing: 8,
                    children: List.generate(5, (i) {
                      const days = ['一', '二', '三', '四', '五'];
                      return ChoiceChip(
                        label: Text(days[i]),
                        selected: selectedDay == i,
                        onSelected: (v) => setDialogState(() => selectedDay = i),
                        selectedColor: Colors.orange[200],
                      );
                    }),
                  ),
                  const SizedBox(height: 8),
                  const Divider(),
                  const Text('區段', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Wrap(
                    spacing: 8,
                    children: List.generate(5, (i) => ChoiceChip(
                      label: Text(_romanNumerals[i]),
                      selected: selectedRoman == i,
                      onSelected: (v) => setDialogState(() {
                        selectedRoman = i;
                        selectedSlots = [];
                        selectedLabels = [];
                      }),
                      selectedColor: Colors.orange[200],
                    )),
                  ),
                  const SizedBox(height: 8),
                  const Divider(),
                  Text('數字節次（$startNum - ${startNum + 2}）', style: const TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Wrap(
                    spacing: 8,
                    children: [for (int i = startNum; i <= startNum + 2; i++) i].map((s) => FilterChip(
                      label: Text('$s'),
                      selected: selectedSlots.contains(s),
                      onSelected: (v) => setDialogState(() => v ? selectedSlots.add(s) : selectedSlots.remove(s)),
                    )).toList(),
                  ),
                  const SizedBox(height: 8),
                  const Divider(),
                  Text('字母節次（${availableLabels.join('，')}）', style: const TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Wrap(
                    spacing: 8,
                    children: availableLabels.map((l) => FilterChip(
                      label: Text(l),
                      selected: selectedLabels.contains(l),
                      onSelected: (v) => setDialogState(() => v ? selectedLabels.add(l) : selectedLabels.remove(l)),
                    )).toList(),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context), child: const Text('取消')),
              FilledButton(
                onPressed: () {
                  if (selectedSlots.isEmpty && selectedLabels.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('請至少勾選一個節次')),
                    );
                    return;
                  }
                  final conflictTitle = _checkConflict(selectedDay, selectedSlots, selectedLabels);
                  if (conflictTitle != null) {
                    showDialog(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: const Text('時間衝突'),
                        content: Text('該時段已安排「$conflictTitle」，無法加入！'),
                        actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('確定'))],
                      ),
                    );
                    return;
                  }
                  setState(() {
                    _schedule[selectedDay] ??= {};
                    _schedule[selectedDay]![selectedRoman] ??= [];
                    _schedule[selectedDay]![selectedRoman]!.add(Course(
                      title: titleCtrl.text,
                      subtitle: subCtrl.text,
                      content: contentCtrl.text,
                      slots: selectedSlots..sort(),
                      labels: selectedLabels..sort(),
                      dayIndex: selectedDay,
                    ));
                  });
                  _saveSchedule();
                  Navigator.pop(context);
                },
                style: FilledButton.styleFrom(backgroundColor: Colors.orange[800]),
                child: const Text('新增'),
              ),
            ],
          );
        },
      ),
    );
  }

  // --- 編輯既有課程對話框（點擊課程色塊觸發）---
  void _openEditCourseDialog(int dayIndex, int romanIndex, Course course) {
    final TextEditingController titleCtrl = TextEditingController(text: course.title);
    final TextEditingController subCtrl = TextEditingController(text: course.subtitle);
    final TextEditingController contentCtrl = TextEditingController(text: course.content);

    // 僅顯示此區段的節次供調整
    int startNum = romanIndex * 3 + 1;
    List<String> availableLabels = 'ABCDEFGHIJ'.split('').sublist(romanIndex * 2, romanIndex * 2 + 2);

    // 複製當前已選節次（僅限此區段範圍）
    List<int> selectedSlots = course.slots.where((s) => s >= startNum && s <= startNum + 2).toList();
    List<String> selectedLabels = course.labels.where((l) => availableLabels.contains(l)).toList();

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('編輯課程'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(controller: titleCtrl, decoration: const InputDecoration(labelText: '課堂名稱')),
                TextField(controller: subCtrl, decoration: const InputDecoration(labelText: '授課教師')),
                TextField(controller: contentCtrl, decoration: const InputDecoration(labelText: '上課教室')),
                const SizedBox(height: 12),
                const Divider(),
                Text('數字節次（$startNum - ${startNum + 2}）', style: const TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Wrap(
                  spacing: 8,
                  children: [for (int i = startNum; i <= startNum + 2; i++) i].map((s) => FilterChip(
                    label: Text('$s'),
                    selected: selectedSlots.contains(s),
                    onSelected: (v) => setDialogState(() => v ? selectedSlots.add(s) : selectedSlots.remove(s)),
                  )).toList(),
                ),
                const SizedBox(height: 8),
                const Divider(),
                Text('字母節次（${availableLabels.join('，')}）', style: const TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Wrap(
                  spacing: 8,
                  children: availableLabels.map((l) => FilterChip(
                    label: Text(l),
                    selected: selectedLabels.contains(l),
                    onSelected: (v) => setDialogState(() => v ? selectedLabels.add(l) : selectedLabels.remove(l)),
                  )).toList(),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                setState(() {
                  _schedule[dayIndex]?[romanIndex]?.remove(course);
                  if (_schedule[dayIndex]?[romanIndex]?.isEmpty ?? false) {
                    _schedule[dayIndex]?.remove(romanIndex);
                  }
                });
                _saveSchedule();
                Navigator.pop(context);
              },
              child: const Text('刪除此課程', style: TextStyle(color: Colors.red)),
            ),
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('取消')),
            FilledButton(
              onPressed: () {
                setState(() {
                  course.title = titleCtrl.text;
                  course.subtitle = subCtrl.text;
                  course.content = contentCtrl.text;
                  // 更新節次：保留不在此區段的原有節次，加上新選的
                  course.slots = [
                    ...course.slots.where((s) => s < startNum || s > startNum + 2),
                    ...selectedSlots,
                  ]..sort();
                  course.labels = [
                    ...course.labels.where((l) => !availableLabels.contains(l)),
                    ...selectedLabels,
                  ]..sort();
                });
                _saveSchedule();
                Navigator.pop(context);
              },
              style: FilledButton.styleFrom(backgroundColor: Colors.orange[800]),
              child: const Text('儲存'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: FloatingActionButton(
        onPressed: _openAddCourseDialog,
        backgroundColor: Colors.orange[800],
        child: const Icon(Icons.add, color: Colors.white),
      ),
      body: Column(
        children: [
          // 頂部星期列
          LayoutBuilder(builder: (context, constraints) {
            double sidebarWidth = constraints.maxWidth * 0.4;
            return SizedBox(
              height: headerHeight,
              child: Row(
                children: [
                  Container(
                    width: sidebarWidth,
                    decoration: const BoxDecoration(
                      color: Color(0xFFF5F5F5),
                      border: Border(right: BorderSide(color: Colors.black), bottom: BorderSide(color: Colors.black)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text('區段', style: TextStyle(fontSize: 12)),
                        const SizedBox(width: 4),
                        IconButton(
                          constraints: const BoxConstraints(),
                          padding: EdgeInsets.zero,
                          icon: const Icon(Icons.cloud_download, size: 16, color: Colors.black54),
                          onPressed: () async {
                            final success = await Navigator.push(
                              context,
                              MaterialPageRoute(builder: (context) => const ImportScreen()),
                            );
                            if (success == true) {
                              _loadSchedule();
                            }
                          },
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: SingleChildScrollView(
                      controller: _headerScrollController,
                      scrollDirection: Axis.horizontal,
                      physics: const NeverScrollableScrollPhysics(),
                      child: Row(
                        children: ['一', '二', '三', '四', '五'].map((h) => Container(
                          width: fixedCellWidth,
                          decoration: const BoxDecoration(border: Border(right: BorderSide(color: Colors.black), bottom: BorderSide(color: Colors.black))),
                          child: Center(child: Text(h, style: const TextStyle(fontWeight: FontWeight.bold))),
                        )).toList(),
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
          // 課表主體
          Expanded(
            child: LayoutBuilder(builder: (context, constraints) {
              double sidebarWidth = constraints.maxWidth * 0.4;
              double cellHeight = constraints.maxHeight / 5;
              return Row(
                children: [
                  // 左側時間欄
                  SizedBox(
                    width: sidebarWidth,
                    child: Column(
                      children: List.generate(5, (idx) => _buildFixedTimeSidebar(idx, cellHeight, sidebarWidth)),
                    ),
                  ),
                  // 右側課程滑動區
                  Expanded(
                    child: SingleChildScrollView(
                      controller: _bodyScrollController,
                      scrollDirection: Axis.horizontal,
                      child: Column(
                        children: List.generate(5, (romanIdx) => Row(
                          children: List.generate(5, (dayIdx) => _buildFitCell(dayIdx, romanIdx, cellHeight, fixedCellWidth)),
                        )),
                      ),
                    ),
                  ),
                ],
              );
            }),
          ),
        ],
      ),
    );
  }

  // --- 左側 UI：40% 寬度，內部 1/2 平分數字與字母 ---
  Widget _buildFixedTimeSidebar(int romanIdx, double totalHeight, double sidebarWidth) {
    int startNum = romanIdx * 3 + 1;
    List<String> rowLabels = 'ABCDEFGHIJ'.split('').sublist(romanIdx * 2, romanIdx * 2 + 2);

    return Container(
      width: sidebarWidth,
      height: totalHeight,
      decoration: BoxDecoration(
        color: Colors.orange[300],
        border: Border.all(color: Colors.black, width: 0.5),
      ),
      child: Row(
        children: [
          // 左半邊：數字 (1/2 寬度)
          Expanded(
            child: Column(
              children: List.generate(3, (i) {
                final data = _numTimeData[startNum + i - 1];
                return Expanded(
                  child: Container(
                    decoration: BoxDecoration(border: Border(bottom: i < 2 ? const BorderSide(color: Colors.black, width: 0.5) : BorderSide.none)),
                    child: Row(
                      children: [
                        Expanded(flex: 1, child: Center(child: Text('${data['n']}', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold)))),
                        Expanded(flex: 2, child: Container(
                          decoration: const BoxDecoration(border: Border(left: BorderSide(color: Colors.black, width: 0.5))),
                          child: Center(child: Text(data['t']!, textAlign: TextAlign.center, style: const TextStyle(fontSize: 9))),
                        )),
                      ],
                    ),
                  ),
                );
              }),
            ),
          ),
          // 右半邊：字母 (1/2 寬度)
          Expanded(
            child: Column(
              children: List.generate(2, (i) {
                final data = _labelTimeData.firstWhere((d) => d['n'] == rowLabels[i]);
                return Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      border: Border(
                        left: const BorderSide(color: Colors.black, width: 0.5),
                        bottom: i < 1 ? const BorderSide(color: Colors.black, width: 0.5) : BorderSide.none,
                      ),
                    ),
                    child: Row(
                      children: [
                        Expanded(flex: 1, child: Center(child: Text('${data['n']}', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold)))),
                        Expanded(flex: 2, child: Container(
                          decoration: const BoxDecoration(border: Border(left: BorderSide(color: Colors.black, width: 0.5))),
                          child: Center(child: Text(data['t']!, textAlign: TextAlign.center, style: const TextStyle(fontSize: 9))),
                        )),
                      ],
                    ),
                  ),
                );
              }),
            ),
          ),
        ],
      ),
    );
  }

  // --- 右側課程格子：顯示完整資訊與前綴 ---
  Widget _buildFitCell(int dayIdx, int romanIdx, double totalHeight, double width) {
    List<Course> courses = _schedule[dayIdx]?[romanIdx] ?? [];
    int baseNum = romanIdx * 3 + 1;
    List<String> rowLabels = 'ABCDEFGHIJ'.split('').sublist(romanIdx * 2, romanIdx * 2 + 2);

    return Container(
      key: Key('cell_${dayIdx}_$romanIdx'),
      width: width,
      height: totalHeight,
      decoration: BoxDecoration(border: Border.all(color: Colors.black, width: 0.5)),
      child: Stack(
        children: [
          for (var course in courses) ...[
            // 數字節次區塊
            ...List.generate(3, (i) {
              int slot = baseNum + i;
              if (!course.slots.contains(slot)) return const SizedBox.shrink();
              bool isStart = i == 0 || !course.slots.contains(slot - 1);
              if (!isStart) return const SizedBox.shrink();

              int span = 1;
              while (i + span < 3 && course.slots.contains(baseNum + i + span)) { span++; }
              
              String prefix = course.slots.where((s) => s >= baseNum && s < baseNum + 3).map((s) => "($s)").join();

              return Positioned(
                top: i * (totalHeight / 3),
                height: span * (totalHeight / 3),
                left: 0, right: 0,
                child: GestureDetector(
                  onTap: () => _openEditCourseDialog(dayIdx, romanIdx, course),
                  child: Container(
                    margin: const EdgeInsets.all(1),
                    color: Colors.blue[100]!.withOpacity(0.8),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(prefix + course.title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold), textAlign: TextAlign.center, maxLines: 2),
                        if (course.subtitle.isNotEmpty) Text(course.subtitle, style: const TextStyle(fontSize: 11)),
                        if (course.content.isNotEmpty) Text(course.content, style: const TextStyle(fontSize: 11, color: Colors.black54)),
                      ],
                    ),
                  ),
                ),
              );
            }),
            // 字母節次區塊
            ...List.generate(2, (i) {
              String label = rowLabels[i];
              if (!course.labels.contains(label)) return const SizedBox.shrink();
              bool isStart = i == 0 || !course.labels.contains(rowLabels[i - 1]);
              if (!isStart) return const SizedBox.shrink();

              int span = 1;
              while (i + span < 2 && course.labels.contains(rowLabels[i + span])) { span++; }
              
              String prefix = course.labels.where((l) => rowLabels.contains(l)).map((l) => "($l)").join();

              return Positioned(
                top: i * (totalHeight / 2),
                height: span * (totalHeight / 2),
                left: 0, right: 0,
                child: GestureDetector(
                  onTap: () => _openEditCourseDialog(dayIdx, romanIdx, course),
                  child: Container(
                    margin: const EdgeInsets.all(1),
                    color: Colors.green[100]!.withOpacity(0.8),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(prefix + course.title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold), textAlign: TextAlign.center, maxLines: 2),
                        if (course.subtitle.isNotEmpty) Text(course.subtitle, style: const TextStyle(fontSize: 11)),
                        if (course.content.isNotEmpty) Text(course.content, style: const TextStyle(fontSize: 11, color: Colors.black54)),
                      ],
                    ),
                  ),
                ),
              );
            }),
          ]
        ],
      ),
    );
  }
}
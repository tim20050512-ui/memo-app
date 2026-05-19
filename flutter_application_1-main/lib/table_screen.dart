import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

// --- 資料模型 ---
class Course {
  String title;    // 課堂名稱
  String subtitle; // 授課教師
  String content;  // 上課教室
  List<int> slots; // 數字節次 1-15
  List<String> labels; // 字母節次 A-J

  Course({
    this.title = '',
    this.subtitle = '',
    this.content = '',
    this.slots = const [],
    this.labels = const [],
  });

  Map<String, dynamic> toJson() => {
    'title': title,
    'subtitle': subtitle,
    'content': content,
    'slots': slots,
    'labels': labels,
  };

  factory Course.fromJson(Map<String, dynamic> json) => Course(
    title: json['title'] ?? '',
    subtitle: json['subtitle'] ?? '',
    content: json['content'] ?? '',
    slots: List<int>.from(json['slots'] ?? []),
    labels: List<String>.from(json['labels'] ?? []),
  );
}

class TableScreen extends StatefulWidget {
  const TableScreen({super.key});

  @override
  State<TableScreen> createState() => _TableScreenState();
}

class _TableScreenState extends State<TableScreen> {
  final List<String> _romanNumerals = ['I', 'II', 'III', 'IV', 'V'];
  
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
  }

  // --- 編輯對話框 ---
  void _openCourseDialog(int dayIndex, int romanIndex) {
    TextEditingController titleCtrl = TextEditingController();
    TextEditingController subCtrl = TextEditingController();
    TextEditingController contentCtrl = TextEditingController();
    List<int> selectedSlots = [];
    List<String> selectedLabels = [];

    int startNum = romanIndex * 3 + 1;
    List<String> availableLabels = 'ABCDEFGHIJ'.split('').sublist(romanIndex * 2, romanIndex * 2 + 2);

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text('新增區段 ${_romanNumerals[romanIndex]} 課程'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(controller: titleCtrl, decoration: const InputDecoration(labelText: '課堂名稱')),
                TextField(controller: subCtrl, decoration: const InputDecoration(labelText: '授課教師')),
                TextField(controller: contentCtrl, decoration: const InputDecoration(labelText: '上課教室')),
                const Divider(),
                Text('勾選數字節次 ($startNum-${startNum+2})'),
                Wrap(
                  spacing: 8,
                  children: [for(int i=startNum; i<=startNum+2; i++) i].map((s) => FilterChip(
                    label: Text('$s'),
                    selected: selectedSlots.contains(s),
                    onSelected: (v) => setDialogState(() => v ? selectedSlots.add(s) : selectedSlots.remove(s)),
                  )).toList(),
                ),
                const Divider(),
                Text('勾選字母節次 (${availableLabels.join(',')})'),
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
            TextButton(onPressed: () { setState(() => _schedule[dayIndex]?.remove(romanIndex)); _saveSchedule(); Navigator.pop(context); }, 
                       child: const Text('清空', style: TextStyle(color: Colors.red))),
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('取消')),
            TextButton(
              onPressed: () {
                setState(() {
                  _schedule[dayIndex] ??= {};
                  _schedule[dayIndex]![romanIndex] ??= [];
                  _schedule[dayIndex]![romanIndex]!.add(Course(
                    title: titleCtrl.text,
                    subtitle: subCtrl.text,
                    content: contentCtrl.text,
                    slots: selectedSlots..sort(),
                    labels: selectedLabels..sort(),
                  ));
                });
                _saveSchedule();
                Navigator.pop(context);
              },
              child: const Text('確定'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
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
                    child: const Center(child: Text('區段', style: TextStyle(fontSize: 12))),
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

    return InkWell(
      onTap: () => _openCourseDialog(dayIdx, romanIdx),
      child: Container(
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
                );
              }),
            ]
          ],
        ),
      ),
    );
  }
}
// 修改 lib/calendar_screen.dart 的內容
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key});

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  DateTime _focusedDay = DateTime.now();
  DateTime _selectedDay = DateTime.now();
  final List<Map<String, String>> _allMemos = [];
  static const _memosKey = 'memos_v2';

  @override
  void initState() {
    super.initState();
    _loadMemos();
  }

  Future<void> _loadMemos() async {
    final prefs = await SharedPreferences.getInstance();
    final List<String> encodedMemos = prefs.getStringList(_memosKey) ?? [];
    setState(() {
      _allMemos.clear();
      for (var encoded in encodedMemos) {
        final parts = encoded.split('|');
        if (parts.length >= 2) {
          _allMemos.add({'title': parts[0], 'date': parts[1]});
        }
      }
    });
  }

  void _onDaySelected(DateTime day) {
    setState(() {
      _selectedDay = day;
    });
  }

  Future<void> _selectYearMonth() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _focusedDay,
      firstDate: DateTime(2000),
      lastDate: DateTime(2101),
      initialDatePickerMode: DatePickerMode.year,
      locale: const Locale('zh', 'TW'),
    );
    if (picked != null && picked != _focusedDay) {
      setState(() {
        _focusedDay = DateTime(picked.year, picked.month, 1);
        _selectedDay = DateTime(picked.year, picked.month, 1); // 切換月份時預設選中第一天
      });
    }
  }

  List<Map<String, String>> _getMemosForDay(DateTime day) {
    final dateStr = DateFormat('yyyy年 MM月 dd日').format(day);
    return _allMemos.where((m) => m['date']!.startsWith(dateStr)).toList();
  }

  @override
  Widget build(BuildContext context) {
    // 使用 LayoutBuilder 來判斷寬度，調整格子比例
    return Scaffold(
      appBar: AppBar(
        title: InkWell(
          onTap: _selectYearMonth,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(DateFormat('yyyy年 MM月').format(_focusedDay),
                  style: const TextStyle(fontWeight: FontWeight.bold)),
              const Icon(Icons.arrow_drop_down),
            ],
          ),
        ),
      ),
      body: LayoutBuilder(
          builder: (context, constraints) {
            // 在寬螢幕下增加比例，減少高度
            double aspectRatio = constraints.maxWidth > 600 ? 2.5 : 1.2;

            return SingleChildScrollView( // 讓整個頁面可以滾動
              child: Column(
                children: [
                  _buildCalendarGrid(aspectRatio),
                  const Divider(height: 1),
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Row(
                      children: [
                        const Icon(Icons.event, size: 20, color: Colors.grey),
                        const SizedBox(width: 8),
                        Text(DateFormat('MM月 dd日').format(_selectedDay),
                            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                  _buildMemoList(),
                ],
              ),
            );
          }
      ),
    );
  }

  Widget _buildCalendarGrid(double aspectRatio) {
    final daysInMonth = DateUtils.getDaysInMonth(_focusedDay.year, _focusedDay.month);
    final firstDayOfMonth = DateTime(_focusedDay.year, _focusedDay.month, 1);
    final firstWeekday = firstDayOfMonth.weekday; // 1=Mon, 7=Sun

    final weekDays = ['一', '二', '三', '四', '五', '六', '日'];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8.0),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: weekDays.map((d) => Expanded(
                child: Center(child: Text(d, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)))
            )).toList(),
          ),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              childAspectRatio: aspectRatio, // 動態調整寬高比
            ),
            itemCount: 42,
            itemBuilder: (context, index) {
              int dayOffset = index - (firstWeekday - 1);
              if (dayOffset < 0 || dayOffset >= daysInMonth) {
                return const SizedBox();
              }
              final day = DateTime(_focusedDay.year, _focusedDay.month, dayOffset + 1);
              final isSelected = DateUtils.isSameDay(day, _selectedDay);
              final isToday = DateUtils.isSameDay(day, DateTime.now());
              final hasMemos = _getMemosForDay(day).isNotEmpty;

              return InkWell(
                onTap: () => _onDaySelected(day),
                child: Container(
                  margin: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    color: isSelected ? Colors.red[800] : (isToday ? Colors.red[50] : null),
                    borderRadius: BorderRadius.circular(8), // 改成圓角矩形，寬度大時比較好看
                  ),
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          '${day.day}',
                          style: TextStyle(
                            color: isSelected ? Colors.white : (isToday ? Colors.red : Colors.black),
                            fontWeight: isSelected || isToday ? FontWeight.bold : FontWeight.normal,
                          ),
                        ),
                        if (hasMemos)
                          Container(
                            width: 6,
                            height: 6,
                            margin: const EdgeInsets.only(top: 2),
                            decoration: BoxDecoration(
                              color: isSelected ? Colors.white : Colors.red,
                              shape: BoxShape.circle,
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildMemoList() {
    final dayMemos = _getMemosForDay(_selectedDay);
    if (dayMemos.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 40.0),
        child: Center(child: Text('當天沒有備忘錄')),
      );
    }
    return ListView.separated(
      shrinkWrap: true, // 放在 SingleChildScrollView 內必須設定
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: dayMemos.length,
      separatorBuilder: (context, index) => const Divider(),
      itemBuilder: (context, index) {
        final memo = dayMemos[index];
        return ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.radio_button_unchecked, color: Colors.grey),
          title: Text(memo['title']!, style: const TextStyle(fontWeight: FontWeight.w500)),
          subtitle: Text(memo['date']!.split(' ').last, style: TextStyle(color: Colors.red[300])),
          onTap: () {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('在日曆中僅能查看內容')));
          },
        );
      },
    );
  }
}
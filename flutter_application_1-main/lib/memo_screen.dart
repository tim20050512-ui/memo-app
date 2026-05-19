import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_application_1/memo_edit_screen.dart';
import 'package:intl/intl.dart';

class MemoScreen extends StatefulWidget {
  const MemoScreen({super.key});

  @override
  State<MemoScreen> createState() => _MemoScreenState();
}

class _MemoScreenState extends State<MemoScreen> {
  final List<Map<String, String>> _memos = [];
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
      _memos.clear();
      for (var encoded in encodedMemos) {
        final parts = encoded.split('|');
        if (parts.length >= 2) {
          _memos.add({'title': parts[0], 'date': parts[1]});
        }
      }
    });
  }

  Future<void> _saveMemos() async {
    final prefs = await SharedPreferences.getInstance();
    final List<String> encodedMemos = _memos.map((m) => "${m['title']}|${m['date']}").toList();
    await prefs.setStringList(_memosKey, encodedMemos);
  }

  Future<DateTime?> _pickDateTime(BuildContext context, DateTime initial) async {
    final DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2000),
      lastDate: DateTime(2101),
      locale: const Locale('zh', 'TW'),
    );
    if (pickedDate == null) return null;

    final TimeOfDay? pickedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initial),
    );
    if (pickedTime == null) return null;

    return DateTime(
      pickedDate.year,
      pickedDate.month,
      pickedDate.day,
      pickedTime.hour,
      pickedTime.minute,
    );
  }

  void _navigateToEditScreen({String? initialText, int? index}) async {
    // 增加備忘錄時，先彈出日期時間選擇器
    DateTime initialDT = DateTime.now();
    if (index != null) {
      try {
        initialDT = DateFormat('yyyy年 MM月 dd日 HH:mm').parse(_memos[index]['date']!);
      } catch (_) {}
    }

    final DateTime? selectedDT = await _pickDateTime(context, initialDT);
    if (selectedDT == null) return; // 取消選擇則不繼續

    final result = await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => MemoEditScreen(initialText: initialText),
      ),
    );

    if (result != null && result is String && result.isNotEmpty) {
      final dateStr = DateFormat('yyyy年 MM月 dd日 HH:mm').format(selectedDT);
      setState(() {
        if (index != null) {
          _memos[index] = {'title': result, 'date': dateStr};
        } else {
          _memos.add({'title': result, 'date': dateStr});
        }
      });
      _saveMemos();
    }
  }

  Future<void> _selectDate(BuildContext context, int index) async {
    DateTime initialDateTime = DateTime.now();
    try {
      initialDateTime = DateFormat('yyyy年 MM月 dd日 HH:mm').parse(_memos[index]['date']!);
    } catch (e) {
      initialDateTime = DateTime.now();
    }

    final DateTime? finalDateTime = await _pickDateTime(context, initialDateTime);
    
    if (finalDateTime != null) {
      final dateStr = DateFormat('yyyy年 MM月 dd日 HH:mm').format(finalDateTime);
      setState(() {
        _memos[index]['date'] = dateStr;
      });
      _saveMemos();
    }
  }

  void _deleteMemo(int index) {
    setState(() {
      _memos.removeAt(index);
    });
    _saveMemos();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('備忘錄', style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          IconButton(icon: const Icon(Icons.view_list), onPressed: () {}),
          IconButton(icon: const Icon(Icons.more_vert), onPressed: () {}),
        ],
      ),
      body: _memos.isEmpty
          ? const Center(
              child: Text('沒有備忘錄。點擊右下角按鈕新增一個！'),
            )
          : ListView.separated(
              itemCount: _memos.length,
              separatorBuilder: (context, index) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final memo = _memos[index];
                return Dismissible(
                  key: Key(memo['title']! + index.toString() + (memo['date'] ?? '')),
                  onDismissed: (direction) {
                    _deleteMemo(index);
                  },
                  background: Container(color: Colors.red),
                  child: ListTile(
                    leading: IconButton(
                      icon: const Icon(Icons.radio_button_unchecked, color: Colors.grey),
                      onPressed: () => _deleteMemo(index),
                    ),
                    title: Text(
                      memo['title']!,
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                    ),
                    subtitle: Padding(
                      padding: const EdgeInsets.only(top: 4.0),
                      child: InkWell(
                        onTap: () => _selectDate(context, index),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.calendar_today, size: 12, color: Colors.red[300]),
                            const SizedBox(width: 4),
                            Text(
                              memo['date']!,
                              style: TextStyle(fontSize: 12, color: Colors.red[300]),
                            ),
                          ],
                        ),
                      ),
                    ),
                    onTap: () {
                      _navigateToEditScreen(initialText: memo['title'], index: index);
                    },
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _navigateToEditScreen(),
        backgroundColor: Colors.red[800],
        foregroundColor: Colors.white,
        child: const Icon(Icons.add),
      ),
    );
  }
}

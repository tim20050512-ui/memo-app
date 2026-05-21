import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:flutter_application_1/widget_service.dart';
import 'package:flutter_application_1/table_screen.dart';

// --- 中正大學課表文字解析器核心 ---
class CourseParser {
  static List<Course> parse(String text) {
    List<Course> courses = [];
    final lines = text.split('\n');

    // 常用星期對照表
    final dayMap = {'一': 0, '二': 1, '三': 2, '四': 3, '五': 4};

    // 精準時間段匹配正則：匹配例如「星期二 10,11」、「五 C,D」、「(三) 1-3」等
    final timeRegex = RegExp(r'(?:星期|週|星期|周)?([一二三四五])\s*\(?([0-9a-zA-J,\-\s]+)\)?');

    for (var line in lines) {
      final lineTrimmed = line.trim();
      if (lineTrimmed.isEmpty) continue;

      // 尋找時間資訊
      final match = timeRegex.firstMatch(lineTrimmed);
      if (match != null) {
        final dayStr = match.group(1)!;
        final timeTokensStr = match.group(2)!;
        final dayIndex = dayMap[dayStr];
        if (dayIndex == null) continue;

        List<int> slots = [];
        List<String> labels = [];

        // 切割逗號、減號或空格
        final tokens = timeTokensStr.split(RegExp(r'[,\s]+'));
        for (var token in tokens) {
          final t = token.trim();
          if (t.isEmpty) continue;

          // 處理範圍，如 10-12
          if (t.contains('-')) {
            final rangeParts = t.split('-');
            if (rangeParts.length == 2) {
              final startPart = rangeParts[0].trim();
              final endPart = rangeParts[1].trim();
              final startInt = int.tryParse(startPart);
              final endInt = int.tryParse(endPart);
              if (startInt != null && endInt != null) {
                for (int i = startInt; i <= endInt; i++) {
                  if (i >= 1 && i <= 15) slots.add(i);
                }
              } else {
                // 字母範圍如 A-C
                if (startPart.length == 1 && endPart.length == 1) {
                  final startChar = startPart.toUpperCase().codeUnitAt(0);
                  final endChar = endPart.toUpperCase().codeUnitAt(0);
                  final aChar = 'A'.codeUnitAt(0);
                  final jChar = 'J'.codeUnitAt(0);
                  if (startChar >= aChar && startChar <= jChar && endChar >= aChar && endChar <= jChar) {
                    for (int i = startChar; i <= endChar; i++) {
                      labels.add(String.fromCharCode(i));
                    }
                  }
                }
              }
            }
          } else {
            // 單一節次
            final intVal = int.tryParse(t);
            if (intVal != null) {
              if (intVal >= 1 && intVal <= 15) slots.add(intVal);
            } else {
              final upper = t.toUpperCase();
              if (upper.length == 1 && upper.codeUnitAt(0) >= 'A'.codeUnitAt(0) && upper.codeUnitAt(0) <= 'J'.codeUnitAt(0)) {
                labels.add(upper);
              }
            }
          }
        }

        // 必須解析出時間段才算是有效課程列
        if (slots.isNotEmpty || labels.isNotEmpty) {
          // 擦除時間資訊，過濾多餘空格
          String infoPart = lineTrimmed.replaceAll(timeRegex, ' ').replaceAll(RegExp(r'\s+'), ' ').trim();
          
          final parts = infoPart.split(' ');

          // --- 專屬中正 Kiki 格式強健解析分支 ---
          final statusIdx = parts.indexOf('正常開課');
          if (statusIdx != -1 && parts.length > statusIdx + 4) {
            String title = parts[statusIdx + 4]; // 課程名稱 (例如 "微積分(二)")
            String subtitle = '';
            if (parts.length > statusIdx + 5) {
              subtitle = parts[statusIdx + 5]; // 開課單位 (例如 "數學系")
            }
            String room = parts.last; // 最後一個為教室
            if (room == subtitle || room == title) {
              room = '';
            }

            courses.add(Course(
              title: title,
              subtitle: subtitle,
              content: room,
              slots: slots..sort(),
              labels: labels..sort(),
              dayIndex: dayIndex,
            ));
            continue; // 解析完成，繼續處理下一行
          }
          
          String title = '';
          String room = '';
          String teacher = '';

          // 過濾課程代碼、學分、必選修等標記
          List<String> textParts = [];
          for (var p in parts) {
            if (RegExp(r'^\d{7}$').hasMatch(p)) continue;
            if (RegExp(r'^\d\.\d$').hasMatch(p)) continue;
            if (p == '必修' || p == '選修' || p == '通識' || p == '必' || p == '選') continue;
            textParts.add(p);
          }

          if (textParts.isNotEmpty) {
            if (textParts.length >= 3) {
              title = textParts[0];
              teacher = textParts[1];
              room = textParts[textParts.length - 1];
            } else if (textParts.length == 2) {
              title = textParts[0];
              room = textParts[1];
            } else {
              title = textParts[0];
            }
          } else {
            title = '未命名課程';
          }

          courses.add(Course(
            title: title,
            subtitle: teacher,
            content: room,
            slots: slots..sort(),
            labels: labels..sort(),
            dayIndex: dayIndex,
          ));
        }
      }
    }
    return courses;
  }
}

class ImportScreen extends StatefulWidget {
  const ImportScreen({super.key});

  @override
  State<ImportScreen> createState() => _ImportScreenState();
}

class _ImportScreenState extends State<ImportScreen> with SingleTickerProviderStateMixin {
  late final WebViewController _webViewController;
  final TextEditingController _textController = TextEditingController();
  late TabController _tabController;
  bool _isLoading = false;
  double _progress = 0.0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);

    // 初始化 WebView 配置，加載新版中正大學選課系統首頁
    _webViewController = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onProgress: (p) => setState(() => _progress = p / 100.0),
          onPageStarted: (url) => setState(() { _isLoading = true; _progress = 0.0; }),
          onPageFinished: (url) => setState(() => _isLoading = false),
        ),
      )
      ..loadRequest(Uri.parse('https://www026220.ccu.edu.tw/home'));
  }

  @override
  void dispose() {
    _tabController.dispose();
    _textController.dispose();
    super.dispose();
  }



  // --- WebView 網頁同步一鍵執行 ---
  Future<void> _handleWebViewImport() async {
    setState(() => _isLoading = true);
    try {
      // 注入 JavaScript 抓取整個網頁顯示的純文字
      final Object? result = await _webViewController.runJavaScriptReturningResult(
        'document.body.innerText'
      );

      if (result != null) {
        // 解碼傳回的 JSON 字串或純字串
        String pageText = '';
        if (result is String) {
          // 有些 WebView 版本會將字串以 JSON 編碼傳回（帶引號與跳脫字元）
          if (result.startsWith('"') && result.endsWith('"')) {
            try {
              pageText = jsonDecode(result);
            } catch (_) {
              pageText = result;
            }
          } else {
            pageText = result;
          }
        } else {
          pageText = result.toString();
        }

        final parsedCourses = CourseParser.parse(pageText);
        await _saveAndImportCoursesActual(parsedCourses);
      } else {
        throw Exception('無法讀取網頁純文字內容');
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('同步失敗：$e')),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  // --- 實際寫入儲存的核心邏輯 ---
  Future<void> _saveAndImportCoursesActual(List<Course> importedCourses) async {
    if (importedCourses.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('未偵測到任何課程資料，請確認內容格式！')),
      );
      return;
    }

    final prefs = await SharedPreferences.getInstance();

    // 覆蓋模式：清空本地舊課表，以學校最新資料為準
    Map<int, Map<int, List<Course>>> schedule = {};

    int importedCount = 0;

    for (var newCourse in importedCourses) {
      int dayIdx = newCourse.dayIndex;
      if (dayIdx < 0 || dayIdx > 4) continue;

      // 依據節次判定應放入哪個區段 (romanIndex)
      int? targetRoman;
      if (newCourse.slots.isNotEmpty) {
        int minSlot = newCourse.slots.reduce((a, b) => a < b ? a : b);
        targetRoman = (minSlot - 1) ~/ 3;
      } else if (newCourse.labels.isNotEmpty) {
        String minLabel = newCourse.labels.reduce((a, b) => a.compareTo(b) < 0 ? a : b);
        int labelIdx = minLabel.codeUnitAt(0) - 'A'.codeUnitAt(0);
        targetRoman = labelIdx ~/ 2;
      }

      if (targetRoman != null && targetRoman >= 0 && targetRoman <= 4) {
        schedule[dayIdx] ??= {};
        schedule[dayIdx]![targetRoman] ??= [];
        schedule[dayIdx]![targetRoman]!.add(newCourse);
        importedCount++;
      }
    }

    // 重新編碼儲存
    Map<String, dynamic> encoded = {};
    schedule.forEach((dayIdx, romanMap) {
      encoded[dayIdx.toString()] = {};
      romanMap.forEach((romanIdx, list) {
        encoded[dayIdx.toString()][romanIdx.toString()] = list.map((c) => c.toJson()).toList();
      });
    });
    
    await prefs.setString('schedule', jsonEncode(encoded));
    
    try {
      await WidgetService.updateWidget();
    } catch (_) {}

    // 提示結果並返回
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('匯入完成'),
        content: Text('成功匯入 $importedCount 門課程！（已覆蓋舊課表）'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context); // 關閉 Dialog
              Navigator.pop(context, true); // 返回 TableScreen 並傳回成功標記
            },
            child: const Text('確定'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('匯入中正個人課表', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.orange[800],
          unselectedLabelColor: Colors.black54,
          indicatorColor: Colors.orange[800],
          tabs: const [
            Tab(icon: Icon(Icons.language), text: '網頁一鍵同步'),
            Tab(icon: Icon(Icons.paste), text: '複製貼上同步'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        physics: const NeverScrollableScrollPhysics(), // 防止 WebView 滑動衝突
        children: [
          // --- Tab 1: WebView 同步 ---
          Stack(
            children: [
              Column(
                children: [
                  if (_isLoading || _progress < 1.0)
                    LinearProgressIndicator(
                      value: _progress > 0.0 ? _progress : null,
                      backgroundColor: Colors.orange[100],
                      color: Colors.orange[800],
                    ),
                  Expanded(
                    child: WebViewWidget(controller: _webViewController),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 4, offset: const Offset(0, -2))],
                    ),
                    child: SafeArea(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text(
                            '登入中正選課系統，進入「查詢選課結果」後點擊下方同步',
                            style: TextStyle(fontSize: 12, color: Colors.black54),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 8),
                          SizedBox(
                            width: double.infinity,
                            height: 48,
                            child: ElevatedButton.icon(
                              onPressed: _isLoading ? null : _handleWebViewImport,
                              icon: const Icon(Icons.sync),
                              label: const Text('一鍵同步此課表', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.orange[800],
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              if (_isLoading && _progress == 0.0)
                const Center(
                  child: Card(
                    color: Colors.white,
                    child: Padding(
                      padding: EdgeInsets.all(24.0),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          CircularProgressIndicator(color: Colors.orange),
                          SizedBox(height: 16),
                          Text('正在安全讀取選課資料...', style: TextStyle(fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
          // --- Tab 2: 複製貼上同步 ---
          SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue[50],
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.blue[200]!),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.info_outline, color: Colors.blue),
                      SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          '貼心備用方案：\n請在外置瀏覽器登入中正選課系統，全選複製選課結果頁面文字，並貼入下方輸入框。',
                          style: TextStyle(fontSize: 13, color: Colors.black87),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                const Text('在此貼上複製的網頁課表文字：', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                const SizedBox(height: 8),
                TextField(
                  controller: _textController,
                  maxLines: 10,
                  decoration: InputDecoration(
                    hintText: '例如：\n9012345 01 計算機概論 3.0 必修 二10,11 社科院227\n9012346 02 資料結構 3.0 必修 五C,D 社科院315',
                    hintStyle: const TextStyle(fontSize: 13, color: Colors.black38),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.orange[800]!, width: 2),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      final parsed = CourseParser.parse(_textController.text);
                      _saveAndImportCoursesActual(parsed);
                    },
                    icon: const Icon(Icons.analytics_outlined),
                    label: const Text('一鍵解析並匯入', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange[800],
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

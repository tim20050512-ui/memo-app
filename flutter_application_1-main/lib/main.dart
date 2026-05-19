import 'package:flutter/material.dart';//Flutter工具箱
import 'package:flutter_application_1/memo_screen.dart';//子模組
import 'package:flutter_application_1/table_screen.dart';//子模組
import 'package:flutter_application_1/calendar_screen.dart';//子模組
import 'package:flutter_localizations/flutter_localizations.dart';//系統內建文字變成中文

void main() {
  runApp(const MyApp());//點開app後執行，透過runApp讓app填滿整個畫面
}

class MyApp extends StatelessWidget {//MyApp是一個靜態組件
  const MyApp({super.key});//傳遞參數

  @override//覆寫build邏輯
  Widget build(BuildContext context) {//創造一個組件，傳入context可以知道目前環境的資訊
    return MaterialApp(//MaterialApp為高階封裝組件
      title: '備忘錄與表格',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.red),//選擇紅色，應用在按鈕等地方
        useMaterial3: true,//使用Google最新視覺語言
        visualDensity: VisualDensity.adaptivePlatformDensity,//在不同裝置自動切換元件的間距與大小
      ),
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,//翻譯Google的Material Design組件
        GlobalWidgetsLocalizations.delegate,//處理文字排版方向
        GlobalCupertinoLocalizations.delegate,//IOS風格組件
      ],
      supportedLocales: const [//支援的語言環境
        Locale('zh', 'TW'),//zh代表中文，TW代表台灣地區
        Locale('en', 'US'),//en代表英文，US代表美國地區
      ],
      home: const MainScreen(),//app啟動後第一個顯示的畫面
    );
  }
}

class MainScreen extends StatefulWidget {//記錄當下應該顯示的畫面(selectedIndex)
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _selectedIndex = 1;//預設顯示課表
  final List<Widget> _widgetOptions = <Widget>[//三個頁面，分別是收件箱、課表以及日曆
    const MemoScreen(),
    const TableScreen(),
    const CalendarScreen(),
  ];

  void _onItemTapped(int index) {//點擊下方按鈕更新selectedIndex並重新build
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _widgetOptions.elementAt(_selectedIndex),//根據index選擇對應畫面
      bottomNavigationBar: BottomNavigationBar(
        items: const <BottomNavigationBarItem>[//下方的三個按鈕
          BottomNavigationBarItem(
            icon: Icon(Icons.all_inbox),//圖示
            label: '備忘錄',//標籤
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.grid_on),
            label: '課表',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.calendar_today),
            label: '日曆',
          ),
        ],
        currentIndex: _selectedIndex,
        selectedItemColor: Colors.red[800],
        onTap: _onItemTapped,
        type: BottomNavigationBarType.fixed,
      ),
    );
  }
}
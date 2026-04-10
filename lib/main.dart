import 'package:cloud_firestore/cloud_firestore.dart'; // 務必加上這一行
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 網頁版初始化必須包含 options 盒子
  await Firebase.initializeApp(
    options: const FirebaseOptions(
      apiKey: "AIzaSyAVpk8Fat5nx-v1mz-Rlsa8GtQiRoDnO9g",
      authDomain: "chiness-words.firebaseapp.com",
      projectId: "chiness-words",
      storageBucket: "chiness-words.firebasestorage.app",
      messagingSenderId: "415968209787",
      appId: "1:415968209787:web:6da20ca5a7dbf076ea2bde",
      measurementId: "G-75JHKWWYYG",
    ),
  );
  // 加上這幾行，強制關閉網頁版的離線暫存，確保它每次都走網路
  try {
    FirebaseFirestore.instance.settings = const Settings(
      persistenceEnabled: false,
    );
  } catch (e) {
    debugPrint("設定失敗: $e");
  }

  runApp(const DragComponentApp());
}

class DragComponentApp extends StatelessWidget {
  const DragComponentApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(primaryColor: Colors.teal, useMaterial3: true),
      home: const VersionMenuPage(),
    );
  }
}

// --- 第一層：選擇版本 ---
class VersionMenuPage extends StatelessWidget {
  const VersionMenuPage({super.key});
  final List<String> versions = const ['南一', '康軒', '翰林'];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('選擇教材版本'),
        centerTitle: true,
        backgroundColor: Colors.teal[100],
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(20),
        itemCount: versions.length,
        itemBuilder: (context, index) => Card(
          child: ListTile(
            leading: const Icon(Icons.book, color: Colors.teal),
            title: Text(versions[index], style: const TextStyle(fontSize: 24)),
            trailing: const Icon(Icons.arrow_forward_ios),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => GradeMenuPage(version: versions[index]),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// --- 第二層：選擇年級 ---
class GradeMenuPage extends StatelessWidget {
  final String version;
  const GradeMenuPage({super.key, required this.version});

  @override
  Widget build(BuildContext context) {
    final List<String> grades = ['一年級', '二年級', '三年級', '四年級', '五年級', '六年級'];
    return Scaffold(
      appBar: AppBar(
        title: Text('$version - 選擇年級'),
        backgroundColor: Colors.teal[100],
      ),
      body: GridView.builder(
        padding: const EdgeInsets.all(20),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          childAspectRatio: 1.5,
          crossAxisSpacing: 10,
          mainAxisSpacing: 10,
        ),
        itemCount: grades.length,
        itemBuilder: (context, index) => ElevatedButton(
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) =>
                  LessonMenuPage(version: version, grade: grades[index]),
            ),
          ),
          child: Text(grades[index], style: const TextStyle(fontSize: 20)),
        ),
      ),
    );
  }
}

// --- 第三層：選擇學期與課次 ---
class LessonMenuPage extends StatelessWidget {
  final String version;
  final String grade;
  const LessonMenuPage({super.key, required this.version, required this.grade});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: Text('$grade - 選擇課次'),
          bottom: const TabBar(
            tabs: [
              Tab(text: '上學期'),
              Tab(text: '下學期'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _buildLessonList(context, '上學期'),
            _buildLessonList(context, '下學期'),
          ],
        ),
      ),
    );
  }

  Widget _buildLessonList(BuildContext context, String semester) {
    return ListView.builder(
      itemCount: 10,
      itemBuilder: (context, index) {
        String lessonName = '第 ${index + 1} 課';
        return ListTile(
          title: Text(lessonName),
          subtitle: Text('$version $grade $semester'),
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) =>
                  DragGamePage(info: '$version $grade $semester $lessonName'),
            ),
          ),
        );
      },
    );
  }
}

// --- 第四層：遊戲頁面 ---
class DragGamePage extends StatefulWidget {
  final String info;
  const DragGamePage({super.key, required this.info});

  @override
  State<DragGamePage> createState() => _DragGamePageState();
}

class _DragGamePageState extends State<DragGamePage> {
  List<Map<String, dynamic>> quizList = [];
  int currentIndex = 0;
  bool isLoading = true;

  String? leftPlaced; // 紀錄左邊格子放了什麼字
  String? rightPlaced; // 紀錄右邊格子放了什麼字

  // 新增：控制是否顯示錯誤的變數
  bool showLeftError = false;
  bool showRightError = false;

  final PageController _pageController = PageController(); // 翻頁控制員

  @override
  void initState() {
    super.initState();
    _fetchDataFromFirestore();
  }

  // --- 自動轉換 ID 的邏輯 ---
  String _generateDocId(String info) {
    try {
      final parts = info.split(' ');
      String v = parts[0] == '康軒' ? 'KSH' : (parts[0] == '南一' ? 'NY' : 'HL');
      String g = parts[1].substring(0, 1);
      String s = parts[2] == '上學期' ? 'up' : 'down';
      String l = parts[4].replaceAll(RegExp(r'[^0-9]'), '');
      String finalId = "${v}_${g}${s}_L$l";
      debugPrint("【偵錯】App 正在嘗試尋找的 ID 是: $finalId");
      return finalId;
    } catch (e) {
      return "default_id";
    }
  }

  // --- 抓取資料 ---
  Future<void> _fetchDataFromFirestore() async {
    try {
      String docId = _generateDocId(widget.info);
      DocumentSnapshot doc = await FirebaseFirestore.instance
          .collection('lessons')
          .doc(docId)
          .get();

      if (doc.exists) {
        setState(() {
          quizList = List<Map<String, dynamic>>.from(doc['words']);
          isLoading = false;
        });
      } else {
        setState(() {
          isLoading = false;
          quizList = [];
        });
      }
    } catch (e) {
      debugPrint("抓取失敗: $e");
      setState(() {
        isLoading = false;
      });
    }
  }

  // --- 處理「下一題」或「過關」邏輯 ---
  void _nextQuiz() {
    if (currentIndex < quizList.length - 1) {
      // 還有下一題，重置狀態並翻回第一頁
      setState(() {
        currentIndex++;
        leftPlaced = null;
        rightPlaced = null;
        showLeftError = false;
        showRightError = false;
      });
      // 跳回第一頁讓小朋友看下一個字
      _pageController.jumpToPage(0);
    } else {
      // 全都答對了，顯示過關視窗
      showDialog(
        context: context,
        barrierDismissible: false, // 點擊旁邊不能關閉
        builder: (context) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: const Text(
            "🏆 恭喜過關！",
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 28),
          ),
          content: const Text(
            "你已經完成這一課所有的生字了！太棒了！",
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 18),
          ),
          actionsAlignment: MainAxisAlignment.center,
          actions: [
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.teal),
              onPressed: () {
                Navigator.pop(context); // 關閉 Dialog
                Navigator.pop(context); // 回到課堂列表頁
              },
              child: const Text(
                "回到目錄",
                style: TextStyle(color: Colors.white, fontSize: 18),
              ),
            ),
          ],
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (quizList.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: Text(widget.info)),
        body: const Center(child: Text("尚無資料")),
      );
    }

    final quiz = quizList[currentIndex];

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.info),
        backgroundColor: Colors.teal[100],
        // 右上角顯示進度
        actions: [
          Center(
            child: Padding(
              padding: const EdgeInsets.only(right: 16.0),
              child: Text(
                "進度: ${currentIndex + 1} / ${quizList.length}",
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.teal,
                ),
              ),
            ),
          ),
        ],
      ),
      body: PageView(
        controller: _pageController,
        physics: const NeverScrollableScrollPhysics(), // 只能按按鈕翻頁
        children: [
          _buildStudyPage(quiz), // 第一頁：觀察
          _buildQuizPage(quiz), // 第二頁：挑戰
        ],
      ),
    );
  }

  // 頁面 A：看字
  Widget _buildStudyPage(Map<String, dynamic> quiz) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Text(
          "👀 認真記住這個字",
          style: TextStyle(fontSize: 20, color: Colors.grey),
        ),
        const SizedBox(height: 20),
        // 使用 RubyText 來顯示有注音的目標字
        _rubyText(quiz['target'], quiz['pinyin'], fontSize: 120),
        const SizedBox(height: 50),
        ElevatedButton(
          onPressed: () => _pageController.nextPage(
            duration: const Duration(milliseconds: 400),
            curve: Curves.easeInOut,
          ),
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 15),
            backgroundColor: Colors.teal,
          ),
          child: const Text(
            "記好了，去挑戰！",
            style: TextStyle(fontSize: 22, color: Colors.white),
          ),
        ),
      ],
    );
  }

  // 頁面 B：拼字遊戲
  Widget _buildQuizPage(Map<String, dynamic> quiz) {
    List<String> options = List<String>.from(quiz['options']);

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Text("🧩 憑記憶拼出來", style: TextStyle(fontSize: 24)),
        const SizedBox(height: 40),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildTargetBox(quiz['left'], true), // 左格
            const Text(" + ", style: TextStyle(fontSize: 30)),
            _buildTargetBox(quiz['right'], false), // 右格
          ],
        ),
        const SizedBox(height: 60),
        Wrap(
          spacing: 15,
          children: options.map((char) => _buildDraggableItem(char)).toList(),
        ),
        const SizedBox(height: 50),

        // 判斷是否兩邊都放對了
        if (leftPlaced == quiz['left'] && rightPlaced == quiz['right'])
          Column(
            children: [
              const Text(
                "🎉 答對了！你太厲害了！",
                style: TextStyle(
                  fontSize: 28,
                  color: Colors.green,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: _nextQuiz, // 呼叫下一題邏輯
                icon: const Icon(Icons.arrow_forward, color: Colors.white),
                label: const Text(
                  "下一題",
                  style: TextStyle(fontSize: 20, color: Colors.white),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 30,
                    vertical: 12,
                  ),
                ),
              ),
            ],
          ),
      ],
    );
  }

  Widget _buildDraggableItem(String char) {
    return Draggable<String>(
      data: char,
      feedback: Material(
        color: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Colors.teal,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            char,
            style: const TextStyle(
              fontSize: 30,
              color: Colors.white,
              decoration: TextDecoration.none,
            ),
          ),
        ),
      ),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.teal[50],
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.teal),
        ),
        child: Text(char, style: const TextStyle(fontSize: 30)),
      ),
    );
  }

  Widget _buildTargetBox(String correctChar, bool isLeft) {
    String? current = isLeft ? leftPlaced : rightPlaced;
    bool isCorrect = current == correctChar;
    // 判斷是否要顯示錯誤回饋
    bool isError = isLeft ? showLeftError : showRightError;

    return DragTarget<String>(
      onAccept: (data) {
        setState(() {
          if (isLeft) {
            leftPlaced = data;
            showLeftError = false; // 剛放下時先不顯示錯誤
          } else {
            rightPlaced = data;
            showRightError = false;
          }
        });

        // 如果放錯了，啟動 2 秒計時器
        if (data != correctChar) {
          Future.delayed(const Duration(seconds: 2), () {
            if (mounted) {
              // 確保頁面沒被關掉
              setState(() {
                if (isLeft && leftPlaced == data) showLeftError = true;
                if (!isLeft && rightPlaced == data) showRightError = true;
              });
            }
          });
        }
      },
      builder: (context, candidateData, rejectedData) {
        return Container(
          width: 80, // 稍微加寬
          height: 110, // 稍微加高以容納下方提示字
          alignment: Alignment.center,
          decoration: BoxDecoration(
            // 邏輯：對了變綠色，錯了 2 秒變紅色，平常灰色
            border: Border.all(
              color: isCorrect
                  ? Colors.green
                  : (isError ? Colors.red : Colors.grey),
              width: isError || isCorrect ? 3 : 2, // 對或錯時邊框加粗
            ),
            color: isCorrect
                ? Colors.green[50]
                : (isError ? Colors.red[50] : Colors.white),
            borderRadius: BorderRadius.circular(10), // 加上圓角更漂亮
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _rubyText(
                current ?? '?',
                isCorrect
                    ? (isLeft ? "ㄕㄡˇ" : "ㄅㄞˊ")
                    : "", // 若未來資料庫加上了注音，此處可換成 quiz['left_pinyin']
                fontSize: 40, // 讓格子裡的字大一點
              ),
              if (isError) // 如果錯了 2 秒，下面出一行小字提示
                const Padding(
                  padding: EdgeInsets.only(top: 4),
                  child: Text(
                    "再試試",
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.red,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  // 這是專門畫「國字+注音」的小工具 (加上了預設字體大小參數)
  Widget _rubyText(String kanji, String? zhuyin, {double fontSize = 30}) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // 上方注音
        Text(
          zhuyin ?? '',
          style: TextStyle(
            fontSize: fontSize * 0.4,
            color: Colors.teal,
            height: 1.0,
          ),
        ),
        // 下方國字
        Text(
          kanji,
          style: TextStyle(
            fontSize: fontSize,
            fontWeight: FontWeight.bold,
            height: 1.0,
          ),
        ),
      ],
    );
  }
}

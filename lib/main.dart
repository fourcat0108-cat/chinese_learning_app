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
  // 1. 變數宣告 (對應你原本的 177-179 行，並增加新功能所需的變數)
  List<Map<String, dynamic>> quizList = [];
  int currentIndex = 0;
  bool isLoading = true;

  String? leftPlaced; // 紀錄左邊格子放了什麼字
  String? rightPlaced; // 紀錄右邊格子放了什麼字
  final PageController _pageController = PageController(); // 翻頁控制員

  @override
  void initState() {
    super.initState();
    _fetchDataFromFirestore();
  }

  // --- 自動轉換 ID 的邏輯 (保持不變) ---
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

  // --- 抓取資料 (對應你原本 201 行之後的邏輯) ---
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

  @override
  Widget build(BuildContext context) {
    if (isLoading)
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    if (quizList.isEmpty)
      return Scaffold(
        appBar: AppBar(title: Text(widget.info)),
        body: const Center(child: Text("尚無資料")),
      );

    final quiz = quizList[currentIndex];

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.info),
        backgroundColor: Colors.teal[100],
      ),
      body: PageView(
        controller: _pageController,
        physics: const NeverScrollableScrollPhysics(), // 只能按按鈕翻頁，防止不小心滑動
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
        Text(
          quiz['target'],
          style: const TextStyle(fontSize: 120, fontWeight: FontWeight.bold),
        ),
        Text(
          quiz['pinyin'] ?? '',
          style: const TextStyle(fontSize: 30, color: Colors.teal),
        ),
        const SizedBox(height: 50),
        ElevatedButton(
          onPressed: () => _pageController.nextPage(
            duration: const Duration(milliseconds: 400),
            curve: Curves.easeInOut,
          ),
          child: const Text("記好了，去挑戰！"),
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
        const Text("🧩 憑記憶拼出來", style: TextStyle(fontSize: 20)),
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
        if (leftPlaced == quiz['left'] && rightPlaced == quiz['right'])
          const Text(
            "🎉 答對了！你太厲害了！",
            style: TextStyle(
              fontSize: 24,
              color: Colors.green,
              fontWeight: FontWeight.bold,
            ),
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
              fontSize: 24,
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
        child: Text(char, style: const TextStyle(fontSize: 24)),
      ),
    );
  }

  Widget _buildTargetBox(String correctChar, bool isLeft) {
    String? current = isLeft ? leftPlaced : rightPlaced;
    bool isCorrect = current == correctChar;

    return DragTarget<String>(
      onAccept: (data) =>
          setState(() => isLeft ? leftPlaced = data : rightPlaced = data),
      builder: (context, candidateData, rejectedData) {
        return Container(
          width: 70,
          height: 70,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            border: Border.all(
              color: isCorrect ? Colors.green : Colors.grey,
              width: 2,
            ),
            color: isCorrect ? Colors.green[50] : Colors.white,
          ),
          child: Text(current ?? '?', style: const TextStyle(fontSize: 30)),
        );
      },
    );
  }
}

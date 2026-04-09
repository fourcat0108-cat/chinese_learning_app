import 'package:cloud_firestore/cloud_firestore.dart'; // 務必加上這一行
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // 網頁版初始化必須包含 options 盒子
  await Firebase.initializeApp(
    options: const FirebaseOptions(
      apiKey: "AIzaSyAVpk8Fat5nx-v1mz-Rlsa8GtQiRoDnO9g", // 你截圖中的 key
      appId: "1:785265489123:web:xxxxxxxxxxxx",          // 請填入你網頁看到的 appId
      messagingSenderId: "785265489123",                 // 請填入你網頁看到的 ID
      projectId: "chinese-learning-app-xxxxx",           // 請填入你的專案 ID
      storageBucket: "chinese-learning-app-xxxxx.firebasestorage.app",
    ),
  );
  
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

  @override
  void initState() {
    super.initState();
    _fetchDataFromFirestore();
  }

  // 自動轉換 ID 的邏輯
  String _generateDocId(String info) {
    try {
      final parts = info.split(' ');
      String v = parts[0] == '康軒' ? 'KSH' : (parts[0] == '南一' ? 'NY' : 'HL');
      String g = parts[1].substring(0, 1); 
      String s = parts[2] == '上學期' ? 'up' : 'down';
      String l = parts[4].replaceAll(RegExp(r'[^0-9]'), ''); 
      return "${v}_${g}up_L$l";
    } catch (e) {
      return "default_id";
    }
  }

  Future<void> _fetchDataFromFirestore() async {
    try {
      String docId = _generateDocId(widget.info);
      DocumentSnapshot doc = await FirebaseFirestore.instance
          .collection('lessons') // 請確保網頁端集合名稱是 lessons
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
    if (isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (quizList.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: Text(widget.info), backgroundColor: Colors.teal[100]),
        body: const Center(child: Text("資料庫還沒建立這課的資料喔！")),
      );
    }

    final quiz = quizList[currentIndex];

    return Scaffold(
      appBar: AppBar(title: Text(widget.info), backgroundColor: Colors.teal[100]),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(quiz['target'], style: const TextStyle(fontSize: 100, fontWeight: FontWeight.bold)),
            Text(quiz['pinyin'] ?? '', style: const TextStyle(fontSize: 30, color: Colors.teal)),
            const SizedBox(height: 40),
            Text("組件：${quiz['left']} + ${quiz['right']}", style: const TextStyle(fontSize: 24)),
            const SizedBox(height: 20),
            const Text("✅ 雲端連線成功！", style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }
} // 這是最後一個關門大括號，務必保留
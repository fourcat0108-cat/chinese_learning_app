import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await Firebase.initializeApp();
  } catch (e) {
    debugPrint("Firebase 初始化失敗: $e");
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
  final List<Map<String, dynamic>> quizList = [
    {
      'target': '校',
      'pinyin': 'ㄒㄧㄠˋ',
      'left': '木',
      'right': '交',
      'options': ['木', '禾', '交', '父'],
    },
  ];

  int currentIndex = 0;
  @override
  Widget build(BuildContext context) {
    final quiz = quizList[currentIndex];
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.info),
        backgroundColor: Colors.teal[100],
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(quiz['target'], style: const TextStyle(fontSize: 80)),
            const Text("遊戲連線測試中...", style: TextStyle(fontSize: 20)),
          ],
        ),
      ),
    );
  }
}

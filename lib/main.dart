import 'dart:io';
import 'dart:async';
import 'package:flutter/material.dart';
import 'admin_login.dart';
import 'api_service.dart'; // <-- Connects to XAMPP backend

// JMCFI Official Colors
const Color jmcIndigo = Color(0xFF4B0082);
const Color jmcGrape = Color(0xFF6C3BAA);
const Color jmcWisteria = Color(0xFFC9A0DC);
const Color jmcSunglow = Color(0xFFFFCC33);

/* ===========================
   MAIN ENTRY
=========================== */
void main() {
  runApp(const TrackAccessApp());
}

/* ===========================
   DATA MODELS
=========================== */
class Student {
  String uid;
  String id;
  String name;
  int points;
  int visits;
  bool isActive;
  final List<PointLog> pointLogs;

  Student({
    required this.uid,
    required this.id,
    required this.name,
    this.points = 0,
    this.visits = 0,
    this.isActive = true,
    List<PointLog>? pointLogs,
  }) : pointLogs = pointLogs ?? [];
}

class PointLog {
  final String type;
  final int value;
  final DateTime time;

  PointLog({
    required this.type,
    required this.value,
    required this.time,
  });
}

class AttendanceLog {
  final String studentName;
  final String library;
  final String detail;
  final DateTime time;

  AttendanceLog(this.studentName, this.library, this.detail, this.time);
}

class Reward {
  String name;
  int cost;
  bool isActive;

  Reward(this.name, this.cost, {this.isActive = true});
}

/* ===========================
   GLOBAL APP STATE
=========================== */
class AppState extends ChangeNotifier {
  static final AppState instance = AppState._internal();
  AppState._internal();

  bool isAdminLoggedIn = false;

  final List<Student> students = [
    Student(uid: "A1", id: "2023-001", name: "Alice"),
    Student(uid: "B2", id: "2023-002", name: "Bob"),
    Student(uid: "C3", id: "2023-003", name: "Charlie"),
    Student(uid: "D4", id: "2023-004", name: "Diana"),
  ];

  final List<Reward> rewards = [
    Reward("Free Coffee", 50),
    Reward("1 Day Extension", 100),
    Reward("School Merchandise", 500),
  ];

  final List<AttendanceLog> visitLogs = [];
  final Set<String> scannedToday = {};
  int _scanIndex = 0;

  /* ===========================
     ADMIN LOGIN (via API)
  ============================ */
  Future<bool> loginAdmin(String username, String password) async {
    final success = await ApiService.login(username, password);
    isAdminLoggedIn = success;
    notifyListeners();
    return success;
  }

  void logoutAdmin() {
    isAdminLoggedIn = false;
    notifyListeners();
  }

  /* ===========================
     RFID & VISIT METHODS
  ============================ */
  String simulateRFIDScan() {
    final activeStudents = students.where((s) => s.isActive).toList();
    if (activeStudents.isEmpty) return "INVALID";
    final uid = activeStudents[_scanIndex % activeStudents.length].uid;
    _scanIndex = (_scanIndex + 1) % activeStudents.length;
    return uid;
  }

  Student? authenticateUID(String uid) {
    try {
      return students.firstWhere((s) => s.uid == uid);
    } catch (_) {
      return null;
    }
  }

  bool logVisit(Student student, String library, String detail,
      {int points = 5}) {
    if (scannedToday.contains(student.uid)) return false;

    scannedToday.add(student.uid);

    visitLogs.add(AttendanceLog(student.name, library, detail, DateTime.now()));

    student.points += points;
    student.visits++;

    student.pointLogs.add(PointLog(
      type: "$library - $detail",
      value: points,
      time: DateTime.now(),
    ));

    notifyListeners();
    return true;
  }

  void resetDailyAttendance() {
    scannedToday.clear();
    notifyListeners();
  }

  void resetStudentPoints(Student student) {
    student.points = 0;
    student.pointLogs.clear();
    notifyListeners();
  }

  void resetAllPoints() {
    for (var s in students) {
      resetStudentPoints(s);
    }
  }

  void resetScheduledPoints() {
    DateTime now = DateTime.now();
    if (now.weekday == DateTime.monday) {
      resetAllPoints();
    }
  }

  // --- UI Mutators ---
  void updateStudent(Student s, String name, String id, String uid) {
    s.name = name;
    s.id = id;
    s.uid = uid;
    notifyListeners();
  }

  void toggleStudentArchive(Student s) {
    s.isActive = !s.isActive;
    notifyListeners();
  }

  void updateReward(Reward r, String name, int cost) {
    r.name = name;
    r.cost = cost;
    notifyListeners();
  }

  void toggleRewardArchive(Reward r) {
    r.isActive = !r.isActive;
    notifyListeners();
  }

  void addReward(String name, int cost) {
    rewards.add(Reward(name, cost));
    notifyListeners();
  }

  void redeemReward(Student s, Reward r) {
    s.points -= r.cost;
    s.pointLogs.add(PointLog(
      type: "Redeemed: ${r.name}",
      value: -r.cost,
      time: DateTime.now(),
    ));
    notifyListeners();
  }

  void adjustPoints(Student student, int delta) {
    student.points += delta;
    if (student.points < 0) student.points = 0;
    student.pointLogs.add(PointLog(
      type: delta > 0 ? "Manual Add" : "Manual Subtract",
      value: delta.abs(),
      time: DateTime.now(),
    ));
    notifyListeners();
  }

  /* ===========================
     STATISTICS
  ============================ */
  int todayVisits() {
    final now = DateTime.now();
    return visitLogs
        .where((l) =>
            l.time.year == now.year &&
            l.time.month == now.month &&
            l.time.day == now.day)
        .length;
  }

  int thisMonthVisits() {
    final now = DateTime.now();
    return visitLogs
        .where((l) => l.time.year == now.year && l.time.month == now.month)
        .length;
  }

  int totalVisits() => visitLogs.length;
}

/* ===========================
   MAIN APP
=========================== */
class TrackAccessApp extends StatelessWidget {
  const TrackAccessApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: "TrackAccess Library System",
      theme: ThemeData(
        primaryColor: jmcIndigo,
        colorScheme: ColorScheme.fromSeed(
          seedColor: jmcIndigo,
          primary: jmcIndigo,
          secondary: jmcSunglow,
        ),
        scaffoldBackgroundColor: const Color(0xFFF8F9FA),
        appBarTheme: const AppBarTheme(
          backgroundColor: jmcIndigo,
          foregroundColor: Colors.white,
          elevation: 0,
          centerTitle: true,
        ),
        cardTheme: CardThemeData(
          elevation: 6,
          shadowColor: const Color(0x336C3BAA),
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: jmcIndigo,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          ),
        ),
      ),
      home: const MainLayout(),
    );
  }
}

/* ===========================
   MAIN LAYOUT
=========================== */
class MainLayout extends StatefulWidget {
  const MainLayout({super.key});

  @override
  State<MainLayout> createState() => _MainLayoutState();
}

class _MainLayoutState extends State<MainLayout> {
  Widget currentPage = const StudentModule();
  String pageTitle = "Student";

  void switchPage(String title, Widget page) {
    setState(() {
      pageTitle = title;
      currentPage = page;
    });
    Navigator.pop(context); // Close drawer automatically
  }

  void openAdmin() async {
    final state = AppState.instance;

    if (!state.isAdminLoggedIn) {
      await Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => AdminLoginPage()),
      );
    }

    if (state.isAdminLoggedIn) {
      switchPage("Dashboard", AdminDashboard());
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = AppState.instance;

    return Scaffold(
      appBar: AppBar(title: Text(pageTitle)),
      drawer: Drawer(
        child: ListView(
          children: [
            DrawerHeader(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [jmcIndigo, jmcGrape],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.account_balance,
                          color: Colors.white, size: 40),
                      const SizedBox(width: 12),
                      const Text("JMCFI",
                          style: TextStyle(
                              color: jmcSunglow,
                              fontFamily: 'Montserrat',
                              fontSize: 28,
                              fontWeight: FontWeight.bold)),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Text("TrackAccess",
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.w600)),
                  const Text("Library Attendance",
                      style: TextStyle(color: Colors.white70, fontSize: 13)),
                ],
              ),
            ),
            ListTile(
              leading: const Icon(Icons.school),
              title: const Text("Student"),
              onTap: () => switchPage("Student", const StudentModule()),
            ),
            AnimatedBuilder(
              animation: state,
              builder: (context, _) {
                return ExpansionTile(
                  leading: const Icon(Icons.admin_panel_settings),
                  title: const Text("Admin"),
                  initiallyExpanded: state.isAdminLoggedIn,
                  onExpansionChanged: (expanded) async {
                    if (!state.isAdminLoggedIn) {
                      await Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => AdminLoginPage()),
                      );
                      setState(() {}); // rebuild drawer after login
                    }
                  },
                  children: state.isAdminLoggedIn
                      ? [
                          ListTile(
                            leading: const Icon(Icons.dashboard),
                            title: const Text("Dashboard"),
                            onTap: () =>
                                switchPage("Dashboard", AdminDashboard()),
                          ),
                          ListTile(
                            leading: const Icon(Icons.people),
                            title: const Text("Student Management"),
                            onTap: () => switchPage(
                                "Student Management", StudentManagement()),
                          ),
                          ListTile(
                            leading: const Icon(Icons.analytics),
                            title: const Text("Attendance Analytics"),
                            onTap: () => switchPage("Attendance Analytics",
                                const AttendanceAnalytics()),
                          ),
                          ListTile(
                            leading: const Icon(Icons.leaderboard),
                            title: const Text("Leaderboard Control"),
                            onTap: () => switchPage("Leaderboard Control",
                                const LeaderboardControl()),
                          ),
                          ListTile(
                            leading: const Icon(Icons.card_giftcard),
                            title: const Text("Rewards"),
                            onTap: () => switchPage("Rewards", RewardsModule()),
                          ),
                          ListTile(
                            leading: const Icon(Icons.settings),
                            title: const Text("System Settings"),
                            onTap: () => switchPage(
                                "System Settings", const SystemSettings()),
                          ),
                        ]
                      : [],
                );
              },
            ),
            if (state.isAdminLoggedIn) ...[
              const Divider(),
              ListTile(
                leading: const Icon(Icons.logout, color: Colors.redAccent),
                title: const Text(
                  "Logout",
                  style: TextStyle(color: Colors.redAccent),
                ),
                onTap: () {
                  state.logoutAdmin();
                  switchPage("Student", const StudentModule());
                },
              ),
            ],
          ],
        ),
      ),
      body: currentPage,
    );
  }
}

/* ===========================
   SECTION HEADER
=========================== */
class SectionHeader extends StatelessWidget {
  final String title;

  const SectionHeader({super.key, required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.bold,
          color: Colors.deepPurple,
        ),
      ),
    );
  }
}

/* ===========================
   STUDENT MODULE
=========================== */
class StudentModule extends StatefulWidget {
  const StudentModule({super.key});

  @override
  State<StudentModule> createState() => _StudentModuleState();
}

class _StudentModuleState extends State<StudentModule>
    with SingleTickerProviderStateMixin {
  final AppState state = AppState.instance;

  String message = "Please tap your RFID card";
  String selectedLibrary = "College Library";
  String selectedDetail = "Entry";

  late AnimationController controller;
  Timer? _pollTimer;
  String? _lastScannedUID;

  @override
  void initState() {
    super.initState();
    controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );

    // Start polling the backend for new RFID scans every 1.5 seconds
    _pollTimer = Timer.periodic(const Duration(milliseconds: 1500), (timer) {
      _checkForPhysicalScan();
    });
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    controller.dispose();
    super.dispose();
  }

  void _checkForPhysicalScan() async {
    final uid = await ApiService.getLatestScan();
    if (uid != null && uid != _lastScannedUID) {
      _lastScannedUID = uid;
      handleScan(uid);
    }
  }

  void handleScan(String uid) {
    final student = state.authenticateUID(uid);

    setState(() {
      if (student == null) {
        message = "Invalid Card.\nContact librarian.";
      } else {
        final success =
            state.logVisit(student, selectedLibrary, selectedDetail);

        message = success
            ? "Welcome ${student.name}\nPoints: ${student.points}\n($selectedLibrary - $selectedDetail)"
            : "Already logged today";
      }

      controller.forward(from: 0);
    });
  }

  void scanCard() {
    // Keep simulation button working alongside physical scanner
    final uid = state.simulateRFIDScan();
    handleScan(uid);
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const SectionHeader(title: "Student Check in"),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                const Icon(Icons.nfc, size: 60, color: Colors.deepPurple),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text(
                      "College Library",
                      style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.deepPurple),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton.icon(
                      onPressed: scanCard,
                      icon: const Icon(Icons.touch_app),
                      label: const Text("Scan"),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                FadeTransition(
                  opacity: controller.drive(
                    Tween(begin: 0.0, end: 1.0)
                        .chain(CurveTween(curve: Curves.easeIn)),
                  ),
                  child: Text(
                    message,
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),
        const SectionHeader(title: "Live Leaderboard"),
        const SizedBox(
          height: 400,
          child: LiveLeaderboard(),
        ),
      ],
    );
  }
}

/* ===========================
   LIVE LEADERBOARD
=========================== */
class LiveLeaderboard extends StatelessWidget {
  const LiveLeaderboard({super.key});

  @override
  Widget build(BuildContext context) {
    final state = AppState.instance;
    final sorted = [...state.students]
      ..sort((a, b) => b.points.compareTo(a.points));
    final maxPoints = sorted.isNotEmpty ? sorted.first.points : 1;

    return ListView.builder(
      itemCount: sorted.length,
      itemBuilder: (context, index) {
        final student = sorted[index];
        final rank = index + 1;

        Color rankColor;
        if (rank == 1) {
          rankColor = Colors.amber;
        } else if (rank == 2) {
          rankColor = Colors.grey;
        } else if (rank == 3) {
          rankColor = Colors.brown;
        } else {
          rankColor = Colors.deepPurple;
        }

        return Card(
          color: rank <= 3 ? Colors.deepPurple.shade50 : null,
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: rankColor,
              child: Text(
                "#$rank",
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            title: Text(
              student.name,
              style: TextStyle(
                  fontWeight: rank <= 3 ? FontWeight.bold : FontWeight.normal),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("${student.visits} visits"),
                LinearProgressIndicator(
                  value: maxPoints == 0 ? 0 : student.points / maxPoints,
                  color: Colors.deepPurple,
                  backgroundColor: Colors.deepPurple.shade100,
                ),
              ],
            ),
            trailing: Text(
              "${student.points} pts",
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        );
      },
    );
  }
}

/* ===========================
   ADMIN DASHBOARD
=========================== */
class AdminDashboard extends StatelessWidget {
  final AppState state = AppState.instance;

  AdminDashboard({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const SectionHeader(title: "Admin Overview"),
        const _AdminStatsGrid(),
        const SizedBox(height: 30),

        // ✅ LOGOUT BUTTON
        ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.red,
            padding: const EdgeInsets.symmetric(vertical: 14),
          ),
          onPressed: () {
            state.logoutAdmin();

            // Return to Student Module after logout
            Navigator.pushAndRemoveUntil(
              context,
              MaterialPageRoute(builder: (_) => const MainLayout()),
              (route) => false,
            );
          },
          icon: const Icon(Icons.logout),
          label: const Text("Logout Admin"),
        ),
      ],
    );
  }
}

/* ===========================
   ADMIN STATS GRID
=========================== */
class _AdminStatsGrid extends StatelessWidget {
  const _AdminStatsGrid();

  @override
  Widget build(BuildContext context) {
    final state = AppState.instance;

    return Wrap(
      spacing: 16,
      runSpacing: 16,
      alignment: WrapAlignment.start,
      children: [
        _statCard("Today's Visits", state.todayVisits(), Icons.today),
        _statCard("This Month", state.thisMonthVisits(), Icons.calendar_month),
        _statCard("Total Visits", state.totalVisits(), Icons.history),
        _statCard("Total Students", state.students.length, Icons.people),
      ],
    );
  }

  static Widget _statCard(String title, int value, IconData icon) {
    return SizedBox(
      width: 200,
      height: 160,
      child: Card(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: jmcIndigo.withOpacity(0.1), width: 1),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircleAvatar(
                backgroundColor: jmcIndigo.withOpacity(0.08),
                radius: 20,
                child: Icon(icon, size: 24, color: jmcIndigo),
              ),
              const SizedBox(height: 12),
              Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    fontSize: 14,
                    color: Colors.black54,
                    fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 6),
              Text(
                value.toString(),
                style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: jmcIndigo),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/* ===========================
   STUDENT MANAGEMENT
=========================== */
class StudentManagement extends StatefulWidget {
  const StudentManagement({super.key});

  @override
  State<StudentManagement> createState() => _StudentManagementState();
}

class _StudentManagementState extends State<StudentManagement> {
  final AppState state = AppState.instance;
  String searchQuery = "";

  void editStudent(Student student) {
    TextEditingController nameCtrl = TextEditingController(text: student.name);
    TextEditingController idCtrl = TextEditingController(text: student.id);
    TextEditingController uidCtrl = TextEditingController(text: student.uid);

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Edit Student"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
                controller: nameCtrl,
                decoration: const InputDecoration(labelText: "Name")),
            TextField(
                controller: idCtrl,
                decoration: const InputDecoration(labelText: "Student ID")),
            TextField(
                controller: uidCtrl,
                decoration: const InputDecoration(labelText: "RFID UID")),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Cancel")),
          ElevatedButton(
            onPressed: () {
              setState(() {
                state.updateStudent(
                    student, nameCtrl.text, idCtrl.text, uidCtrl.text);
              });
              Navigator.pop(context);
            },
            child: const Text("Save"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final filteredStudents = state.students.where((s) {
      final q = searchQuery.toLowerCase();
      return s.name.toLowerCase().contains(q) || s.id.toLowerCase().contains(q);
    }).toList();

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const SectionHeader(title: "Student Management"),
        TextField(
          decoration: const InputDecoration(
            prefixIcon: Icon(Icons.search, color: Colors.deepPurple),
            hintText: "Search by student name or ID",
            border: OutlineInputBorder(),
          ),
          onChanged: (value) {
            setState(() {
              searchQuery = value;
            });
          },
        ),
        const SizedBox(height: 10),
        ...filteredStudents.map(
          (s) => Card(
            color: s.isActive ? Colors.white : Colors.grey.shade300,
            child: ListTile(
              title: Text("${s.name} ${!s.isActive ? '(Archived)' : ''}"),
              subtitle:
                  Text("ID: ${s.id} | UID: ${s.uid} | Points: ${s.points}"),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.edit, color: Colors.blue),
                    onPressed: () => editStudent(s),
                  ),
                  IconButton(
                    icon: Icon(s.isActive ? Icons.archive : Icons.unarchive,
                        color: s.isActive ? Colors.red : Colors.green),
                    onPressed: () {
                      setState(() {
                        state.toggleStudentArchive(s);
                      });
                    },
                  ),
                  IconButton(
                    icon: const Icon(Icons.refresh, color: Colors.deepPurple),
                    onPressed: () {
                      setState(() {
                        state.resetStudentPoints(s);
                      });
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/* ===========================
   ATTENDANCE ANALYTICS
=========================== */
class AttendanceAnalytics extends StatefulWidget {
  const AttendanceAnalytics({super.key});

  @override
  State<AttendanceAnalytics> createState() => _AttendanceAnalyticsState();
}

class _AttendanceAnalyticsState extends State<AttendanceAnalytics> {
  final AppState state = AppState.instance;

  String selectedLibrary = "College Library";
  String searchQuery = "";

  int count(String library, [String? detail]) {
    return state.visitLogs.where((l) {
      if (detail == null) return l.library == library;
      return l.library == library && l.detail == detail;
    }).length;
  }

  @override
  Widget build(BuildContext context) {
    final recentLogs = state.visitLogs
        .where((l) => l.library == selectedLibrary)
        .toList()
        .reversed
        .take(10);

    final filteredStudents = state.students.where((s) {
      final q = searchQuery.toLowerCase();
      return s.name.toLowerCase().contains(q) || s.id.toLowerCase().contains(q);
    }).toList();

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const Text(
          "Attendance Analytics",
          style: TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.bold,
            color: Colors.deepPurple,
          ),
        ),

        const SizedBox(height: 20),


        const SizedBox(height: 20),

        analyticsInfoCard(
          title: "Total Library Usage",
          value: count(selectedLibrary),
          icon: Icons.library_books,
        ),
        analyticsInfoCard(
          title: "Entry Count",
          value: count(selectedLibrary, "Entry"),
          icon: Icons.meeting_room,
        ),

        const SizedBox(height: 24),

        // Recent Check-ins
        const Text(
          "Recent Check-ins",
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.deepPurple,
          ),
        ),
        const SizedBox(height: 10),
        ...recentLogs.map(
          (l) => Card(
            child: ListTile(
              title: Text(l.studentName),
              subtitle: Text("${l.library} • ${l.detail}"),
              trailing: Text(
                "${l.time.year}-${l.time.month.toString().padLeft(2, '0')}-${l.time.day.toString().padLeft(2, '0')} "
                "${l.time.hour.toString().padLeft(2, '0')}:${l.time.minute.toString().padLeft(2, '0')}",
              ),
            ),
          ),
        ),

        const SizedBox(height: 30),

        // Spreadsheet Section
        const Text(
          "Student Analytics Spreadsheet",
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: Colors.deepPurple,
          ),
        ),
        const SizedBox(height: 15),

        // Search Bar
        TextField(
          decoration: const InputDecoration(
            prefixIcon: Icon(Icons.search),
            hintText: "Search by student name or ID",
            border: OutlineInputBorder(),
          ),
          onChanged: (value) {
            setState(() {
              searchQuery = value;
            });
          },
        ),
        const SizedBox(height: 20),

        // Spreadsheet Table
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            columns: const [
              DataColumn(label: Text("Student Name")),
              DataColumn(label: Text("Student ID")),
              DataColumn(label: Text("Course Year")),
              DataColumn(label: Text("Points")),
              DataColumn(label: Text("Visits")),
              DataColumn(label: Text("Last Visit")), // NEW
            ],
            rows: filteredStudents.map((s) {
              final lastLog = state.visitLogs
                  .where((log) => log.studentName == s.name)
                  .toList()
                  .fold<AttendanceLog?>(
                      null,
                      (prev, log) =>
                          (prev == null || log.time.isAfter(prev.time))
                              ? log
                              : prev);

              final lastCheckIn = lastLog != null
                  ? "${lastLog.time.year}-${lastLog.time.month.toString().padLeft(2, '0')}-${lastLog.time.day.toString().padLeft(2, '0')} "
                      "${lastLog.time.hour.toString().padLeft(2, '0')}:${lastLog.time.minute.toString().padLeft(2, '0')}"
                  : "-";

              return DataRow(
                cells: [
                  DataCell(Text(s.name)),
                  DataCell(Text(s.id)),
                  const DataCell(Text("2023")),
                  DataCell(Text(s.points.toString())),
                  DataCell(Text(s.visits.toString())),
                  DataCell(Text(lastCheckIn)), // display last visit
                ],
              );
            }).toList(),
          ),
        ),

        const SizedBox(height: 20),

        // Generate Report Button
        Center(
          child: SizedBox(
            width: double.infinity,
            height: 54,
            child: ElevatedButton.icon(
              icon: const Icon(Icons.download_rounded,
                  size: 28, color: Colors.white),
              label: const Text("Download CSV Report to Desktop",
                  style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white)),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green.shade600,
                elevation: 4,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: () => generateReport(filteredStudents),
            ),
          ),
        ),
      ],
    );
  }

  // Library button
  Widget libraryButton(String name) {
    final selected = selectedLibrary == name;

    return ElevatedButton(
      style: ElevatedButton.styleFrom(
        backgroundColor: selected ? Colors.deepPurple : Colors.grey.shade200,
        foregroundColor: selected ? Colors.white : Colors.black87,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
      ),
      onPressed: () {
        setState(() {
          selectedLibrary = name;
        });
      },
      child: Text(name),
    );
  }

  // Analytics card
  Widget analyticsInfoCard(
      {required String title, required int value, required IconData icon}) {
    return Card(
      child: ListTile(
        leading: Icon(icon, color: Colors.deepPurple),
        title: Text(title),
        trailing: Text(
          value.toString(),
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  // Generate report
  Future<void> generateReport(List<Student> studentsToExport) async {
    final buffer = StringBuffer();
    buffer.writeln("Report Type,Attendance Logs");
    buffer.writeln("Name,Student ID,Course Year,Points,Visits,Last Visit");

    for (var s in studentsToExport) {
      final lastLog = state.visitLogs
          .where((log) => log.studentName == s.name)
          .fold<AttendanceLog?>(
              null,
              (prev, log) =>
                  (prev == null || log.time.isAfter(prev.time)) ? log : prev);

      final lastCheckIn = lastLog != null
          ? "${lastLog.time.year}-${lastLog.time.month.toString().padLeft(2, '0')}-${lastLog.time.day.toString().padLeft(2, '0')} "
              "${lastLog.time.hour.toString().padLeft(2, '0')}:${lastLog.time.minute.toString().padLeft(2, '0')}"
          : "-";

      buffer.writeln(
          '"${s.name}","${s.id}","2023","${s.points}","${s.visits}","$lastCheckIn"');
    }

    buffer.writeln("");
    buffer.writeln("Report Type,Rewards History");
    buffer.writeln("Student,Type,Points Change,Date");

    for (var s in state.students) {
      for (var log in s.pointLogs) {
        if (log.value < 0 || log.type.contains("Redeem")) {
          buffer.writeln(
              '"${s.name}","${log.type}","${log.value}","${log.time.toString()}"');
        }
      }
    }

    try {
      final file = File(
          'C:/Users/mike3/OneDrive/Desktop/Library_Report_${DateTime.now().millisecondsSinceEpoch}.csv');
      await file.writeAsString(buffer.toString());

      if (mounted) {
        showDialog(
          context: context,
          builder: (_) => AlertDialog(
            title: const Text("Report Exported"),
            content: Text("Successfully saved to your Desktop:\n${file.path}"),
            actions: [
              TextButton(
                  child: const Text("OK"),
                  onPressed: () => Navigator.pop(context)),
            ],
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text("Error saving: $e")));
      }
    }
  }
}

/* ===========================
   REWARDS MODULE
   (Eligible Students List)
   
=========================== */
class RewardsModule extends StatefulWidget {
  const RewardsModule({super.key});

  @override
  State<RewardsModule> createState() => _RewardsModuleState();
}

class _RewardsModuleState extends State<RewardsModule> {
  final AppState state = AppState.instance;

  void redeemReward(Reward reward) {
    final eligibleStudents = state.students
        .where((s) => s.points >= reward.cost && s.isActive)
        .toList();
    if (eligibleStudents.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("No students have enough points.")));
      return;
    }

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text("Redeem ${reward.name}"),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: eligibleStudents.length,
            itemBuilder: (ctx, i) {
              final student = eligibleStudents[i];
              return ListTile(
                title: Text(student.name),
                subtitle: Text("Points: ${student.points}"),
                onTap: () {
                  setState(() {
                    state.redeemReward(student, reward);
                  });
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                      content:
                          Text("${student.name} redeemed ${reward.name}!")));
                },
              );
            },
          ),
        ),
      ),
    );
  }

  void editReward(Reward reward) {
    TextEditingController nameCtrl = TextEditingController(text: reward.name);
    TextEditingController costCtrl =
        TextEditingController(text: reward.cost.toString());

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Edit Reward"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
                controller: nameCtrl,
                decoration: const InputDecoration(labelText: "Reward Name")),
            TextField(
                controller: costCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: "Point Cost")),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Cancel")),
          ElevatedButton(
            onPressed: () {
              setState(() {
                state.updateReward(reward, nameCtrl.text,
                    int.tryParse(costCtrl.text) ?? reward.cost);
              });
              Navigator.pop(context);
            },
            child: const Text("Save"),
          ),
        ],
      ),
    );
  }

  void createReward() {
    TextEditingController nameCtrl = TextEditingController();
    TextEditingController costCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Add New Reward"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
                controller: nameCtrl,
                decoration: const InputDecoration(labelText: "Reward Name")),
            TextField(
                controller: costCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: "Point Cost")),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Cancel")),
          ElevatedButton(
            onPressed: () {
              if (nameCtrl.text.isNotEmpty && costCtrl.text.isNotEmpty) {
                setState(() {
                  state.addReward(
                      nameCtrl.text, int.tryParse(costCtrl.text) ?? 0);
                });
                Navigator.pop(context);
              }
            },
            child: const Text("Create"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const SectionHeader(title: "Rewards Setup & Redemption"),
            ElevatedButton.icon(
              onPressed: createReward,
              icon: const Icon(Icons.add),
              label: const Text("Add Reward"),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            ),
          ],
        ),
        ...state.rewards.map(
          (r) => Card(
            color: r.isActive ? Colors.white : Colors.grey.shade300,
            child: ListTile(
              title: Text("${r.name} ${!r.isActive ? '(Archived)' : ''}"),
              subtitle: Text("Cost: ${r.cost} pts"),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.edit, color: Colors.blue),
                    onPressed: () => editReward(r),
                  ),
                  IconButton(
                    icon: Icon(r.isActive ? Icons.archive : Icons.unarchive,
                        color: r.isActive ? Colors.red : Colors.green),
                    onPressed: () {
                      setState(() {
                        state.toggleRewardArchive(r);
                      });
                    },
                  ),
                  IconButton(
                    icon: const Icon(Icons.check_circle, color: Colors.amber),
                    onPressed: () => redeemReward(r),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/* ===========================
   LEADERBOARD CONTROL
=========================== */
class LeaderboardControl extends StatefulWidget {
  const LeaderboardControl({super.key});

  @override
  State<LeaderboardControl> createState() => _LeaderboardControlState();
}

class _LeaderboardControlState extends State<LeaderboardControl> {
  final AppState state = AppState.instance;
  String searchQuery = "";

  void adjustPoints(Student student, int delta) {
    setState(() {
      state.adjustPoints(student, delta);
    });
  }

  @override
  Widget build(BuildContext context) {
    final filtered = state.students.where((s) {
      final q = searchQuery.toLowerCase();
      return s.name.toLowerCase().contains(q) || s.id.toLowerCase().contains(q);
    }).toList();

    final sorted = [...filtered]..sort((a, b) => b.points.compareTo(a.points));

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const SectionHeader(title: "Leaderboard Control"),
        TextField(
          decoration: const InputDecoration(
            prefixIcon: Icon(Icons.search, color: Colors.deepPurple),
            hintText: "Search by student name or ID",
            border: OutlineInputBorder(),
          ),
          onChanged: (value) {
            setState(() {
              searchQuery = value;
            });
          },
        ),
        const SizedBox(height: 10),
        ...sorted.map(
          (s) => Card(
            child: ListTile(
              title: Text(s.name),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: s.pointLogs
                    .map((p) => Text("${p.type}: +${p.value}"))
                    .toList(),
              ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.remove, color: Colors.red),
                    onPressed: () => adjustPoints(s, -1),
                  ),
                  Text("${s.points} pts",
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                  IconButton(
                    icon: const Icon(Icons.add, color: Colors.green),
                    onPressed: () => adjustPoints(s, 1),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/* ===========================
   SYSTEM SETTINGS
=========================== */
class SystemSettings extends StatefulWidget {
  const SystemSettings({super.key});

  @override
  State<SystemSettings> createState() => _SystemSettingsState();
}

class _SystemSettingsState extends State<SystemSettings> {
  final AppState state = AppState.instance;
  DateTime? scheduledResetDate;
  bool weeklyResetEnabled = false;

  void checkScheduledReset() {
    final now = DateTime.now();
    if (weeklyResetEnabled &&
        scheduledResetDate != null &&
        now.isAfter(scheduledResetDate!)) {
      state.resetAllPoints();
      scheduledResetDate = scheduledResetDate!.add(const Duration(days: 7));
    }
  }

  @override
  Widget build(BuildContext context) {
    checkScheduledReset();

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const SectionHeader(title: "System Settings"),

        // Reset All Points
        Card(
          child: ListTile(
            leading: const Icon(Icons.star, color: Colors.orange),
            title: const Text("Reset All Points"),
            subtitle: const Text("Clears points for all students"),
            trailing: IconButton(
              icon: const Icon(Icons.refresh, color: Colors.deepPurple),
              onPressed: () {
                state.resetAllPoints();
              },
            ),
          ),
        ),
        const SizedBox(height: 10),

        // Scheduled Reset
        Card(
          child: ListTile(
            leading: const Icon(Icons.schedule, color: Colors.blue),
            title: const Text("Scheduled Reset"),
            subtitle: Text(scheduledResetDate == null
                ? "No date selected"
                : "Next reset: ${scheduledResetDate!.toLocal().toString().split(' ')[0]}"),
            trailing: IconButton(
              icon: const Icon(Icons.calendar_today),
              onPressed: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: scheduledResetDate ?? DateTime.now(),
                  firstDate: DateTime.now(),
                  lastDate: DateTime(2100),
                );
                if (picked != null) {
                  setState(() {
                    scheduledResetDate = picked;
                  });
                }
              },
            ),
          ),
        ),

        // Weekly Reset Switch
        Card(
          child: SwitchListTile(
            title: const Text("Enable Weekly Automatic Reset"),
            subtitle: const Text("Automatically reset points weekly"),
            value: weeklyResetEnabled,
            onChanged: (v) => setState(() => weeklyResetEnabled = v),
          ),
        ),
      ],
    );
  }
}

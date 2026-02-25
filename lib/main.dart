import 'package:flutter/material.dart';
import 'admin_login.dart';
import 'api_service.dart'; // <-- Connects to XAMPP backend

/* ===========================
   MAIN ENTRY
=========================== */
void main() {
  runApp(TrackAccessApp());
}

/* ===========================
   DATA MODELS
=========================== */
class Student {
  final String uid;
  final String id;
  final String name;
  int points;
  int visits;
  final List<PointLog> pointLogs;

  Student({
    required this.uid,
    required this.id,
    required this.name,
    this.points = 0,
    this.visits = 0,
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

  AttendanceLog(
      this.studentName,
      this.library,
      this.detail,
      this.time,
      );
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
    final uid = students[_scanIndex].uid;
    _scanIndex = (_scanIndex + 1) % students.length;
    return uid;
  }

  Student? authenticateUID(String uid) {
    try {
      return students.firstWhere((s) => s.uid == uid);
    } catch (_) {
      return null;
    }
  }

  bool logVisit(Student student, String library, String detail, {int points = 5}) {
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

  /* ===========================
     STATISTICS
  ============================ */

  int todayVisits() {
    final now = DateTime.now();
    return visitLogs.where((l) =>
        l.time.year == now.year &&
        l.time.month == now.month &&
        l.time.day == now.day).length;
  }

  int thisMonthVisits() {
    final now = DateTime.now();
    return visitLogs.where((l) =>
        l.time.year == now.year &&
        l.time.month == now.month).length;
  }

  int totalVisits() => visitLogs.length;
}

/* ===========================
   MAIN APP
=========================== */
class TrackAccessApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: "TrackAccess Library System",
      theme: ThemeData(
        primarySwatch: Colors.deepPurple,
        scaffoldBackgroundColor: const Color(0xFFF4F1FA),
        cardTheme: const CardThemeData(
          elevation: 4,
          margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(16)),
          ),
        ),
      ),
      home: MainLayout(),
    );
  }
}

/* ===========================
   MAIN LAYOUT
=========================== */
class MainLayout extends StatefulWidget {
  @override
  State<MainLayout> createState() => _MainLayoutState();
}

class _MainLayoutState extends State<MainLayout> {
  Widget currentPage = StudentModule();
  String pageTitle = "Student Module";

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
            const DrawerHeader(
              decoration: BoxDecoration(color: Colors.deepPurple),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.local_library, color: Colors.white, size: 40),
                  SizedBox(height: 12),
                  Text("TrackAccess",
                      style: TextStyle(color: Colors.white, fontSize: 22)),
                  Text("Library Attendance System",
                      style: TextStyle(color: Colors.white70)),
                ],
              ),
            ),
            ListTile(
              leading: const Icon(Icons.school),
              title: const Text("Student Module"),
              onTap: () => switchPage("Student Module", StudentModule()),
            ),
            AnimatedBuilder(
              animation: state,
              builder: (context, _) {
                return ExpansionTile(
                  leading: const Icon(Icons.admin_panel_settings),
                  title: const Text("Admin Module"),
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
                            onTap: () =>
                                switchPage("Student Management", StudentManagement()),
                          ),
                          ListTile(
                            leading: const Icon(Icons.analytics),
                            title: const Text("Attendance Analytics"),
                            onTap: () =>
                                switchPage("Attendance Analytics", AttendanceAnalytics()),
                          ),
                          ListTile(
                            leading: const Icon(Icons.leaderboard),
                            title: const Text("Leaderboard Control"),
                            onTap: () =>
                                switchPage("Leaderboard Control", LeaderboardControl()),
                          ),
                          ListTile(
                            leading: const Icon(Icons.settings),
                            title: const Text("System Settings"),
                            onTap: () =>
                                switchPage("System Settings", SystemSettings()),
                          ),
                        ]
                      : [],
                );
              },
            ),
            // ================= Logout Button =================
            if (state.isAdminLoggedIn) ...[
              const Divider(),
              ListTile(
                leading: const Icon(Icons.logout, color: Colors.redAccent),
                title: const Text(
                  "Logout",
                  style: TextStyle(color: Colors.redAccent),
                ),
                onTap: () {
                  state.logoutAdmin(); // Reset admin login
                  switchPage("Student Module", StudentModule());
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

  @override
  void initState() {
    super.initState();
    controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
  }

  void scanCard() async {
    final uid = state.simulateRFIDScan();
    final student = state.authenticateUID(uid);

    setState(() {
      if (student == null) {
        message = "Invalid Card.\nContact librarian.";
      } else {
        final success = state.logVisit(student, selectedLibrary, selectedDetail);

        message = success
            ? "Welcome ${student.name}\nPoints: ${student.points}\n($selectedLibrary - $selectedDetail)"
            : "Already logged today";
      }

      controller.forward(from: 0);
    });
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
                    DropdownButton<String>(
                      value: selectedLibrary,
                      items: [
                        "College Library",
                        "Law Library",
                        "Medical Library",
                        "IBED Library"
                      ]
                          .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                          .toList(),
                      onChanged: (v) {
                        setState(() {
                          selectedLibrary = v!;
                          selectedDetail = selectedLibrary == "College Library"
                              ? "PC"
                              : selectedLibrary == "Law Library"
                                  ? "Discussion Room"
                                  : "Entry";
                        });
                      },
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
    final sorted = [...state.students]..sort((a, b) => b.points.compareTo(a.points));
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
              MaterialPageRoute(builder: (_) => MainLayout()),
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

    return GridView.count(
      shrinkWrap: true,
      crossAxisCount: 2,
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      physics: const NeverScrollableScrollPhysics(),
      children: [
        _statCard("Today's Visits", state.todayVisits(), Icons.today),
        _statCard("This Month", state.thisMonthVisits(), Icons.calendar_month),
        _statCard("Total Visits", state.totalVisits(), Icons.history),
        _statCard("Total Students", state.students.length, Icons.people),
      ],
    );
  }

  static Widget _statCard(String title, int value, IconData icon) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 36, color: Colors.deepPurple),
            const SizedBox(height: 12),
            Text(title),
            const SizedBox(height: 8),
            Text(
              value.toString(),
              style: const TextStyle(
                  fontSize: 22, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }
}

/* ===========================
   STUDENT MANAGEMENT
=========================== */
class StudentManagement extends StatelessWidget {
  final AppState state = AppState.instance;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const SectionHeader(title: "Student Management"),
        ...state.students.map(
          (s) => Card(
            child: ListTile(
              title: Text(s.name),
              subtitle: Text("ID: ${s.id} | Points: ${s.points}"),
              trailing: IconButton(
                icon: const Icon(Icons.refresh,
                    color: Colors.deepPurple),
                onPressed: () => state.resetStudentPoints(s),
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
  @override
  State<AttendanceAnalytics> createState() =>
      _AttendanceAnalyticsState();
}

class _AttendanceAnalyticsState
    extends State<AttendanceAnalytics> {
  final AppState state = AppState.instance;
  String selectedLibrary = "College Library";

  int count(String library, [String? detail]) {
    return state.visitLogs.where((l) {
      if (detail == null) return l.library == library;
      return l.library == library && l.detail == detail;
    }).length;
  }

  @override
  Widget build(BuildContext context) {
    final logs = state.visitLogs
        .where((l) => l.library == selectedLibrary)
        .toList()
        .reversed
        .take(10);

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const SectionHeader(title: "Attendance Analytics"),

        Wrap(
          spacing: 8,
          children: [
            libraryChip("College Library"),
            libraryChip("Law Library"),
            libraryChip("Medical Library"),
            libraryChip("IBED Library"),
          ],
        ),

        const SizedBox(height: 20),

        statCard("Total Usage", count(selectedLibrary)),

        if (selectedLibrary == "College Library")
          statCard("PC Usage", count(selectedLibrary, "PC")),

        if (selectedLibrary == "Law Library")
          statCard("Discussion Room Usage",
              count(selectedLibrary, "Discussion Room")),

        const SizedBox(height: 20),
        const SectionHeader(title: "Recent Check ins"),

        ...logs.map(
          (l) => Card(
            child: ListTile(
              title: Text(l.studentName),
              subtitle: Text("${l.library} • ${l.detail}"),
              trailing: Text(
                  "${l.time.hour}:${l.time.minute.toString().padLeft(2, '0')}"),
            ),
          ),
        ),
      ],
    );
  }

  Widget libraryChip(String name) {
    final selected = selectedLibrary == name;
    return ChoiceChip(
      label: Text(name),
      selected: selected,
      selectedColor: Colors.deepPurple,
      labelStyle: TextStyle(
          color: selected ? Colors.white : Colors.black),
      onSelected: (_) =>
          setState(() => selectedLibrary = name),
    );
  }

  Widget statCard(String title, int value) {
    return Card(
      child: ListTile(
        leading: const Icon(Icons.analytics,
            color: Colors.deepPurple),
        title: Text(title),
        trailing: Text(
          value.toString(),
          style: const TextStyle(
              fontSize: 20, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }
}

/* ===========================
   LEADERBOARD CONTROL
=========================== */
class LeaderboardControl extends StatelessWidget {
  final AppState state = AppState.instance;

  @override
  Widget build(BuildContext context) {
    final sorted = [...state.students]
      ..sort((a, b) => b.points.compareTo(a.points));

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const SectionHeader(title: "Leaderboard Control"),
        ...sorted.map(
          (s) => Card(
            child: ListTile(
              title: Text(s.name),
              subtitle: Column(
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: s.pointLogs
                    .map((p) =>
                        Text("${p.type}: +${p.value}"))
                    .toList(),
              ),
              trailing: Text("${s.points} pts"),
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
class SystemSettings extends StatelessWidget {
  final AppState state = AppState.instance;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const SectionHeader(title: "System Settings"),
        Card(
          child: ListTile(
            title: const Text("Reset Daily Attendance"),
            trailing: IconButton(
              icon: const Icon(Icons.refresh,
                  color: Colors.deepPurple),
              onPressed: () =>
                  state.resetDailyAttendance(),
            ),
          ),
        ),
      ],
    );
  }
}
import 'dart:io';
import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_libserialport/flutter_libserialport.dart';
import 'admin_login.dart';
import 'api_service.dart'; // <-- Still here for potential sync, but we use SQLite
import 'database_service.dart';

// JMCFI Official Colors
const Color jmcIndigo = Color(0xFF4B0082);
const Color jmcGrape = Color(0xFF6C3BAA);
const Color jmcWisteria = Color(0xFFC9A0DC);
const Color jmcSunglow = Color(0xFFFFCC33);
const Color jmcGold = Color(0xFFFFD700);
const Color jmcSilver = Color(0xFFC0C0C0);
const Color jmcBronze = Color(0xFFCD7F32);

const List<String> jmcfiCourses = [
  "BS Nursing",
  "BS Medical Technology",
  "BS Radiologic Technology",
  "BS Pharmacy",
  "BS Biology",
  "B Early Childhood Education",
  "B Elementary Education",
  "B Secondary Education (English)",
  "B Secondary Education (Mathematics)",
  "B Secondary Education (Filipino)",
  "B Secondary Education (Social Studies)",
  "BTvTED - Tech-Voc Teacher Ed",
  "BS Accountancy",
  "BS Management Accounting",
  "BSBA - Financial Management",
  "BSBA - Marketing Management",
  "BSBA - Human Resource Management",
  "BS Entrepreneurship",
  "BS Tourism Management",
  "BS Criminology",
  "BSIT - Information Technology",
  "BSEMC - Ent. & Multimedia Computing",
  "BS Psychology",
  "BS Social Work",
  "BS Agriculture",
  "BS Civil Engineering (Construction)",
  "BS Civil Engineering (Structural)",
  "College of Law (Juris Doctor)",
  "College of Medicine",
  "Integrated Basic Education",
  "Caregiving NC II",
  "Health Care Services NC II",
  "Housekeeping NC II",
  "Computer Systems Servicing NC II",
  "Agricultural Crops Production NC II",
];

const List<String> yearLevels = [
  "1st Year",
  "2nd Year",
  "3rd Year",
  "4th Year",
];

/* ===========================
   MAIN ENTRY
=========================== */
final GlobalKey<ScaffoldMessengerState> globalMessengerKey = GlobalKey<ScaffoldMessengerState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  try {
    print("TrackAccess: Starting initialization...");
    final state = AppState.instance;
    print("TrackAccess: Loading students from database...");
    await state.loadStudents(); // Fetch initial data
    print("TrackAccess: Starting serial listener...");
    state.startSerialListener(); // Start listener for USB Serial scans
    print("TrackAccess: Initialization complete. Running app.");
    
    runApp(const TrackAccessApp());
  } catch (e, stack) {
    print("CRITICAL ERROR during TrackAccess startup: $e");
    print(stack);
    
    // Show a simple error app if initialization fails
    runApp(MaterialApp(
      home: Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, color: Colors.red, size: 60),
                const SizedBox(height: 16),
                const Text("Oops! TrackAccess couldn't start.", 
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Text(e.toString(), textAlign: TextAlign.center),
                const SizedBox(height: 16),
                const Text("Try running the app as Administrator or contact support.", 
                  style: TextStyle(fontStyle: FontStyle.italic)),
              ],
            ),
          ),
        ),
      ),
    ));
  }
}

/* ===========================
   DATA MODELS
=========================== */
class Student {
  String uid;
  String id;
  String name;
  String course;
  String yearLevel;
  int points;
  int visits;
  bool isActive;
  String currentStatus; // "Entry" or "Exit"
  final List<PointLog> pointLogs;

  Student({
    required this.uid,
    required this.id,
    required this.name,
    this.course = "N/A",
    this.yearLevel = "N/A",
    this.points = 0,
    this.visits = 0,
    this.isActive = true,
    this.currentStatus = "Exit", // Default to out of library
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

  Map<String, dynamic> toMap() => {
    'student_name': studentName,
    'library': library,
    'detail': detail,
    'created_at': time.toIso8601String(),
  };
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
  List<Student> students = [];
  List<AttendanceLog> visitLogs = [];
  final dbService = DatabaseService();

  Future<void> loadStudents() async {
    students = await dbService.getStudents();
    visitLogs = await dbService.getVisitLogs();
    rewards = await dbService.getRewards();

    // Initialize currentStatus for each student from their latest log
    for (var student in students) {
      final studentLogs = visitLogs.where((l) => l.studentName == student.name).toList();
      if (studentLogs.isNotEmpty) {
        // Logs are usually ordered by ID/Time, but let's ensure we get the latest
        studentLogs.sort((a, b) => b.time.compareTo(a.time));
        student.currentStatus = studentLogs.first.detail;
      }
    }
    
    notifyListeners();
  }

  List<Reward> rewards = [];
  String scanMessage = "Please tap your RFID card";

  // Scan Alert State for Professional Pop-ups
  String? lastScanResult; // "Success", "Wait", "Error", "Invalid", "Completed"
  String? lastScanName;
  String? lastScanAction; // "Entry", "Exit"
  String? lastScanUID;
  DateTime? lastScanTime;

  void _triggerScanAlert(String result, {String? name, String? action, String? uid}) {
    lastScanResult = result;
    lastScanName = name;
    lastScanAction = action;
    lastScanUID = uid;
    lastScanTime = DateTime.now();
    notifyListeners();

    // Auto-clear after 4 seconds
    Timer(const Duration(seconds: 4), () {
      if (lastScanTime != null && 
          DateTime.now().difference(lastScanTime!).inSeconds >= 4) {
        lastScanResult = null;
        notifyListeners();
      }
    });
  }

  Future<void> _processScan(String uid) async {
    try {
      // Record any scan (recognized or not) so it can be pulled during registration
      await dbService.insertScan(uid);

      final student = authenticateUID(uid);
      if (student != null) {
        final now = DateTime.now();
        // Get today's logs for this student
        final todaysLogs = visitLogs.where((l) => 
          l.studentName == student.name && 
          l.time.year == now.year && 
          l.time.month == now.month && 
          l.time.day == now.day
        ).toList();
        
        // Anti-spam cooldown (10 seconds)
        if (todaysLogs.isNotEmpty) {
          todaysLogs.sort((a,b) => a.time.compareTo(b.time));
          final lastScan = todaysLogs.last.time;
          if (now.difference(lastScan).inSeconds < 10) {
            scanMessage = "Wait before scanning again.";
            _triggerScanAlert("Wait", name: student.name);
            return;
          }
        }

        String nextStatus = (todaysLogs.length % 2 == 0) ? "Entry" : "Exit";
        
        final success = logVisit(student, "College Library", nextStatus);

        
        if (success) {
          scanMessage = (nextStatus == "Entry")
            ? "Welcome ${student.name}\nPoints: ${student.points}\n(Entry Logged)"
            : "Goodbye ${student.name}\n(Exit Logged)";
            
          _triggerScanAlert("Success", name: student.name, action: nextStatus);
        } else {
          scanMessage = "Scan Error for ${student.name}";
          _triggerScanAlert("Error", name: student.name);
        }
      } else {
        scanMessage = "Invalid Card: $uid\nContact librarian.";
        _triggerScanAlert("Invalid", uid: uid);
      }
    } catch (e) {
      print("TrackAccess Error during scan processing: $e");
    } finally {
      notifyListeners();
    }
  }

  /* ===========================
     USB SERIAL SCANNER
  ============================ */
  String usbStatus = "Scanning for USB Scanner...";
  String lastRawData = "No data yet";
  SerialPort? _activePort;
  StreamSubscription? _serialSub;
  final StringBuffer _serialBuffer = StringBuffer();
  Timer? _reconnectTimer;

  void startSerialListener() {
    print("TrackAccess: Starting serial listener...");
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer.periodic(const Duration(seconds: 4), (timer) {
      if (_activePort == null) {
        _scanForScanner();
      }
    });
    
    // Initial scan
    _scanForScanner();
  }

  void _scanForScanner() {
    try {
      final ports = SerialPort.availablePorts;
      if (ports.isEmpty) {
        usbStatus = "No USB Ports Found";
        notifyListeners();
        return;
      }

      for (final name in ports) {
        // Skip common internal/legacy ports
        final upperName = name.toUpperCase();
        if (upperName == "COM1" || upperName == "COM2") continue;

        final port = SerialPort(name);
        try {
          if (port.openReadWrite()) {
            print("TrackAccess: Attempting to connect to $name");
            
            // Set configuration
            final config = SerialPortConfig();
            config.baudRate = 115200;
            config.bits = 8;
            config.stopBits = 1;
            config.parity = SerialPortParity.none;
            config.setFlowControl(SerialPortFlowControl.none);
            port.config = config;

            _activePort = port;
            usbStatus = "Connected to $name";
            print("TrackAccess: Serial Connected on $name");
            notifyListeners();

            final reader = SerialPortReader(port);
            _serialSub = reader.stream.listen(
              (data) {
                try {
                  final raw = utf8.decode(data);
                  _serialBuffer.write(raw);
                  lastRawData = _serialBuffer.toString();
                  
                  // Keep buffer size reasonable
                  if (_serialBuffer.length > 1000) {
                     _serialBuffer.clear();
                  }

                  if (raw.contains('\n') || _serialBuffer.toString().contains('\n')) {
                    final content = _serialBuffer.toString();
                    final lines = content.split('\n');
                    
                    // The last element might be incomplete
                    _serialBuffer.clear();
                    _serialBuffer.write(lines.last);
                    
                    for (int i = 0; i < lines.length - 1; i++) {
                      final uid = lines[i].trim();
                      if (uid.isNotEmpty && uid.length >= 4) {
                         print("TrackAccess: Valid UID received: $uid");
                         _processScan(uid);
                      }
                    }
                  }
                  notifyListeners();
                } catch (e) {
                   print("TrackAccess: Serial decode error: $e");
                }
              },
              onDone: () {
                print("TrackAccess: Serial Stream Done");
                _handleDisconnect();
              },
              onError: (error) {
                print("TrackAccess: Serial Stream Error: $error");
                _handleDisconnect();
              },
            );
            return; // Exit loop after successful connection
          }
        } catch (e) {
          print("TrackAccess: Failed to open port $name: $e");
          port.close();
        }
      }
    } catch (e) {
      print("TrackAccess: Error during port scan: $e");
    }
  }

  void _handleDisconnect() {
    print("TrackAccess: Handling Serial disconnect...");
    _serialSub?.cancel();
    _serialSub = null;
    
    try {
      if (_activePort != null) {
        _activePort!.close();
      }
    } catch (e) {
      print("TrackAccess: Error closing port during disconnect: $e");
    }
    
    _activePort = null;
    usbStatus = "USB Disconnected (Retrying...)";
    notifyListeners();
  }

  void forceReconnect() {
    _handleDisconnect();
    startSerialListener();
  }


  /* ===========================
     ADMIN LOGIN (via API)
  ============================ */
  Future<bool> loginAdmin(String username, String password) async {
    // Local check for standalone version
    if (username == "admin" && password == "admin") {
      isAdminLoggedIn = true;
      notifyListeners();
      return true;
    }

    try {
      final success = await ApiService.login(username, password);
      isAdminLoggedIn = success;
      notifyListeners();
      return success;
    } catch (e) {
      print("Login failed: $e");
      return false;
    }
  }

  void logoutAdmin() {
    isAdminLoggedIn = false;
    notifyListeners();
  }

  /* ===========================
     RFID & VISIT METHODS
  ============================ */

  Student? authenticateUID(String uid) {
    String cleanId = uid.trim().toUpperCase();
    try {
      return students.firstWhere((s) => s.uid.trim().toUpperCase() == cleanId);
    } catch (_) {
      return null;
    }
  }

  bool logVisit(Student student, String library, String detail,
      {int points = 10}) {
    // We now allow multiple scans per day (Entry/Exit toggle)
    
    visitLogs.add(AttendanceLog(student.name, library, detail, DateTime.now()));
    student.currentStatus = detail;

    // Award 10 points for both Entry and Exit as requested
    student.points += points;
    
    // Only increment visit count on Entry to keep statistics accurate
    if (detail == "Entry") {
      student.visits++;
    }

    student.pointLogs.add(PointLog(
      type: "$library - $detail",
      value: points,
      time: DateTime.now(),
    ));
    
    dbService.logPoints(student.id, "$library - $detail", points);
    dbService.updateStudent(student.id, {
      'points': student.points,
      'visits': student.visits,
    });

    // Always log the visit/action to database
    dbService.logVisit(student.name, library, detail);

    notifyListeners();
    return true;
  }

  void resetDailyAttendance() {
    // Current Entry/Exit toggle logic handle this
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
  Future<void> registerStudent(String name, String id, String uid, String course, String yearLevel) async {
    final s = Student(uid: uid, id: id, name: name, course: course, yearLevel: yearLevel);
    await dbService.insertStudent(s);
    await loadStudents();
  }

  Future<void> updateStudent(Student s, String name, String id, String uid, {String? course, String? yearLevel}) async {
    final Map<String, dynamic> data = {
      'name': name,
      'rfid_uid': uid,
    };
    if (course != null) data['course'] = course;
    if (yearLevel != null) data['year_level'] = yearLevel;
    
    await dbService.updateStudent(s.id, data);
    await loadStudents();
  }

  Future<void> toggleStudentArchive(Student s) async {
    await dbService.updateStudent(s.id, {'is_active': s.isActive ? 0 : 1});
    await loadStudents();
  }

  Future<void> updateReward(Reward r, String name, int cost) async {
    final oldName = r.name;
    r.name = name;
    r.cost = cost;
    await dbService.updateReward(oldName, r);
    notifyListeners();
  }

  Future<void> toggleRewardArchive(Reward r) async {
    r.isActive = !r.isActive;
    await dbService.updateReward(r.name, r);
    notifyListeners();
  }

  Future<void> deleteReward(Reward r) async {
    rewards.remove(r);
    await dbService.deleteReward(r.name);
    notifyListeners();
  }

  Future<void> addReward(String name, int cost) async {
    final r = Reward(name, cost);
    rewards.add(r);
    await dbService.insertReward(r);
    notifyListeners();
  }

  void redeemReward(Student s, Reward r) {
    s.points -= r.cost;
    s.pointLogs.add(PointLog(
      type: "Redeemed: ${r.name}",
      value: -r.cost,
      time: DateTime.now(),
    ));

    // Send to Database
    dbService.logPoints(s.id, "Redeemed: ${r.name}", -r.cost);
    dbService.updateStudent(s.id, {'points': s.points});

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

    // Send to Database
    dbService.logPoints(student.id, delta > 0 ? "Manual Add" : "Manual Subtract", delta);
    dbService.updateStudent(student.id, {'points': student.points});

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

  /* ===========================
     ANALYTICS DATA (Pie Chart)
  ============================ */
  Map<String, int> getCourseDistribution() {
    Map<String, int> dist = {};
    for (var s in students) {
      if (s.course.isNotEmpty) {
        dist[s.course] = (dist[s.course] ?? 0) + 1;
      }
    }
    return dist;
  }
}

/* ===========================
   MAIN APP
=========================== */
class TrackAccessApp extends StatelessWidget {
  const TrackAccessApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      scaffoldMessengerKey: globalMessengerKey,
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
  }

  void openAdmin() async {
    final state = AppState.instance;

    if (!state.isAdminLoggedIn) {
      await Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => AdminLoginPage()),
      );
      setState(() {});
    }

    if (state.isAdminLoggedIn) {
      switchPage("Dashboard", AdminDashboard());
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = AppState.instance;

    // 1. ADMIN LAYOUT (Persistent Sidebar, No Drawer)
    if (state.isAdminLoggedIn) {
      return Scaffold(
        body: Row(
          children: [
            // Persistent Sidebar
            Container(
              width: 250,
              color: Colors.white,
              child: Column(
                children: [
                  _buildSidebarHeader(),
                  Expanded(
                    child: ListView(
                      padding: EdgeInsets.zero,
                      children: [
                        _sidebarItem("Dashboard", Icons.dashboard, AdminDashboard()),
                        _sidebarItem("Student Management", Icons.people, StudentManagement()),
                        _sidebarItem("Attendance Analytics", Icons.analytics, const AttendanceAnalytics()),
                        _sidebarItem("Leaderboard Control", Icons.leaderboard, const LeaderboardControl()),
                        _sidebarItem("Rewards", Icons.card_giftcard, RewardsModule()),
                        _sidebarItem("System Settings", Icons.settings, const SystemSettings()),
                        const Divider(height: 1),
                        ListTile(
                          dense: true,
                          leading: const Icon(Icons.school, color: Colors.deepPurple, size: 20),
                          title: const Text("Student View", style: TextStyle(fontSize: 13)),
                          onTap: () => switchPage("Student", const StudentModule()),
                        ),
                        ListTile(
                          dense: true,
                          leading: const Icon(Icons.logout, color: Colors.redAccent, size: 20),
                          title: const Text("Logout Admin", style: TextStyle(color: Colors.redAccent, fontSize: 13)),
                          onTap: () {
                            state.logoutAdmin();
                            switchPage("Student", const StudentModule());
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Container(width: 1, color: Colors.grey.shade300),
            Expanded(
              child: Scaffold(
                appBar: AppBar(
                  title: Text(pageTitle),
                  automaticallyImplyLeading: false, // No drawer icon in Admin
                ),
                body: currentPage,
              ),
            ),
          ],
        ),
      );
    }

    // 2. STUDENT LAYOUT (Standard Drawer)
    return Scaffold(
      appBar: AppBar(title: Text(pageTitle)),
      drawer: Drawer(
        width: 250,
        child: Column(
          children: [
            _buildSidebarHeader(),
            ListTile(
              dense: true,
              leading: const Icon(Icons.school, size: 20),
              title: const Text("Student", style: TextStyle(fontSize: 13)),
              selected: pageTitle == "Student",
              onTap: () => switchPage("Student", const StudentModule()),
            ),
            ListTile(
              dense: true,
              leading: const Icon(Icons.admin_panel_settings, size: 20),
              title: const Text("Admin", style: TextStyle(fontSize: 13)),
              onTap: openAdmin,
            ),
          ],
        ),
      ),
      body: currentPage,
    );
  }

  Widget _buildSidebarHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 25),
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
              Image.asset(
                'assets/logo.png',
                height: 50,
                errorBuilder: (context, error, stackTrace) =>
                    const Icon(Icons.account_balance,
                        color: Colors.white, size: 35),
              ),
              const SizedBox(width: 10),
              const Text("JMCFI",
                  style: TextStyle(
                      color: jmcSunglow,
                      fontFamily: 'Montserrat',
                      fontSize: 24,
                      fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 12),
          const Text("TrackAccess",
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w600)),
          const Text("Library Attendance",
              style: TextStyle(color: Colors.white70, fontSize: 12)),
        ],
      ),
    );
  }

  Widget _sidebarItem(String title, IconData icon, Widget page) {
    return ListTile(
      dense: true,
      visualDensity: const VisualDensity(vertical: -2),
      leading: Icon(icon, size: 20),
      title: Text(title, style: const TextStyle(fontSize: 13)),
      selected: pageTitle == title,
      onTap: () => switchPage(title, page),
      contentPadding: const EdgeInsets.symmetric(horizontal: 20),
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

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }



  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const SectionHeader(title: "Student Check in"),
        AnimatedBuilder(
          animation: state,
          builder: (context, _) => Column(
            children: [
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.usb,
                        color: state.usbStatus.contains("Connected")
                            ? Colors.green
                            : Colors.orange,
                        size: 14),
                    const SizedBox(width: 4),
                    Text(state.usbStatus,
                        style: TextStyle(
                            fontSize: 10,
                            color: state.usbStatus.contains("Connected")
                                ? Colors.green
                                : Colors.orange)),
                    if (!state.usbStatus.contains("Connected"))
                      IconButton(
                        icon: const Icon(Icons.refresh, size: 14, color: Colors.blue),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        onPressed: () => state.forceReconnect(),
                        tooltip: "Try Reconnect",
                      ),
                  ],
                ),
              ),
              if (state.lastRawData != "No data yet")
                Text("Raw Input: ${state.lastRawData}", 
                  style: const TextStyle(fontSize: 8, color: Colors.grey)),
            ],
          ),
        ),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                Image.asset(
                  'assets/logo.png',
                  height: 100,
                  errorBuilder: (context, error, stackTrace) =>
                      const Icon(Icons.nfc, size: 60, color: Colors.deepPurple),
                ),
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
                  ],
                ),
                const SizedBox(height: 20),
                AnimatedBuilder(
                  animation: state,
                  builder: (context, _) => AnimatedSwitcher(
                    duration: const Duration(milliseconds: 300),
                    child: Text(
                      state.scanMessage,
                      key: ValueKey<String>(state.scanMessage),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),
        const SectionHeader(title: "Live Leaderboard"),
        SizedBox(
          height: 400,
          child: AnimatedBuilder(
            animation: state,
            builder: (context, _) => Stack(
              children: [
                const LiveLeaderboard(),
                // Pop-out scan notification
                ScanAlertOverlay(state: state),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class ScanAlertOverlay extends StatelessWidget {
  final AppState state;
  const ScanAlertOverlay({super.key, required this.state});

  @override
  Widget build(BuildContext context) {
    if (state.lastScanResult == null) return const SizedBox.shrink();

    Color bgColor;
    IconData icon;
    String title;
    String subtitle;

    switch (state.lastScanResult) {
      case "Success":
        bgColor = Colors.green.shade600;
        icon = state.lastScanAction == "Entry"
            ? Icons.login_rounded
            : Icons.logout_rounded;
        title = state.lastScanAction == "Entry" ? "Welcome!" : "Goodbye!";
        subtitle = state.lastScanName ?? "";
        break;
      case "Wait":
        bgColor = Colors.orange.shade700;
        icon = Icons.timer_rounded;
        title = "Too Fast";
        subtitle = "Please wait a moment.";
        break;
      case "Completed":
        bgColor = Colors.blueGrey.shade700;
        icon = Icons.check_circle_outline;
        title = "Daily Limit";
        subtitle = "${state.lastScanName} is done for today.";
        break;
      case "Invalid":
        bgColor = Colors.red.shade700;
        icon = Icons.error_outline;
        title = "Unknown Card";
        subtitle = "UID: ${state.lastScanUID}\nContact Librarian";
        break;
      default:
        bgColor = Colors.grey;
        icon = Icons.info_outline;
        title = "Scan Received";
        subtitle = "";
    }

    return Positioned(
      top: 10,
      left: 10,
      right: 10,
      child: TweenAnimationBuilder<double>(
        key: ValueKey(state.lastScanTime),
        duration: const Duration(milliseconds: 500),
        tween: Tween(begin: 0.0, end: 1.0),
        curve: Curves.elasticOut,
        builder: (context, value, child) {
          return Transform.translate(
            offset: Offset(0, (1 - value) * -20),
            child: Opacity(
              opacity: value.clamp(0.0, 1.0),
              child: child,
            ),
          );
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.3),
                blurRadius: 15,
                offset: const Offset(0, 8),
              )
            ],
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    shape: BoxShape.circle),
                child: Icon(icon, color: Colors.white, size: 28),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(title,
                      style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 16)),
                    Text(subtitle,
                      style: const TextStyle(
                          color: Colors.white70, 
                          fontSize: 12,
                          fontWeight: FontWeight.w500)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/* ===========================
   LIVE LEADERBOARD
=========================== */
/* ===========================
   LIVE LEADERBOARD
=========================== */
class LiveLeaderboard extends StatelessWidget {
  const LiveLeaderboard({super.key});

  @override
  Widget build(BuildContext context) {
    final state = AppState.instance;

    return AnimatedBuilder(
      animation: state,
      builder: (context, _) {
        final sorted = [...state.students]
          ..sort((a, b) => b.points.compareTo(a.points));
        final maxPoints = sorted.isNotEmpty ? (sorted.first.points > 0 ? sorted.first.points : 1) : 1;

        return ListView.builder(
          itemCount: sorted.length,
          itemBuilder: (context, index) {
            final student = sorted[index];
            final rank = index + 1;

            Color rankColor;
            IconData rankIcon;
            double elevation = 2;
            
            if (rank == 1) {
              rankColor = jmcGold;
              rankIcon = Icons.emoji_events;
              elevation = 8;
            } else if (rank == 2) {
              rankColor = jmcSilver;
              rankIcon = Icons.emoji_events;
              elevation = 6;
            } else if (rank == 3) {
              rankColor = jmcBronze;
              rankIcon = Icons.emoji_events;
              elevation = 4;
            } else {
              rankColor = jmcIndigo.withOpacity(0.7);
              rankIcon = Icons.person;
            }

            return Container(
              key: ValueKey(student.uid),
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                gradient: rank <= 3 ? LinearGradient(
                  colors: [
                    rankColor.withOpacity(0.15),
                    Colors.white.withOpacity(0.05),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ) : null,
              ),
              child: Card(
                elevation: elevation,
                color: rank <= 3 ? Colors.white.withOpacity(0.95) : Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: rank <= 3 
                    ? BorderSide(color: rankColor.withOpacity(0.3), width: 2)
                    : BorderSide(color: Colors.grey.shade100),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Row(
                    children: [
                      // Rank Badge
                      _RankBadge(rank: rank, color: rankColor, icon: rankIcon),
                      const SizedBox(width: 16),
                      
                      // Student Info
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(
                                  student.name,
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: rank <= 3 ? FontWeight.w800 : FontWeight.w600,
                                    color: rank <= 3 ? jmcIndigo : Colors.black87,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Container(
                                  width: 8,
                                  height: 8,
                                  decoration: BoxDecoration(
                                    color: student.currentStatus == "Entry" ? Colors.green : Colors.grey.shade400,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(10),
                              child: LinearProgressIndicator(
                                value: student.points / maxPoints,
                                minHeight: 8,
                                backgroundColor: Colors.grey.shade200,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  rank <= 3 ? rankColor : jmcIndigo,
                                ),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              "${student.visits} visits • ${student.course}",
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.grey.shade600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      
                      const SizedBox(width: 12),
                      
                      // Points Display
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: rankColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          children: [
                            Text(
                              student.points.toString(),
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w900,
                                color: rankColor.withOpacity(0.9),
                              ),
                            ),
                            const Text(
                              "PTS",
                              style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                                color: Colors.grey,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class _RankBadge extends StatelessWidget {
  final int rank;
  final Color color;
  final IconData icon;

  const _RankBadge({required this.rank, required this.color, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.4),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Center(
        child: rank <= 3 
          ? Icon(icon, color: Colors.white, size: 24)
          : Text(
              "#$rank",
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
      ),
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
        AnimatedBuilder(
          animation: state,
          builder: (context, _) => Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              children: [
                Icon(Icons.usb,
                    color: state.usbStatus.contains("Connected")
                        ? Colors.green
                        : Colors.orange,
                    size: 18),
                const SizedBox(width: 8),
                Text(state.usbStatus,
                    style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: state.usbStatus.contains("Connected")
                            ? Colors.green
                            : Colors.orange)),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.refresh, size: 18),
                  onPressed: () => state.forceReconnect(),
                  tooltip: "Force Scanner Reconnect",
                ),
              ],
            ),
          ),
        ),
        const _AdminStatsGrid(),
        const SizedBox(height: 24),
        const CourseDistributionChart(),
        const SizedBox(height: 30),
      ],
    );
  }
}

class CourseDistributionChart extends StatelessWidget {
  const CourseDistributionChart({super.key});

  @override
  Widget build(BuildContext context) {
    final state = AppState.instance;
    return AnimatedBuilder(
      animation: state,
      builder: (context, _) {
        final data = state.getCourseDistribution();
        if (data.isEmpty) {
          return const Card(
            child: Padding(
              padding: EdgeInsets.all(40),
              child: Center(child: Text("Register students to see distribution analytics.")),
            ),
          );
        }

        final total = data.values.fold(0, (sum, val) => sum + val);
        final sortedKeys = data.keys.toList()..sort((a, b) => data[b]!.compareTo(data[a]!));

        const colors = [
          jmcIndigo,
          jmcGrape,
          jmcSunglow,
          Colors.cyan,
          Colors.pinkAccent,
          Colors.orangeAccent,
          Colors.teal,
          Colors.blueAccent,
        ];

        return Card(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("DEMOGRAPHICS",
                    style: TextStyle(
                        fontSize: 12,
                        letterSpacing: 1.2,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey)),
                const Text("Course Distribution",
                    style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: jmcIndigo)),
                const SizedBox(height: 24),
                Row(
                  children: [
                    SizedBox(
                      height: 180,
                      width: 180,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          CustomPaint(
                            size: const Size(180, 180),
                            painter: DonutChartPainter(
                              data: data,
                              sortedKeys: sortedKeys,
                              colors: colors,
                              total: total,
                            ),
                          ),
                          Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Text("TOTAL",
                                  style: TextStyle(
                                      fontSize: 10,
                                      color: Colors.grey,
                                      letterSpacing: 1,
                                      fontWeight: FontWeight.bold)),
                              Text("$total",
                                  style: const TextStyle(
                                      fontSize: 32,
                                      fontWeight: FontWeight.w900,
                                      color: jmcIndigo)),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 40),
                    Expanded(
                      child: Column(
                        children: sortedKeys.asMap().entries.map((entry) {
                          final idx = entry.key;
                          final course = entry.value;
                          final count = data[course]!;
                          final percent = (count / total * 100).toStringAsFixed(1);
                          final color = colors[idx % colors.length];

                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 6),
                            child: Row(
                              children: [
                                Container(
                                  width: 10,
                                  height: 10,
                                  decoration: BoxDecoration(
                                      color: color, shape: BoxShape.circle),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(course,
                                      style: const TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w500,
                                          color: Colors.black87),
                                      overflow: TextOverflow.ellipsis),
                                ),
                                Text("$count",
                                    style: const TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.bold,
                                        color: jmcIndigo)),
                                SizedBox(
                                  width: 45,
                                  child: Text(" $percent%",
                                      textAlign: TextAlign.right,
                                      style: const TextStyle(
                                          fontSize: 11, color: Colors.grey)),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class DonutChartPainter extends CustomPainter {
  final Map<String, int> data;
  final List<String> sortedKeys;
  final List<Color> colors;
  final int total;

  DonutChartPainter(
      {required this.data,
      required this.sortedKeys,
      required this.colors,
      required this.total});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;
    final rect = Rect.fromCircle(center: center, radius: radius);
    const strokeWidth = 32.0;

    double startAngle = -1.5708;

    for (int i = 0; i < sortedKeys.length; i++) {
      final key = sortedKeys[i];
      final sweepAngle = (data[key]! / total) * 6.283185;

      final paint = Paint()
        ..color = colors[i % colors.length]
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round;

      double drawSweep = sweepAngle;
      if (sortedKeys.length > 1) {
        drawSweep = sweepAngle - 0.15;
      }

      canvas.drawArc(rect, startAngle + 0.07, drawSweep, false, paint);
      startAngle += sweepAngle;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

/* ===========================
   ADMIN STATS GRID
=========================== */
class _AdminStatsGrid extends StatelessWidget {
  const _AdminStatsGrid();

  @override
  Widget build(BuildContext context) {
    final state = AppState.instance;

    return AnimatedBuilder(
      animation: state,
      builder: (context, _) => Wrap(
        spacing: 16,
        runSpacing: 16,
        alignment: WrapAlignment.start,
        children: [
          _statCard("Today's Visits", state.todayVisits(), Icons.today),
          _statCard("This Month", state.thisMonthVisits(), Icons.calendar_month),
          _statCard("Total Visits", state.totalVisits(), Icons.history),
          _statCard("Total Students", state.students.length, Icons.people),
        ],
      ),
    );
  }

  static Widget _statCard(String title, int value, IconData icon) {
    return Container(
      width: 220,
      height: 165,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: jmcIndigo.withOpacity(0.08),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
        border: Border.all(color: jmcIndigo.withOpacity(0.1)),
      ),
      child: Stack(
        children: [
          Positioned(
            right: -20,
            top: -20,
            child: Icon(
              icon,
              size: 100,
              color: jmcIndigo.withOpacity(0.03),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: jmcIndigo.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(icon, size: 24, color: jmcIndigo),
                    ),
                    const Spacer(),
                  ],
                ),
                const Spacer(),
                Text(
                  value.toString(),
                  style: const TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: jmcIndigo,
                    letterSpacing: -1,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  title.toUpperCase(),
                  style: const TextStyle(
                    fontSize: 12,
                    color: Colors.black54,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.2,
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
    TextEditingController uidCtrl = TextEditingController(text: student.uid);
    String? selectedCourse = jmcfiCourses.contains(student.course) ? student.course : null;
    String? selectedYear = yearLevels.contains(student.yearLevel) ? student.yearLevel : null;

    showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text("Edit Student"),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                    controller: nameCtrl,
                    decoration: const InputDecoration(labelText: "Full Name")),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: selectedCourse,
                  decoration: const InputDecoration(labelText: "Course"),
                  items: jmcfiCourses.map((c) => DropdownMenuItem(value: c, child: Text(c, style: const TextStyle(fontSize: 12)))).toList(),
                  onChanged: (val) => setDialogState(() => selectedCourse = val),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: selectedYear,
                  decoration: const InputDecoration(labelText: "Year Level"),
                  items: yearLevels.map((y) => DropdownMenuItem(value: y, child: Text(y))).toList(),
                  onChanged: (val) => setDialogState(() => selectedYear = val),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                          controller: uidCtrl,
                          decoration: const InputDecoration(labelText: "RFID UID")),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: const Icon(Icons.nfc_rounded, color: jmcIndigo),
                      tooltip: "Get Latest Scan",
                      onPressed: () async {
                        final uid = await DatabaseService().getLatestScan();
                        if (uid != null) {
                          uidCtrl.text = uid;
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text("No recent scan found.")),
                          );
                        }
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                const Text(
                  "Tip: Tap the NFC icon to pull the UID from the physical scanner.",
                  style: TextStyle(fontSize: 10, color: Colors.grey),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text("Cancel")),
            ElevatedButton(
              onPressed: () {
                setState(() {
                  state.updateStudent(
                      student, nameCtrl.text, uidCtrl.text, uidCtrl.text,
                      course: selectedCourse, yearLevel: selectedYear);
                });
                Navigator.pop(context);
              },
              child: const Text("Save"),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionBtn({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: state,
      builder: (context, _) {
        final filteredStudents = state.students.where((s) {
          final q = searchQuery.toLowerCase();
          return s.name.toLowerCase().contains(q) ||
              s.id.toLowerCase().contains(q);
        }).toList();

        return ListView(
          padding: const EdgeInsets.all(20),
          children: [
            const SectionHeader(title: "Student Management"),
            Row(
              children: [
                Expanded(
                  child: TextField(
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
                ),
                const SizedBox(width: 12),
                ElevatedButton.icon(
                  onPressed: () => _showRegisterDialog(),
                  icon: const Icon(Icons.person_add_alt_1_rounded),
                  label: const Text("Register"),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            ...filteredStudents.map(
              (s) => Container(
                margin: const EdgeInsets.symmetric(vertical: 6),
                decoration: BoxDecoration(
                  color: s.isActive ? Colors.white : Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: s.isActive
                        ? jmcIndigo.withOpacity(0.2)
                        : Colors.grey.shade300,
                  ),
                  boxShadow: [
                    if (s.isActive)
                      BoxShadow(
                        color: jmcIndigo.withOpacity(0.05),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      )
                  ],
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 24,
                        backgroundColor: s.isActive
                            ? jmcIndigo.withOpacity(0.1)
                            : Colors.grey.shade300,
                        child: Text(
                          s.name.isNotEmpty ? s.name[0].toUpperCase() : "?",
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: s.isActive ? jmcIndigo : Colors.grey,
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              s.name,
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: s.isActive ? Colors.black87 : Colors.grey,
                                decoration:
                                    s.isActive ? null : TextDecoration.lineThrough,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              "UID: ${s.uid}",
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.grey.shade600,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              "Points: ${s.points}  •  Visits: ${s.visits}",
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: jmcIndigo,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _buildActionBtn(
                            icon: Icons.edit_rounded,
                            label: "Edit",
                            color: Colors.blue.shade700,
                            onTap: () => editStudent(s),
                          ),
                          const SizedBox(width: 8),
                          _buildActionBtn(
                            icon: s.isActive
                                ? Icons.archive_rounded
                                : Icons.unarchive_rounded,
                            label: s.isActive ? "Archive" : "Restore",
                            color: s.isActive ? Colors.red.shade600 : Colors.green.shade600,
                            onTap: () async {
                              final msg = s.isActive ? "Archiving will hide the student from the active list. Proceed?" : "Restore this student to the active list?";
                              final confirmed = await showDialog<bool>(
                                context: context,
                                builder: (ctx) => AlertDialog(
                                  title: Text(s.isActive ? "Archive Student" : "Restore Student"),
                                  content: Text(msg),
                                  actions: [
                                    TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("Cancel")),
                                    ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: Text(s.isActive ? "Archive" : "Restore")),
                                  ],
                                ),
                              );
                              if (confirmed == true) {
                                await state.toggleStudentArchive(s);
                              }
                            },
                          ),
                          const SizedBox(width: 8),
                          _buildActionBtn(
                            icon: Icons.refresh_rounded,
                            label: "Reset",
                            color: jmcIndigo,
                            onTap: () async {
                              final confirmed = await showDialog<bool>(
                                context: context,
                                builder: (ctx) => AlertDialog(
                                  title: const Text("Reset Points"),
                                  content: Text("Are you sure you want to reset points for ${s.name}?"),
                                  actions: [
                                    TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("Cancel")),
                                    ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text("Reset")),
                                  ],
                                ),
                              );
                              if (confirmed == true) {
                                state.resetStudentPoints(s);
                              }
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  void _showRegisterDialog() async {
    final draft = await state.dbService.loadDraft('register_student');
    
    TextEditingController nameCtrl = TextEditingController(text: draft?['name'] ?? "");
    TextEditingController uidCtrl = TextEditingController(text: draft?['uid'] ?? "");
    String? selectedCourse = draft?['course'];
    String? selectedYear = draft?['year'];

    void updateDraft() {
      state.dbService.saveDraft('register_student', {
        'name': nameCtrl.text,
        'uid': uidCtrl.text,
        'course': selectedCourse,
        'year': selectedYear,
      });
    }

    final dialogOpenTime = DateTime.now();
    showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text("Register New Student"),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                    controller: nameCtrl,
                    onChanged: (_) => updateDraft(),
                    decoration: const InputDecoration(labelText: "Full Name *")),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: selectedCourse,
                  decoration: const InputDecoration(labelText: "Course *"),
                  items: jmcfiCourses.map((c) => DropdownMenuItem(value: c, child: Text(c, style: const TextStyle(fontSize: 12)))).toList(),
                  hint: const Text("Select Course"),
                  onChanged: (val) {
                    setDialogState(() => selectedCourse = val);
                    updateDraft();
                  },
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: selectedYear,
                  decoration: const InputDecoration(labelText: "Year Level *"),
                  items: yearLevels.map((y) => DropdownMenuItem(value: y, child: Text(y))).toList(),
                  hint: const Text("Select Year Level"),
                  onChanged: (val) {
                    setDialogState(() => selectedYear = val);
                    updateDraft();
                  },
                ),
                const SizedBox(height: 12),
                // AUTOMATIC AUTO-FILL UID on Scan
                AnimatedBuilder(
                  animation: state,
                  builder: (context, _) {
                    // Automatically fill UID if scanned while dialog is open!
                    if (state.lastScanUID != null &&
                        state.lastScanTime != null &&
                        state.lastScanTime!.isAfter(dialogOpenTime)) {
                      if (uidCtrl.text != state.lastScanUID) {
                        // Use postFrameCallback to avoid modifying state during build
                        WidgetsBinding.instance.addPostFrameCallback((_) {
                           uidCtrl.text = state.lastScanUID!;
                           updateDraft();
                           setDialogState(() {}); // Ensure the UI reflects the change
                        });
                      }
                    }

                    return Row(
                      children: [
                        Expanded(
                          child: TextField(
                              controller: uidCtrl,
                              readOnly: true,
                              decoration: const InputDecoration(
                                labelText: "RFID UID (Auto-Fill) *",
                                hintText: "Please tap the student's RFID card...",
                                floatingLabelBehavior: FloatingLabelBehavior.always,
                              )),
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          icon: const Icon(Icons.refresh_rounded, color: jmcIndigo),
                          tooltip: "Manual Refresh",
                          onPressed: () async {
                            final uid = await DatabaseService().getLatestScan();
                            if (uid != null) {
                              setDialogState(() => uidCtrl.text = uid);
                              updateDraft();
                            }
                          },
                        ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 12),
                const Text(
                  "Tip: Tap the NFC icon to pull the UID from the physical scanner.",
                  style: TextStyle(fontSize: 10, color: Colors.grey),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text("Cancel")),
            OutlinedButton(
              onPressed: () async {
                if (nameCtrl.text.trim().isEmpty || 
                    uidCtrl.text.trim().isEmpty || 
                    selectedCourse == null || 
                    selectedYear == null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text("All fields are required! (Name, UID, Course, and Year)"),
                      backgroundColor: Colors.red,
                    ),
                  );
                  return;
                }

                // Prevent duplicate UID
                if (state.students.any((s) => s.uid == uidCtrl.text)) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text("Registration Failed: This RFID UID is already in the system!"),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                  return;
                }

                await state.registerStudent(
                    nameCtrl.text, uidCtrl.text, uidCtrl.text, 
                    selectedCourse ?? "N/A", selectedYear ?? "N/A");
                await state.dbService.clearDraft('register_student');
                
                // Clear fields for the next student
                nameCtrl.clear();
                uidCtrl.clear();
                setDialogState(() {
                  selectedCourse = null;
                  selectedYear = null;
                });

                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("Student registered. You can add another.")),
                  );
                }
              },
              child: const Text("Register & Add Another"),
            ),
            ElevatedButton(
              onPressed: () async {
                if (nameCtrl.text.trim().isEmpty || 
                    uidCtrl.text.trim().isEmpty || 
                    selectedCourse == null || 
                    selectedYear == null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text("All fields are required! (Name, UID, Course, and Year)"),
                      backgroundColor: Colors.red,
                    ),
                  );
                  return;
                }

                // Prevent duplicate UID
                if (state.students.any((s) => s.uid == uidCtrl.text)) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text("Registration Failed: This RFID UID is already in the system!"),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                  return;
                }

                await state.registerStudent(
                    nameCtrl.text, uidCtrl.text, uidCtrl.text, 
                    selectedCourse ?? "N/A", selectedYear ?? "N/A");
                await state.dbService.clearDraft('register_student');
                if (context.mounted) {
                  Navigator.pop(context);
                }
              },
              child: const Text("Register & Close"),
            ),
          ],
        ),
      ),
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
    return AnimatedBuilder(
      animation: state,
      builder: (context, _) {
        final recentLogs = state.visitLogs
            .where((l) => l.library == selectedLibrary)
            .toList()
            .reversed
            .take(10);

    final filteredStudents = state.students.where((s) {
      final q = searchQuery.toLowerCase();
      return s.name.toLowerCase().contains(q) || s.id.toLowerCase().contains(q);
    }).toList();

    // Generate Master Event Log
    final List<({DateTime time, String name, String id, String action, String detail})> allEvents = [];
    final q = searchQuery.toLowerCase();

    for (final s in state.students) {
      if (q.isNotEmpty && !s.name.toLowerCase().contains(q) && !s.id.toLowerCase().contains(q)) continue;
      
      for (final pLog in s.pointLogs) {
        allEvents.add((
          time: pLog.time,
          name: s.name,
          id: s.uid,
          action: pLog.value > 0 ? "Points Altered" : "Redeemed Reward",
          detail: "${pLog.type} (${pLog.value > 0 ? '+' : ''}${pLog.value} pts)"
        ));
      }
    }

    for (final vLog in state.visitLogs) {
      final student = state.students.where((s) => s.name == vLog.studentName).firstOrNull;
      if (student == null) continue;
      if (q.isNotEmpty && !student.name.toLowerCase().contains(q) && !student.id.toLowerCase().contains(q)) continue;
      
      allEvents.add((
        time: vLog.time,
        name: student.name,
        id: student.uid,
        action: "Library ${vLog.detail}",
        detail: vLog.library,
      ));
    }

    allEvents.sort((a, b) => b.time.compareTo(a.time));

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const SectionHeader(title: "Attendance Analytics"),
        const SizedBox(height: 10),

        Row(
          children: [
            Expanded(
              child: analyticsInfoCard(
                title: "Total Usage",
                value: count(selectedLibrary),
                icon: Icons.library_books_rounded,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: analyticsInfoCard(
                title: "Entries",
                value: count(selectedLibrary, "Entry"),
                icon: Icons.meeting_room_rounded,
              ),
            ),
          ],
        ),

        const SizedBox(height: 30),

        // Recent Check-ins
        const SectionHeader(title: "Recent Check-ins"),
        const SizedBox(height: 10),
        if (recentLogs.isEmpty)
          Container(
            padding: const EdgeInsets.all(30),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: const Center(
              child: Text(
                "No recent check-ins.",
                style: TextStyle(color: Colors.grey, fontSize: 16),
              ),
            ),
          )
        else
          ...recentLogs.map(
            (l) => Card(
              elevation: 0,
              margin: const EdgeInsets.symmetric(vertical: 4),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
                side: BorderSide(color: Colors.grey.shade200),
              ),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: jmcIndigo.withOpacity(0.1),
                  child: const Icon(Icons.person, color: jmcIndigo),
                ),
                title: Text(l.studentName,
                    style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text("${l.library} • ${l.detail}"),
                trailing: Text(
                  "${l.time.year}-${l.time.month.toString().padLeft(2, '0')}-${l.time.day.toString().padLeft(2, '0')} "
                  "${l.time.hour.toString().padLeft(2, '0')}:${l.time.minute.toString().padLeft(2, '0')}",
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                ),
              ),
            ),
          ).toList(),

        const SizedBox(height: 30),

        // Spreadsheet Section
        const SectionHeader(title: "Student Analytics Data"),
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: TextField(
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.search, color: jmcIndigo),
                  hintText: "Search by student name or ID...",
                  border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.symmetric(vertical: 0),
                ),
                onChanged: (value) {
                  setState(() {
                    searchQuery = value;
                  });
                },
              ),
            ),
            const SizedBox(width: 16),
            SizedBox(
              height: 48,
              child: ElevatedButton.icon(
                icon: const Icon(Icons.download_rounded, color: Colors.white),
                label: const Text(
                  "Export CSV",
                  style: TextStyle(
                      fontWeight: FontWeight.bold, color: Colors.white),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green.shade600,
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                onPressed: () => generateReport(filteredStudents),
              ),
            ),
          ],
        ),

        const SizedBox(height: 16),

        // Spreadsheet Table
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade300),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.02),
                blurRadius: 8,
                offset: const Offset(0, 4),
              )
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              headingRowColor: MaterialStateProperty.all(Colors.grey.shade50),
              columns: const [
                DataColumn(
                    label: Text("Student Name",
                        style: TextStyle(fontWeight: FontWeight.bold))),
                DataColumn(
                    label: Text("UID",
                        style: TextStyle(fontWeight: FontWeight.bold))),
                DataColumn(
                    label: Text("Course Year",
                        style: TextStyle(fontWeight: FontWeight.bold))),
                DataColumn(
                    label: Text("Points",
                        style: TextStyle(fontWeight: FontWeight.bold))),
                DataColumn(
                    label: Text("Visits",
                        style: TextStyle(fontWeight: FontWeight.bold))),
                DataColumn(
                    label: Text("Last Visit",
                        style: TextStyle(fontWeight: FontWeight.bold))),
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
                    DataCell(Text(s.uid)),
                    DataCell(Text("${s.course} ${s.yearLevel}")),
                    DataCell(Text(s.points.toString())),
                    DataCell(Text(s.visits.toString())),
                    DataCell(Text(lastCheckIn,
                        style: TextStyle(color: Colors.grey.shade700))),
                  ],
                );
              }).toList(),
            ),
          ),
        ),

        const SizedBox(height: 30),

        // Activity Logs Section
        const SectionHeader(title: "Activity Logs"),
        const SizedBox(height: 16),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade300),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.02),
                blurRadius: 8,
                offset: const Offset(0, 4),
              )
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              headingRowColor: MaterialStateProperty.all(Colors.grey.shade50),
              columns: const [
                DataColumn(
                    label: Text("Date & Time",
                        style: TextStyle(fontWeight: FontWeight.bold))),
                DataColumn(
                    label: Text("Student Name",
                        style: TextStyle(fontWeight: FontWeight.bold))),
                DataColumn(
                    label: Text("UID",
                        style: TextStyle(fontWeight: FontWeight.bold))),
                DataColumn(
                    label: Text("Action",
                        style: TextStyle(fontWeight: FontWeight.bold))),
                DataColumn(
                    label: Text("Details / Reward",
                        style: TextStyle(fontWeight: FontWeight.bold))),
              ],
              rows: allEvents.take(50).map((event) {
                final t = event.time;
                final timeStr = "${t.year}-${t.month.toString().padLeft(2, '0')}-${t.day.toString().padLeft(2, '0')} "
                    "${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}";

                return DataRow(
                  cells: [
                    DataCell(Text(timeStr, style: TextStyle(color: Colors.grey.shade700))),
                    DataCell(Text(event.name, style: const TextStyle(fontWeight: FontWeight.w500))),
                    DataCell(Text(event.id)),
                    DataCell(
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: event.action.contains("Redeem") 
                            ? Colors.orange.withOpacity(0.1) 
                            : event.action.contains("Entry")
                              ? Colors.green.withOpacity(0.1)
                              : Colors.blue.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          event.action,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: event.action.contains("Redeem") 
                              ? Colors.orange.shade800
                              : event.action.contains("Entry")
                                ? Colors.green.shade800
                                : Colors.blue.shade800,
                          ),
                        ),
                      ),
                    ),
                    DataCell(Text(event.detail)),
                  ],
                );
              }).toList(),
            ),
          ),
        ),
      ],
    );
      },
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
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: jmcIndigo.withOpacity(0.1)),
        boxShadow: [
          BoxShadow(
            color: jmcIndigo.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: jmcIndigo.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: jmcIndigo, size: 28),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey.shade600,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value.toString(),
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: jmcIndigo,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Helper for consistent 12-hour time formatting
  String _formatTime(DateTime t) {
    final hour12 = t.hour == 0 ? 12 : (t.hour > 12 ? t.hour - 12 : t.hour);
    final ampm = t.hour >= 12 ? 'PM' : 'AM';
    return "${hour12.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')} $ampm";
  }

  // Generate report
  Future<void> generateReport(List<Student> studentsToExport) async {
    final buffer = StringBuffer();
    buffer.write('\uFEFF'); // Add UTF-8 BOM for Excel visibility/encoding improvements
    
    final now = DateTime.now();
    final dateStr = "${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}";
    final timeStr = _formatTime(now);

    // CSS Styling for Professional Look
    buffer.write('''
<!DOCTYPE html>
<html>
<head>
<meta charset="UTF-8">
<title>TrackAccess Library Report</title>
<style>
  body { font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif; margin: 40px; color: #2c3e50; line-height: 1.6; }
  .header { border-bottom: 3px solid #4B0082; padding-bottom: 10px; margin-bottom: 30px; }
  h1 { color: #4B0082; margin: 0; font-size: 28px; }
  .subtitle { font-weight: bold; color: #7f8c8d; font-size: 16px; margin-top: 5px; }
  .timestamp { color: #95a5a6; font-size: 12px; font-style: italic; }
  
  h2 { color: #6C3BAA; margin-top: 40px; border-left: 5px solid #6C3BAA; padding-left: 15px; font-size: 20px; }
  
  table { width: 100%; border-collapse: collapse; margin: 20px 0; background: #fff; box-shadow: 0 1px 3px rgba(0,0,0,0.1); }
  th, td { border: 1px solid #ecf0f1; padding: 12px 15px; text-align: left; }
  th { background-color: #F8F4FF; color: #4B0082; font-weight: bold; text-transform: uppercase; font-size: 12px; letter-spacing: 0.5px; }
  tr:nth-child(even) { background-color: #fcfaff; }
  tr:hover { background-color: #f1f1f1; }
  
  .summary-container { display: flex; gap: 20px; flex-wrap: wrap; }
  .summary-box { border: 1px solid #DDD; padding: 15px; border-radius: 8px; min-width: 200px; background: #fdfdfd; }
  .summary-label { display: block; font-size: 11px; color: #7f8c8d; font-weight: bold; text-transform: uppercase; }
  .summary-value { display: block; font-size: 22px; color: #4B0082; font-weight: 800; }
  
  .badge { padding: 4px 8px; border-radius: 4px; font-size: 11px; font-weight: bold; }
  .entry { background: #e8f5e9; color: #2e7d32; }
  .exit { background: #ffebee; color: #c62828; }
  .points { color: #4B0082; font-weight: bold; }
</style>
</head>
<body>
  <div class="header">
    <h1>TRACKACCESS LIBRARY SYSTEM</h1>
    <div class="subtitle">OFFICIAL ANALYTICS & ACTIVITY REPORT</div>
    <div class="timestamp">Generated on: $dateStr at $timeStr</div>
  </div>

  <h2>REPORT SUMMARY</h2>
  <div class="summary-container">
    <div class="summary-box">
      <span class="summary-label">Total Students</span>
      <span class="summary-value">${studentsToExport.length}</span>
    </div>
    <div class="summary-box">
      <span class="summary-label">Active Students</span>
      <span class="summary-value">${studentsToExport.where((s) => s.isActive).length}</span>
    </div>
    <div class="summary-box">
      <span class="summary-label">Visits Today</span>
      <span class="summary-value">${state.todayVisits()}</span>
    </div>
    <div class="summary-box">
      <span class="summary-label">Total Points</span>
      <span class="summary-value">${studentsToExport.fold(0, (sum, s) => sum + s.points)}</span>
    </div>
  </div>

  <h2>STUDENT LIST SUMMARY</h2>
  <table>
    <thead>
      <tr>
        <th>Student Name</th>
        <th>Student ID</th>
        <th>Course</th>
        <th>Year Level</th>
        <th style="text-align: center;">Total Points</th>
        <th style="text-align: center;">Total Visits</th>
      </tr>
    </thead>
    <tbody>
''');

    for (var s in studentsToExport) {
      buffer.write('''
      <tr>
        <td><strong>${s.name}</strong></td>
        <td><code>${s.id}</code></td>
        <td>${s.course}</td>
        <td>${s.yearLevel}</td>
        <td style="text-align: center;" class="points">${s.points}</td>
        <td style="text-align: center;">${s.visits}</td>
      </tr>
''');
    }

    buffer.write('''
    </tbody>
  </table>

  <h2>DETAILED ACTIVITY LOGS</h2>
  <table>
    <thead>
      <tr>
        <th>Date</th>
        <th>Time</th>
        <th>Student Name</th>
        <th>Student ID</th>
        <th>Action</th>
        <th>Details/Reward</th>
      </tr>
    </thead>
    <tbody>
''');

    final List<({DateTime time, String name, String id, String action, String detail})> allEvents = [];
    
    for (var s in state.students) {
      if (!studentsToExport.contains(s)) continue;
      for (var pLog in s.pointLogs) {
        allEvents.add((
          time: pLog.time,
          name: s.name,
          id: s.id,
          action: pLog.value > 0 ? "Points Altered" : "Redeemed Reward",
          detail: "${pLog.type} (${pLog.value > 0 ? '+' : ''}${pLog.value} pts)"
        ));
      }
    }

    for (var vLog in state.visitLogs) {
      final student = state.students.where((s) => s.name == vLog.studentName).firstOrNull;
      if (student == null || !studentsToExport.contains(student)) continue;
      allEvents.add((
        time: vLog.time,
        name: vLog.studentName,
        id: student.id,
        action: "Library ${vLog.detail}",
        detail: vLog.library,
      ));
    }

    allEvents.sort((a, b) => b.time.compareTo(a.time));

    if (allEvents.isEmpty) {
      buffer.write('<tr><td colspan="6" style="text-align: center; color: #999;">No tracked activity found for this selection.</td></tr>');
    } else {
      for (var event in allEvents) {
        final t = event.time;
        final dStr = "${t.year}-${t.month.toString().padLeft(2, '0')}-${t.day.toString().padLeft(2, '0')}";
        final tStr = _formatTime(t);
        final statusClass = event.action.contains("Entry") ? "entry" : (event.action.contains("Exit") ? "exit" : "");
        
        buffer.write('''
      <tr>
        <td>$dStr</td>
        <td>$tStr</td>
        <td>${event.name}</td>
        <td><code>${event.id}</code></td>
        <td><span class="badge $statusClass">${event.action}</span></td>
        <td>${event.detail}</td>
      </tr>
''');
      }
    }

    buffer.write('''
    </tbody>
  </table>
</body>
</html>
''');

    try {
      String? selectedDirectory = await FilePicker.platform.getDirectoryPath();
      if (selectedDirectory == null) return; 

      final file = File('$selectedDirectory/Library_Report_${DateTime.now().millisecondsSinceEpoch}.xls');
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
        const SnackBar(content: Text("No active students have enough points for this reward.")),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (ctx) {
        String filterQuery = "";
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final filtered = eligibleStudents.where((s) {
              final q = filterQuery.toLowerCase();
              return s.name.toLowerCase().contains(q) ||
                  s.uid.toLowerCase().contains(q);
            }).toList();

            return Dialog(
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20)),
              child: Container(
                width: 500,
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "Redeem: ${reward.name}",
                                style: const TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold,
                                  color: jmcIndigo,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                "Select the student who is redeeming this reward. (Cost: ${reward.cost} pts)",
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () => Navigator.pop(context),
                        )
                      ],
                    ),
                    const SizedBox(height: 24),
                    TextField(
                      decoration: InputDecoration(
                        hintText: "Search student name or UID...",
                        prefixIcon: const Icon(Icons.search, color: jmcIndigo),
                        filled: true,
                        fillColor: Colors.grey.shade50,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: Colors.grey.shade300),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: Colors.grey.shade300),
                        ),
                      ),
                      onChanged: (val) {
                        setDialogState(() => filterQuery = val);
                      },
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      height: 350,
                      child: filtered.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.search_off_rounded,
                                      size: 48, color: Colors.grey.shade400),
                                  const SizedBox(height: 16),
                                  Text(
                                    "No matching active students found.",
                                    style: TextStyle(
                                        color: Colors.grey.shade600,
                                        fontSize: 16),
                                  ),
                                ],
                              ),
                            )
                          : ListView.builder(
                              itemCount: filtered.length,
                              itemBuilder: (ctx, i) {
                                final student = filtered[i];
                                return Container(
                                  margin:
                                      const EdgeInsets.symmetric(vertical: 4),
                                  decoration: BoxDecoration(
                                    border: Border.all(
                                        color: Colors.grey.shade200),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: ListTile(
                                    contentPadding: const EdgeInsets.symmetric(
                                        horizontal: 16, vertical: 4),
                                    leading: CircleAvatar(
                                      backgroundColor:
                                          jmcIndigo.withOpacity(0.1),
                                      child: Text(
                                          student.name[0].toUpperCase(),
                                          style: const TextStyle(
                                              color: jmcIndigo,
                                              fontWeight: FontWeight.bold)),
                                    ),
                                    title: Text(student.name,
                                        style: const TextStyle(
                                            fontWeight: FontWeight.bold)),
                                    subtitle: Text(
                                        "UID: ${student.uid} | Balance: ${student.points} pts"),
                                    trailing: ElevatedButton(
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.green,
                                        foregroundColor: Colors.white,
                                        shape: RoundedRectangleBorder(
                                            borderRadius:
                                                BorderRadius.circular(8)),
                                      ),
                                      onPressed: () {
                                        setState(() {
                                          state.redeemReward(student, reward);
                                        });
                                        Navigator.pop(context);
                                        ScaffoldMessenger.of(context)
                                            .showSnackBar(
                                          SnackBar(
                                            backgroundColor: Colors.green,
                                            content: Text(
                                                "Success: ${student.name} redeemed ${reward.name}!"),
                                          ),
                                        );
                                      },
                                      child: const Text("Select"),
                                    ),
                                  ),
                                );
                              },
                            ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
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

  void createReward() async {
    final draft = await state.dbService.loadDraft('create_reward');
    TextEditingController nameCtrl = TextEditingController(text: draft?['name'] ?? "");
    TextEditingController costCtrl = TextEditingController(text: draft?['cost'] ?? "");

    void updateDraft() {
      state.dbService.saveDraft('create_reward', {
        'name': nameCtrl.text,
        'cost': costCtrl.text,
      });
    }

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Add New Reward"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
                controller: nameCtrl,
                onChanged: (_) => updateDraft(),
                decoration: const InputDecoration(labelText: "Reward Name")),
            TextField(
                controller: costCtrl,
                onChanged: (_) => updateDraft(),
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: "Point Cost")),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Cancel")),
          ElevatedButton(
            onPressed: () async {
              if (nameCtrl.text.isNotEmpty && costCtrl.text.isNotEmpty) {
                await state.addReward(
                    nameCtrl.text, int.tryParse(costCtrl.text) ?? 0);
                await state.dbService.clearDraft('create_reward');
                if (mounted) setState(() {});
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
            const SectionHeader(title: "Rewards"),
            ElevatedButton.icon(
              onPressed: createReward,
              icon: const Icon(Icons.add),
              label: const Text("Add Reward"),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            ),
          ],
        ),
        ...state.rewards.map(
          (r) => Container(
            margin: const EdgeInsets.symmetric(vertical: 6),
            decoration: BoxDecoration(
              color: r.isActive ? Colors.white : Colors.grey.shade100,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: r.isActive
                    ? jmcIndigo.withOpacity(0.2)
                    : Colors.grey.shade300,
              ),
              boxShadow: [
                if (r.isActive)
                  BoxShadow(
                    color: jmcIndigo.withOpacity(0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  )
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: r.isActive
                          ? jmcSunglow.withOpacity(0.2)
                          : Colors.grey.shade300,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.card_giftcard_rounded,
                      color: r.isActive ? jmcSunglow : Colors.grey,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          r.name,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: r.isActive ? Colors.black87 : Colors.grey,
                            decoration:
                                r.isActive ? null : TextDecoration.lineThrough,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          "Cost: ${r.cost} pts",
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: jmcIndigo,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.edit_rounded,
                            color: Colors.blue),
                        tooltip: "Edit Reward",
                        onPressed: () => editReward(r),
                      ),
                      IconButton(
                        icon: Icon(
                          r.isActive
                              ? Icons.archive_rounded
                              : Icons.unarchive_rounded,
                          color: r.isActive ? Colors.red : Colors.green,
                        ),
                        tooltip: r.isActive ? "Archive" : "Restore",
                        onPressed: () {
                          setState(() {
                            state.toggleRewardArchive(r);
                          });
                        },
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete_outline_rounded,
                            color: Colors.red),
                        tooltip: "Delete Reward",
                        onPressed: () async {
                          final confirmed = await showDialog<bool>(
                            context: context,
                            builder: (ctx) => AlertDialog(
                              title: const Text("Delete Reward"),
                              content: Text("Are you sure you want to delete '${r.name}'? This action cannot be undone."),
                              actions: [
                                TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("Cancel")),
                                ElevatedButton(
                                  style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                                  onPressed: () => Navigator.pop(ctx, true), 
                                  child: const Text("Delete")
                                ),
                              ],
                            ),
                          );
                          if (confirmed == true) {
                            setState(() {
                              state.deleteReward(r);
                            });
                          }
                        },
                      ),
                      const SizedBox(width: 8),
                      if (r.isActive)
                        ElevatedButton.icon(
                          icon: const Icon(Icons.check_circle_rounded,
                              size: 18),
                          label: const Text("Redeem"),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: jmcIndigo,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 8),
                          ),
                          onPressed: () => redeemReward(r),
                        ),
                    ],
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
    return AnimatedBuilder(
      animation: state,
      builder: (context, _) {
        final filtered = state.students.where((s) {
          final q = searchQuery.toLowerCase();
          return s.name.toLowerCase().contains(q) || s.id.toLowerCase().contains(q);
        }).toList();

        final sorted = [...filtered]..sort((a, b) => b.points.compareTo(a.points));

        return ListView(
          padding: const EdgeInsets.all(20),
          children: [
            const SectionHeader(title: "Leaderboard Control"),
            const SizedBox(height: 10),
            TextField(
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search, color: jmcIndigo),
                hintText: "Search by student name or ID...",
                border: OutlineInputBorder(),
              ),
              onChanged: (value) {
                setState(() {
                  searchQuery = value;
                });
              },
            ),
            const SizedBox(height: 20),
            ...sorted.map(
              (s) => Container(
                margin: const EdgeInsets.symmetric(vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade300),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.03),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    )
                  ],
                ),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      CircleAvatar(
                        backgroundColor: jmcIndigo.withOpacity(0.1),
                        child: Text(
                          s.name[0].toUpperCase(),
                          style: const TextStyle(
                              color: jmcIndigo, fontWeight: FontWeight.bold),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              s.name,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              "UID: ${s.uid}",
                              style: TextStyle(color: Colors.grey.shade600),
                            ),
                            if (s.pointLogs.isNotEmpty) ...[
                              const SizedBox(height: 8),
                              Wrap(
                                spacing: 8,
                                children: s.pointLogs.take(2).map((p) {
                                  final isPositive = p.value > 0;
                                  return Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: isPositive
                                          ? Colors.green.withOpacity(0.1)
                                          : Colors.red.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Text(
                                      "${p.type}: ${isPositive ? '+' : ''}${p.value}",
                                      style: TextStyle(
                                        fontSize: 10,
                                        color:
                                            isPositive ? Colors.green : Colors.red,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  );
                                }).toList(),
                              ),
                            ]
                          ],
                        ),
                      ),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            decoration: BoxDecoration(
                              color: Colors.red.shade50,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: IconButton(
                              icon:
                                  const Icon(Icons.remove_rounded, color: Colors.red),
                              onPressed: () => adjustPoints(s, -1),
                              tooltip: "Subtract Point",
                            ),
                          ),
                          const SizedBox(width: 12),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 8),
                            decoration: BoxDecoration(
                              color: jmcSunglow.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              "${s.points} pts",
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                                color: jmcIndigo,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Container(
                            decoration: BoxDecoration(
                              color: Colors.green.shade50,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: IconButton(
                              icon:
                                  const Icon(Icons.add_rounded, color: Colors.green),
                              onPressed: () => adjustPoints(s, 1),
                              tooltip: "Add Point",
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        );
      },
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
        const SizedBox(height: 10),

        // Reset All Points
        Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade300),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.02),
                blurRadius: 8,
                offset: const Offset(0, 4),
              )
            ],
          ),
          child: ListTile(
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            leading: CircleAvatar(
              backgroundColor: Colors.orange.withOpacity(0.1),
              child: const Icon(Icons.star_rounded, color: Colors.orange),
            ),
            title: const Text("Reset All Points",
                style: TextStyle(fontWeight: FontWeight.bold)),
            subtitle: const Text("Clears points for all students"),
            trailing: IconButton(
              icon: const Icon(Icons.refresh_rounded, color: jmcIndigo),
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (_) => AlertDialog(
                    title: const Text("Confirm Global Reset"),
                    content: const Text(
                        "Are you sure you want to reset all points? This cannot be undone."),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text("Cancel"),
                      ),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red),
                        onPressed: () {
                          state.resetAllPoints();
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                                content: Text("All student points reset.")),
                          );
                        },
                        child: const Text("Reset"),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ),

        // Scheduled Reset
        Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade300),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.02),
                blurRadius: 8,
                offset: const Offset(0, 4),
              )
            ],
          ),
          child: ListTile(
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            leading: CircleAvatar(
              backgroundColor: Colors.blue.withOpacity(0.1),
              child: const Icon(Icons.schedule_rounded, color: Colors.blue),
            ),
            title: const Text("Scheduled Reset",
                style: TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text(scheduledResetDate == null
                ? "No date selected"
                : "Next reset: ${scheduledResetDate!.toLocal().toString().split(' ')[0]}"),
            trailing: IconButton(
              icon: const Icon(Icons.calendar_today_rounded, color: jmcIndigo),
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
        Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade300),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.02),
                blurRadius: 8,
                offset: const Offset(0, 4),
              )
            ],
          ),
          child: SwitchListTile(
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            title: const Text("Enable Weekly Automatic Reset",
                style: TextStyle(fontWeight: FontWeight.bold)),
            subtitle: const Text("Automatically reset points weekly"),
            value: weeklyResetEnabled,
            activeColor: jmcIndigo,
            onChanged: (v) => setState(() => weeklyResetEnabled = v),
          ),
        ),
      ],
    );
  }
}

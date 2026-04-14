import 'dart:convert';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'main.dart'; // To access Student, PointLog, and AttendanceLog models

class DatabaseService {
  static final DatabaseService _instance = DatabaseService._internal();
  static Database? _database;

  factory DatabaseService() => _instance;
  DatabaseService._internal();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    // Initialize sqflite for desktop
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;

    final documentsDirectory = await getApplicationDocumentsDirectory();
    final path = join(documentsDirectory.path, 'trackaccess.db');

    return await openDatabase(
      path,
      version: 4,
      onCreate: _onCreate,
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          // Wipe existing data to remove mock students if upgrading from 1
          await db.execute('DELETE FROM students');
          await db.execute('DELETE FROM visit_logs');
          await db.execute('DELETE FROM point_logs');
          await db.execute('DELETE FROM scans');
        }
        
        if (oldVersion < 3) {
          // Version 3: Add rewards and drafts tables
          await _createRewardsTable(db);
          await _createDraftsTable(db);
          
          // Seed initial rewards if empty
          final results = await db.rawQuery('SELECT COUNT(*) FROM rewards');
          final count = results.isNotEmpty ? (results.first.values.first as int) : 0;
          if (count == 0) {
            await db.insert('rewards', {'name': 'Free Coffee', 'cost': 50, 'is_active': 1});
            await db.insert('rewards', {'name': '1 Day Extension', 'cost': 100, 'is_active': 1});
            await db.insert('rewards', {'name': 'School Merchandise', 'cost': 500, 'is_active': 1});
          }
        }
        
        if (oldVersion < 4) {
          // Version 4: Add admins table
          await _createAdminsTable(db);
          final adminResults = await db.rawQuery('SELECT COUNT(*) FROM admins');
          final adminCount = adminResults.isNotEmpty ? (adminResults.first.values.first as int) : 0;
          if (adminCount == 0) {
            await db.insert('admins', {
              'username': 'admin',
              'password': 'admin',
              'email': 'admin@demo.com',
              'security_question': 'Default',
              'security_answer': 'admin'
            });
          }
        }
      },
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    // Students table
    print("DatabaseService: Creating tables...");
    await db.execute('''
      CREATE TABLE IF NOT EXISTS students (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        student_id TEXT UNIQUE,
        name TEXT,
        course TEXT,
        year_level TEXT,
        rfid_uid TEXT UNIQUE,
        points INTEGER DEFAULT 0,
        visits INTEGER DEFAULT 0,
        is_active INTEGER DEFAULT 1
      )
    ''');

    // Scans table (for latest scan polling)
    await db.execute('''
      CREATE TABLE IF NOT EXISTS scans (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        uid TEXT,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
      )
    ''');

    // Logs table (Activity logs)
    await db.execute('''
      CREATE TABLE IF NOT EXISTS logs (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        student_id TEXT,
        student_name TEXT,
        action TEXT,
        details TEXT,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
      )
    ''');

    // Visit logs (Attendance logs)
    await db.execute('''
      CREATE TABLE IF NOT EXISTS visit_logs (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        student_name TEXT,
        library TEXT,
        detail TEXT,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
      )
    ''');

    // Point logs
    await db.execute('''
      CREATE TABLE IF NOT EXISTS point_logs (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        student_id TEXT,
        type TEXT,
        value INTEGER,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
      )
    ''');

    await _createRewardsTable(db);
    await _createDraftsTable(db);
    await _createAdminsTable(db);

    // Seed initial rewards
    await db.insert('rewards', {'name': 'Free Coffee', 'cost': 50, 'is_active': 1});
    await db.insert('rewards', {'name': '1 Day Extension', 'cost': 100, 'is_active': 1});
    await db.insert('rewards', {'name': 'School Merchandise', 'cost': 500, 'is_active': 1});

    // Seed default admin
    await db.insert('admins', {
      'username': 'admin',
      'password': 'admin',
      'email': 'admin@demo.com',
      'security_question': 'Default',
      'security_answer': 'admin'
    });

    print("DatabaseService: Database initialized.");
  }

  Future<void> _createRewardsTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS rewards (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT,
        cost INTEGER,
        is_active INTEGER DEFAULT 1
      )
    ''');
  }

  Future<void> _createDraftsTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS drafts (
        form_id TEXT PRIMARY KEY,
        data TEXT,
        updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
      )
    ''');
  }

  Future<void> _createAdminsTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS admins (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        username TEXT UNIQUE,
        password TEXT,
        email TEXT UNIQUE,
        security_question TEXT,
        security_answer TEXT
      )
    ''');
  }

  // --- Admins Operations ---

  Future<Map<String, dynamic>?> getAdmin(String username) async {
    final db = await database;
    final maps = await db.query('admins', where: 'username = ?', whereArgs: [username]);
    if (maps.isNotEmpty) {
      return maps.first;
    }
    return null;
  }

  Future<bool> insertAdmin(Map<String, dynamic> adminData) async {
    final db = await database;
    try {
      await db.insert('admins', adminData, conflictAlgorithm: ConflictAlgorithm.fail);
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<bool> updateAdminPassword(String username, String newPassword) async {
    final db = await database;
    int changes = await db.update(
      'admins',
      {'password': newPassword},
      where: 'username = ?',
      whereArgs: [username]
    );
    return changes > 0;
  }

  Future<Map<String, dynamic>?> getAdminByEmail(String email) async {
    final db = await database;
    final maps = await db.query('admins', where: 'email = ?', whereArgs: [email]);
    if (maps.isNotEmpty) {
      return maps.first;
    }
    return null;
  }

  // --- Rewards Operations ---

  Future<List<Reward>> getRewards() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query('rewards');
    return maps.map((m) => Reward(
      m['name'], 
      m['cost'], 
      isActive: m['is_active'] == 1
    )).toList();
  }

  Future<void> insertReward(Reward r) async {
    final db = await database;
    await db.insert('rewards', {
      'name': r.name,
      'cost': r.cost,
      'is_active': r.isActive ? 1 : 0,
    });
  }

  Future<void> updateReward(String oldName, Reward r) async {
    final db = await database;
    await db.update('rewards', {
      'name': r.name,
      'cost': r.cost,
      'is_active': r.isActive ? 1 : 0,
    }, where: 'name = ?', whereArgs: [oldName]);
  }

  Future<void> deleteReward(String name) async {
    final db = await database;
    await db.delete('rewards', where: 'name = ?', whereArgs: [name]);
  }

  // --- Draft Operations ---

  Future<void> saveDraft(String formId, Map<String, dynamic> data) async {
    final db = await database;
    await db.insert('drafts', {
      'form_id': formId,
      'data': jsonEncode(data),
      'updated_at': DateTime.now().toIso8601String(),
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<Map<String, dynamic>?> loadDraft(String formId) async {
    final db = await database;
    final maps = await db.query('drafts', where: 'form_id = ?', whereArgs: [formId]);
    if (maps.isNotEmpty) {
      return jsonDecode(maps.first['data'] as String);
    }
    return null;
  }

  Future<void> clearDraft(String formId) async {
    final db = await database;
    await db.delete('drafts', where: 'form_id = ?', whereArgs: [formId]);
  }

  // --- CRUD Operations ---

  Future<List<Student>> getStudents() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query('students', orderBy: 'name ASC');

    List<Student> students = [];
    for (var map in maps) {
      final String studentId = map['student_id'];
      
      // Fetch point logs for this student
      final List<Map<String, dynamic>> pLogMaps = await db.query(
        'point_logs',
        where: 'student_id = ?',
        whereArgs: [studentId],
        orderBy: 'created_at DESC'
      );

      List<PointLog> pointLogs = pLogMaps.map((m) => PointLog(
        type: m['type'],
        value: m['value'],
        time: DateTime.parse(m['created_at']),
      )).toList();

      students.add(Student(
        uid: map['rfid_uid'],
        id: studentId,
        name: map['name'],
        course: map['course'] ?? "N/A",
        yearLevel: map['year_level'] ?? "N/A",
        points: map['points'],
        visits: map['visits'],
        isActive: map['is_active'] == 1,
        pointLogs: pointLogs,
      ));
    }
    return students;
  }

  Future<void> insertStudent(Student s) async {
    final db = await database;
    await db.insert(
      'students',
      {
        'student_id': s.id,
        'name': s.name,
        'course': s.course,
        'year_level': s.yearLevel,
        'rfid_uid': s.uid,
        'points': s.points,
        'visits': s.visits,
        'is_active': s.isActive ? 1 : 0,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> updateStudent(String studentId, Map<String, dynamic> data) async {
    final db = await database;
    await db.update(
      'students',
      data,
      where: 'student_id = ?',
      whereArgs: [studentId],
    );
  }

  Future<void> logActivity(String studentId, String studentName, String action, String details) async {
    final db = await database;
    await db.insert('logs', {
      'student_id': studentId,
      'student_name': studentName,
      'action': action,
      'details': details,
      'created_at': DateTime.now().toIso8601String(),
    });
  }

  Future<void> logVisit(String studentName, String library, String detail) async {
    final db = await database;
    await db.insert('visit_logs', {
      'student_name': studentName,
      'library': library,
      'detail': detail,
      'created_at': DateTime.now().toIso8601String(),
    });
  }

  Future<void> logPoints(String studentId, String type, int value) async {
    final db = await database;
    await db.insert('point_logs', {
      'student_id': studentId,
      'type': type,
      'value': value,
      'created_at': DateTime.now().toIso8601String(),
    });
  }

  Future<List<AttendanceLog>> getVisitLogs() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query('visit_logs', orderBy: 'created_at DESC');

    return List.generate(maps.length, (i) {
      return AttendanceLog(
        maps[i]['student_name'],
        maps[i]['library'],
        maps[i]['detail'],
        DateTime.parse(maps[i]['created_at']),
      );
    });
  }

  Future<String?> getLatestScan() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query('scans', orderBy: 'created_at DESC', limit: 1);
    if (maps.isNotEmpty) {
      return maps.first['uid'];
    }
    return null;
  }

  Future<void> insertScan(String uid) async {
    final db = await database;
    await db.insert('scans', {
      'uid': uid,
      'created_at': DateTime.now().toIso8601String(),
    });
  }
}

import 'dart:convert';
import 'package:http/http.dart' as http;

import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;

class ApiService {
  static String get baseUrl {
    if (kIsWeb) return "http://localhost:8080";
    if (Platform.isAndroid) return "http://10.0.2.2:8080";
    return "http://localhost:8080";
  }

  static Future<bool> login(String username, String password) async {
    try {
      final response = await http.post(
        Uri.parse("$baseUrl/login.php"),
        body: {
          "username": username,
          "password": password,
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data["success"] == true;
      } else {
        return false;
      }
    } catch (e) {
      print("Login Error: $e");
      throw Exception("Connection failed");
    }
  }

  static Future<String?> getLatestScan() async {
    try {
      final response = await http.get(Uri.parse("$baseUrl/get_latest.php"));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data["success"] == true) {
          return data["uid"];
        }
      }
      return null;
    } catch (e) {
      print("Fetch Scan Error: $e");
      return null;
    }
  }

  static Future<bool> logActivity(String studentId, String studentName, String action, String details) async {
    try {
      final response = await http.post(
        Uri.parse("$baseUrl/log_activity.php"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "student_id": studentId,
          "student_name": studentName,
          "action": action,
          "details": details,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data["success"] == true;
      }
      return false;
    } catch (e) {
      print("Log Activity Error: $e");
      return false;
    }
  }

  static Future<List<dynamic>> fetchStudents() async {
    try {
      final response = await http.get(Uri.parse("$baseUrl/get_students.php"));
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
      return [];
    } catch (e) {
      print("Fetch Students Error: $e");
      return [];
    }
  }

  static Future<bool> registerStudent(String studentId, String name, String uid, String course, String yearLevel) async {
    try {
      final response = await http.post(
        Uri.parse("$baseUrl/register_student.php"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "student_id": studentId,
          "name": name,
          "uid": uid,
          "course": course,
          "year_level": yearLevel,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data["success"] == true;
      }
      return false;
    } catch (e) {
      print("Register Student Error: $e");
      return false;
    }
  }

  static Future<bool> updateStudent(String studentId, {String? name, String? uid, bool? isActive, int? points, String? course, String? yearLevel}) async {
    try {
      final Map<String, dynamic> body = {"student_id": studentId};
      if (name != null) body["name"] = name;
      if (uid != null) body["uid"] = uid;
      if (isActive != null) body["isActive"] = isActive;
      if (points != null) body["points"] = points;
      if (course != null) body["course"] = course;
      if (yearLevel != null) body["year_level"] = yearLevel;

      final response = await http.post(
        Uri.parse("$baseUrl/update_student.php"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode(body),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data["success"] == true;
      }
      return false;
    } catch (e) {
      print("Update Student Error: $e");
      return false;
    }
  }
}

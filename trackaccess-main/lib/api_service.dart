import 'dart:convert';
import 'package:http/http.dart' as http;

class ApiService {
  static const String baseUrl = "http://localhost:8080";

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
      return false;
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

  static Future<bool> logScan(String uid) async {
    try {
      final response = await http.post(
        Uri.parse("$baseUrl/scan_rfid.php"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"uid": uid}),
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data["success"] == true;
      }
      return false;
    } catch (e) {
      print("Log Scan Error: $e");
      return false;
    }
  }

  static Future<List<Map<String, dynamic>>> getAllScans() async {
    try {
      final response = await http.get(Uri.parse("$baseUrl/get_all_scans.php"));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data["success"] == true) {
          return List<Map<String, dynamic>>.from(data["scans"]);
        }
      }
      return [];
    } catch (e) {
      print("Fetch All Scans Error: $e");
      return [];
    }
  }
}

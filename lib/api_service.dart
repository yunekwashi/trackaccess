import 'dart:convert';
import 'package:http/http.dart' as http;

class ApiService {
  // Change this to your XAMPP server IP when testing on a real phone
  static const String baseUrl = "http://localhost/TrackaccessDB"; 
  // Example for real phone:
  // static const String baseUrl = "http://192.168.1.5/TrackaccessDB";

  /// Calls login.php on the server to verify admin credentials
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
}
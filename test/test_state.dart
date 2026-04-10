import 'dart:async';
import 'package:flutter/material.dart';

class Student {
  String uid;
  String id;
  String name;
  String course;
  String yearLevel;
  int points;
  int visits;
  int isActive;
  String? currentStatus;
  
  Student({
    required this.uid,
    required this.id,
    required this.name,
    required this.course,
    required this.yearLevel,
    this.points = 0,
    this.visits = 0,
    this.isActive = 1,
    this.currentStatus,
  });
}

class AppState extends ChangeNotifier {
  static final AppState instance = AppState._internal();
  AppState._internal();

  List<Student> students = [
    Student(uid: "AABB1122", id: "001", name: "Mike", course: "IT", yearLevel: "1st Year", points: 5),
    Student(uid: "1122AABB", id: "002", name: "Alice", course: "IT", yearLevel: "1st Year", points: 2),
  ];
  String scanMessage = "Tap card";

  void processScan(String uid) {
    final student = students.firstWhere((s) => s.uid == uid);
    final nextStatus = (student.currentStatus == "Entry") ? "Exit" : "Entry";
    student.currentStatus = nextStatus;

    if (nextStatus == "Entry") {
      student.points += 5;
    }

    scanMessage = (nextStatus == "Entry")
          ? "Welcome ${student.name}\nPoints: ${student.points}\n(Entry Logged)"
          : "Goodbye ${student.name}\n(Exit Logged)";
          
    notifyListeners();
  }
}

void main() {
  final state = AppState.instance;
  state.addListener(() {
    print("Listeners notified! Scan message: ${state.scanMessage}");
    final top = [...state.students]..sort((a,b) => b.points.compareTo(a.points));
    print("Leaderboard Top: ${top.first.name} - ${top.first.points} pts");
  });

  print("First scan...");
  state.processScan("AABB1122");
  
  print("Second scan...");
  state.processScan("AABB1122");

  print("Third scan...");
  state.processScan("1122AABB");
}

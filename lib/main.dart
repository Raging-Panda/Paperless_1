import 'package:flutter/material.dart';
import 'app.dart';
import 'database/database_helper.dart';

void main() async {
  // Ensure Flutter binding is initialized
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize the database
  final dbHelper = DatabaseHelper();
  await dbHelper.database;

  runApp(const PaperlessApp());
}

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const ToshehApp());
}

class ToshehApp extends StatelessWidget {
  const ToshehApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'توشه آخرت',
      theme: ThemeData(
        useMaterial3: true,
        fontFamily: 'sans',
        colorSchemeSeed: const Color(0xFF2E6F68),
      ),
      home: const HomePage(),
    );
  }
}

class DatabaseHelper {
  static Database? _database;

  static Future<Database> get database async {
    if (_database != null) return _database!;

    final databasesPath = await getDatabasesPath();
    final path = join(databasesPath, 'book.db');

    final exists = await databaseExists(path);

    if (!exists) {
      final data = await rootBundle.load('assets/book.db');
      final bytes = data.buffer.asUint8List(
        data.offsetInBytes,
        data.lengthInBytes,
      );

      await writeDatabaseFile(path, bytes);
    }

    _database = await openDatabase(path, readOnly: true);
    return _database!;
  }

  static Future<void> writeDatabaseFile(
    String path,
    List<int> bytes,
  ) async {
    final file = await databaseFile(path);
    await file.writeAsBytes(bytes, flush: true);
  }

  static Future<dynamic> databaseFile(String path) async {
    return FileWrapper(path);
  }
}

class FileWrapper {
  final String path;

  FileWrapper(this.path);

  Future<void> writeAsBytes(List<int> bytes, {bool flush = false}) async {
    // This method is replaced below by dart:io implementation.
  }
}

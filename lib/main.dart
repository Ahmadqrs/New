import 'dart:io';

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
        colorSchemeSeed: const Color(0xFF2E6F68),
        scaffoldBackgroundColor: const Color(0xFFFAF7EF),
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
    final dbPath = join(databasesPath, 'book.db');

    if (!await databaseExists(dbPath)) {
      final data = await rootBundle.load('assets/book.db');

      final bytes = data.buffer.asUint8List(
        data.offsetInBytes,
        data.lengthInBytes,
      );

      final file = File(dbPath);
      await file.writeAsBytes(bytes, flush: true);
    }

    _database = await openDatabase(
      dbPath,
      readOnly: true,
    );

    return _database!;
  }

  static Future<List<Map<String, dynamic>>> getBooks() async {
    final db = await database;

    return db.query(
      'contenttb',
      where: 'level1 = ? AND level2 = 0',
      whereArgs: [9999],
      orderBy: 'priority ASC, id ASC',
    );
  }

  static Future<List<Map<String, dynamic>>> getChildren(
    int level1,
    int level2,
  ) async {
    final db = await database;

    return db.query(
      'contenttb',
      where: 'level1 = ? AND level2 = ?',
      whereArgs: [level1, level2],
      orderBy: 'priority ASC, id ASC',
    );
  }

  static Future<List<Map<String, dynamic>>> search(String text) async {
    final db = await database;

    return db.query(
      'contenttb',
      where: 'title LIKE ? OR content LIKE ?',
      whereArgs: ['%$text%', '%$text%'],
      orderBy: 'id ASC',
      limit: 100,
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  List<Map<String, dynamic>> books = [];
  bool loading = true;

  @override
  void initState() {
    super.initState();
    loadBooks();
  }

  Future<void> loadBooks() async {
    try {
      final db = await DatabaseHelper.database;

      final result = await db.query(
        'contenttb',
        orderBy: 'id ASC',
      );

      setState(() {
        books = result;
        loading = false;
      });
    } catch (e) {
      setState(() {
        loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: const Text(
            'توشه آخرت',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          centerTitle: true,
        ),
        body: loading
            ? const Center(child: CircularProgressIndicator())
            : books.isEmpty
                ? const Center(
                    child: Text('کتابی پیدا نشد'),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(12),
                    itemCount: books.length,
                    itemBuilder: (context, index) {
                      final item = books[index];

                      return BookTile(
                        item: item,
                        allItems: books,
                      );
                    },
                  ),
      ),
    );
  }
}

class BookTile extends StatelessWidget {
  final Map<String, dynamic> item;
  final List<Map<String, dynamic>> allItems;

  const BookTile({
    super.key,
    required this.item,
    required this.allItems,
  });

  @override
  Widget build(BuildContext context) {
    final title = item['title']?.toString() ?? '';
    final level1 = item['level1'] ?? 0;
    final level2 = item['level2'] ?? 0;
    final level3 = item['level3'] ?? 0;
    final level4 = item['level4'] ?? 0;

    final children = allItems.where((x) {
      return x['level1'] == level1 &&
          x['level2'] == level2 &&
          x['level3'] == level3 &&
          x['level4'] == level4 &&
          x['id'] != item['id'];
    }).toList();

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: const CircleAvatar(
          child: Icon(Icons.menu_book),
        ),
        title: Text(
          title.isEmpty ? 'بدون عنوان' : title,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
        trailing: const Icon(Icons.chevron_left),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => ContentPage(
                item: item,
                allItems: allItems,
              ),
            ),
          );
        },
      ),
    );
  }
}

class ContentPage extends StatelessWidget {
  final Map<String, dynamic> item;
  final List<Map<String, dynamic>> allItems;

  const ContentPage({
    super.key,
    required this.item,
    required this.allItems,
  });

  @override
  Widget build(BuildContext context) {
    final title = item['title']?.toString() ?? '';
    final content = item['content']?.toString() ?? '';

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: Text(title),
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: SelectableText(
            content,
            style: const TextStyle(
              fontSize: 18,
              height: 2,
            ),
          ),
        ),
      ),
    );
  }
}

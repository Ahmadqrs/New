import 'dart:io';

import 'package:archive/archive.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
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
        appBarTheme: const AppBarTheme(
          centerTitle: true,
        ),
      ),
      home: const HomePage(),
    );
  }
}

class DbHelper {
  static Database? _db;

  static Future<Database> get db async {
    if (_db != null) {
      return _db!;
    }

    final databasesPath = await getDatabasesPath();
    final dbPath = p.join(databasesPath, 'book.db');

    // اگر دیتابیس قبلاً استخراج نشده باشد
    if (!await databaseExists(dbPath)) {
      final compressed = await rootBundle.load(
        'assets/book.db.gz',
      );

      final input = compressed.buffer.asUint8List(
        compressed.offsetInBytes,
        compressed.lengthInBytes,
      );

      // استخراج gzip
      final output = GZipDecoder().decodeBytes(input);

      final file = File(dbPath);

      await file.writeAsBytes(
        output,
        flush: true,
      );
    }

    _db = await openDatabase(
      dbPath,
      readOnly: true,
    );

    return _db!;
  }

  static Future<List<Map<String, Object?>>> getAllItems() async {
    final database = await db;

    return database.query(
      'contenttb',
      orderBy: 'id ASC',
    );
  }
}

class Item {
  final int id;
  final String title;
  final String content;

  final int? level1;
  final int? level2;
  final int? level3;
  final int? level4;

  Item(Map<String, Object?> row)
      : id = (row['id'] as num?)?.toInt() ?? 0,
        title = (row['title'] ?? '').toString().trim(),
        content = (row['content'] ?? '').toString(),
        level1 = (row['level1'] as num?)?.toInt(),
        level2 = (row['level2'] as num?)?.toInt(),
        level3 = (row['level3'] as num?)?.toInt(),
        level4 = (row['level4'] as num?)?.toInt();

  bool get isRoot => level2 == null || level2 == 0;

  bool get hasContent => content.trim().isNotEmpty;
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  late Future<List<Item>> futureItems;

  @override
  void initState() {
    super.initState();
    futureItems = loadItems();
  }

  Future<List<Item>> loadItems() async {
    final rows = await DbHelper.getAllItems();

    return rows.map((row) {
      return Item(row);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: const Text(
            'توشه آخرت',
            style: TextStyle(
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        body: FutureBuilder<List<Item>>(
          future: futureItems,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const Center(
                child: CircularProgressIndicator(),
              );
            }

            if (snapshot.hasError) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Text(
                    'خطا در باز کردن دیتابیس:\n\n${snapshot.error}',
                    textAlign: TextAlign.center,
                  ),
                ),
              );
            }

            final items = snapshot.data ?? [];

            if (items.isEmpty) {
              return const Center(
                child: Text(
                  'هیچ مطلبی پیدا نشد.',
                ),
              );
            }

            return ListView(
              padding: const EdgeInsets.all(12),
              children: [
                const LibraryHeader(),
                const SizedBox(height: 12),

                // نمایش ساختار درختی
                ...buildRootItems(items),
              ],
            );
          },
        ),
      ),
    );
  }

  List<Widget> buildRootItems(List<Item> items) {
    final roots = <Item>[];

    for (final item in items) {
      if (item.isRoot) {
        roots.add(item);
      }
    }

    return roots.map((item) {
      return TreeItem(
        item: item,
        allItems: items,
        depth: 0,
      );
    }).toList();
  }
}

class LibraryHeader extends StatelessWidget {
  const LibraryHeader({super.key});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 1,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Row(
          children: [
            const CircleAvatar(
              radius: 28,
              child: Icon(
                Icons.menu_book,
                size: 30,
              ),
            ),

            const SizedBox(width: 14),

            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Text(
                    'کتابخانه توشه آخرت',
                    style: TextStyle(
                      fontSize: 19,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 5),
                  Text(
                    'نسخه آزمایشی برای بررسی کتاب‌ها',
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class TreeItem extends StatelessWidget {
  final Item item;
  final List<Item> allItems;
  final int depth;

  const TreeItem({
    super.key,
    required this.item,
    required this.allItems,
    required this.depth,
  });

  List<Item> get children {
    // سطح اول
    if (item.isRoot) {
      return allItems.where((x) {
        return x.level1 == item.level1 &&
            x.level2 != null &&
            x.level2 != 0 &&
            x.level3 == null;
      }).toList();
    }

    // سطح دوم
    if (item.level2 != null &&
        item.level3 == null) {
      return allItems.where((x) {
        return x.level1 == item.level1 &&
            x.level2 == item.level2 &&
            x.level3 != null &&
            x.level4 == null;
      }).toList();
    }

    // سطح سوم
    if (item.level3 != null &&
        item.level4 == null) {
      return allItems.where((x) {
        return x.level1 == item.level1 &&
            x.level2 == item.level2 &&
            x.level3 == item.level3 &&
            x.level4 != null;
      }).toList();
    }

    return [];
  }

  @override
  Widget build(BuildContext context) {
    final childItems = children;

    // دارای زیرمجموعه
    if (childItems.isNotEmpty) {
      return Card(
        elevation: depth == 0 ? 1 : 0,
        margin: EdgeInsets.only(
          right: depth * 10.0,
          bottom: 7,
        ),
        child: ExpansionTile(
          leading: Icon(
            depth == 0
                ? Icons.library_books
                : Icons.folder_open,
          ),
          title: Text(
            item.title.isEmpty
                ? 'بدون عنوان'
                : item.title,
            style: TextStyle(
              fontWeight: depth == 0
                  ? FontWeight.bold
                  : FontWeight.w600,
            ),
          ),
          children: childItems.map((child) {
            return TreeItem(
              item: child,
              allItems: allItems,
              depth: depth + 1,
            );
          }).toList(),
        ),
      );
    }

    // مطلب نهایی
    return Card(
      elevation: 0,
      margin: EdgeInsets.only(
        right: depth * 10.0,
        bottom: 5,
      ),
      child: ListTile(
        leading: Icon(
          item.hasContent
              ? Icons.article_outlined
              : Icons.folder_outlined,
        ),
        title: Text(
          item.title.isEmpty
              ? 'بدون عنوان'
              : item.title,
          style: const TextStyle(
            fontWeight: FontWeight.w600,
          ),
        ),
        trailing: item.hasContent
            ? const Icon(Icons.chevron_left)
            : null,
        onTap: item.hasContent
            ? () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) {
                      return ReaderPage(
                        item: item,
                      );
                    },
                  ),
                );
              }
            : null,
      ),
    );
  }
}

class ReaderPage extends StatelessWidget {
  final Item item;

  const ReaderPage({
    super.key,
    required this.item,
  });

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            item.title.isEmpty
                ? 'مطالعه'
                : item.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(
            20,
            18,
            20,
            40,
          ),
          child: SelectableText(
            item.content,
            textAlign: TextAlign.justify,
            style: const TextStyle(
              fontSize: 18,
              height: 2.05,
            ),
          ),
        ),
      ),
    );
  }
}

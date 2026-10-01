import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:just_audio/just_audio.dart';
import 'package:shared_preferences/shared_preferences.dart';

const api = 'https://api.quran.com/api/v4';
const cdn = 'https://verses.quran.foundation/';
const bg = Color(0xFF0C2421), card = Color(0xFF12332F);
const gold = Color(0xFFD4B05A), ink = Color(0xFFEFE9D8), mute = Color(0xFF9DB5AD);

Future<dynamic> getJson(String p) async {
  final r = await http.get(Uri.parse(api + p));
  if (r.statusCode != 200) throw Exception('HTTP ${r.statusCode}');
  return jsonDecode(utf8.decode(r.bodyBytes));
}

String audioUrl(String u) => u.startsWith('http')
    ? u
    : u.startsWith('//')
        ? 'https:$u'
        : cdn + u.replaceFirst(RegExp(r'^/'), '');

String strip(String h) =>
    h.replaceAll(RegExp(r'<sup[^>]*>.*?</sup>'), '').replaceAll(RegExp(r'<[^>]+>'), '');

String langLabel(String l) =>
    l == 'persian' ? 'فارسی' : (l == 'pashto' ? 'پشتو' : 'English');

/// تنظیمات و داده‌های مشترک
class S {
  static late SharedPreferences p;
  static List chapters = [], trans = [], reciters = [];
  static int tid = 0, rid = 7;

  static Future<void> boot() async {
    p = await SharedPreferences.getInstance();
    final r = await Future.wait([
      getJson('/chapters?language=fa'),
      getJson('/resources/translations'),
      getJson('/resources/recitations?language=fa'),
    ]);
    chapters = r[0]['chapters'];
    const langs = ['persian', 'pashto', 'english'];
    trans = (r[1]['translations'] as List)
        .where((x) => langs.contains(x['language_name']))
        .toList()
      ..sort((a, b) => langs.indexOf(a['language_name']).compareTo(langs.indexOf(b['language_name'])));
    reciters = r[2]['recitations'];
    tid = p.getInt('tid') ?? trans.first['id'];
    rid = p.getInt('rid') ??
        reciters.firstWhere(
          (x) => RegExp('Alafasy|مشاری').hasMatch('${x['reciter_name']} ${x['translated_name']?['name']}'),
          orElse: () => reciters.first,
        )['id'];
  }
}

void main() => runApp(const QuranApp());

class QuranApp extends StatelessWidget {
  const QuranApp({super.key});
  @override
  Widget build(BuildContext context) {
    final base = ThemeData.dark();
    return MaterialApp(
      title: 'قرآن کریم',
      debugShowCheckedModeBanner: false,
      builder: (c, child) => Directionality(textDirection: TextDirection.rtl, child: child!),
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: bg,
        colorScheme: const ColorScheme.dark(primary: gold, surface: card),
        textTheme: GoogleFonts.vazirmatnTextTheme(base.textTheme).apply(bodyColor: ink, displayColor: ink),
        appBarTheme: const AppBarTheme(backgroundColor: bg, elevation: 0),
      ),
      home: const HomePage(),
    );
  }
}

void openSettings(BuildContext context, VoidCallback done) {
  showModalBottomSheet(
    context: context,
    backgroundColor: card,
    builder: (_) => StatefulBuilder(
      builder: (ctx, set) => Padding(
        padding: const EdgeInsets.all(16),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('ترجمه', style: TextStyle(color: gold)),
          DropdownButton<int>(
            isExpanded: true,
            value: S.tid,
            dropdownColor: card,
            items: [
              for (final t in S.trans)
                DropdownMenuItem<int>(
                  value: t['id'] as int,
                  child: Text('${langLabel(t['language_name'])} — ${t['name']}', overflow: TextOverflow.ellipsis),
                )
            ],
            onChanged: (v) {
              S.tid = v!;
              S.p.setInt('tid', v);
              set(() {});
            },
          ),
          const SizedBox(height: 12),
          const Text('قاری', style: TextStyle(color: gold)),
          DropdownButton<int>(
            isExpanded: true,
            value: S.rid,
            dropdownColor: card,
            items: [
              for (final r in S.reciters)
                DropdownMenuItem<int>(
                  value: r['id'] as int,
                  child: Text(
                    '${r['translated_name']?['name'] ?? r['reciter_name']}${(r['style'] ?? '') == '' ? '' : ' (${r['style']})'}',
                    overflow: TextOverflow.ellipsis,
                  ),
                )
            ],
            onChanged: (v) {
              S.rid = v!;
              S.p.setInt('rid', v);
              set(() {});
            },
          ),
        ]),
      ),
    ),
  ).whenComplete(done);
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});
  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  late Future<void> boot = S.boot();
  String q = '';

  void open(Map ch, [int start = 0]) =>
      Navigator.push(context, MaterialPageRoute(builder: (_) => ReaderPage(ch: ch, start: start)))
          .then((_) => setState(() {}));

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: boot,
      builder: (context, snap) {
        if (snap.hasError) {
          return Scaffold(
            body: Center(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                const Text('اتصال به اینترنت برقرار نشد'),
                TextButton(onPressed: () => setState(() => boot = S.boot()), child: const Text('تلاش دوباره')),
              ]),
            ),
          );
        }
        if (snap.connectionState != ConnectionState.done) {
          return const Scaffold(body: Center(child: CircularProgressIndicator(color: gold)));
        }
        final list = S.chapters.where((c) {
          final s = q.trim();
          return s.isEmpty ||
              '${c['id']}'.contains(s) ||
              c['name_arabic'].toString().contains(s) ||
              c['name_simple'].toString().toLowerCase().contains(s.toLowerCase()) ||
              c['translated_name']['name'].toString().contains(s);
        }).toList();
        final lastS = S.p.getInt('last_s'), lastV = S.p.getInt('last_v') ?? 0;
        return Scaffold(
          appBar: AppBar(
            title: Text('قرآن کریم', style: GoogleFonts.amiriQuran(fontSize: 26, color: gold)),
            actions: [IconButton(icon: const Icon(Icons.tune), onPressed: () => openSettings(context, () {}))],
          ),
          body: Column(children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 4, 14, 8),
              child: TextField(
                onChanged: (v) => setState(() => q = v),
                decoration: InputDecoration(
                  hintText: 'جستجوی سوره',
                  prefixIcon: const Icon(Icons.search),
                  filled: true,
                  fillColor: card,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                ),
              ),
            ),
            if (lastS != null && q.isEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 0, 14, 8),
                child: Material(
                  color: card,
                  borderRadius: BorderRadius.circular(12),
                  child: ListTile(
                    leading: const Icon(Icons.bookmark, color: gold),
                    title: const Text('ادامهٔ مطالعه'),
                    subtitle: Text('سورهٔ ${S.chapters[lastS - 1]['name_arabic']} — آیه $lastV'),
                    onTap: () => open(S.chapters[lastS - 1], lastV > 0 ? lastV - 1 : 0),
                  ),
                ),
              ),
            Expanded(
              child: ListView.separated(
                itemCount: list.length,
                separatorBuilder: (_, __) => const Divider(height: 1, color: Color(0xFF25514B)),
                itemBuilder: (_, i) {
                  final c = list[i];
                  return ListTile(
                    leading: Container(
                      width: 40,
                      height: 40,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: gold)),
                      child: Text('${c['id']}', style: const TextStyle(color: gold, fontSize: 13)),
                    ),
                    title: Text(c['name_arabic'], style: GoogleFonts.amiriQuran(fontSize: 24)),
                    subtitle: Text(
                      '${c['translated_name']['name']} · ${c['verses_count']} آیه · ${c['revelation_place'] == 'makkah' ? 'مکی' : 'مدنی'}',
                      style: const TextStyle(color: mute, fontSize: 13),
                    ),
                    onTap: () => open(c),
                  );
                },
              ),
            ),
          ]),
        );
      },
    );
  }
}

class ReaderPage extends StatefulWidget {
  final Map ch;
  final int start;
  const ReaderPage({super.key, required this.ch, this.start = 0});
  @override
  State<ReaderPage> createState() => _ReaderPageState();
}

class _ReaderPageState extends State<ReaderPage> {
  final player = AudioPlayer();
  List verses = [];
  Map<String, String> audio = {};
  List<GlobalKey> keys = [];
  int cur = -1;
  bool loading = true;
  String? err;

  @override
  void initState() {
    super.initState();
    player.playerStateStream.listen((s) {
      if (s.processingState == ProcessingState.completed) {
        playAt(cur + 1);
      } else if (mounted) {
        setState(() {});
      }
    });
    load();
  }

  @override
  void dispose() {
    player.dispose();
    super.dispose();
  }

  Future<void> load() async {
    setState(() {
      loading = true;
      err = null;
      cur = -1;
    });
    await player.stop();
    try {
      final n = widget.ch['id'];
      final r = await Future.wait([
        getJson('/verses/by_chapter/$n?language=fa&translations=${S.tid}&fields=text_uthmani&per_page=300'),
        getJson('/recitations/${S.rid}/by_chapter/$n?per_page=300'),
      ]);
      verses = r[0]['verses'];
      audio = {for (final f in r[1]['audio_files']) f['verse_key'] as String: audioUrl(f['url'])};
      keys = List.generate(verses.length, (_) => GlobalKey());
      setState(() => loading = false);
      if (widget.start > 0) WidgetsBinding.instance.addPostFrameCallback((_) => reveal(widget.start));
    } catch (e) {
      setState(() {
        loading = false;
        err = 'خطا در دریافت سوره';
      });
    }
  }

  void reveal(int i) {
    final c = keys[i].currentContext;
    if (c != null) Scrollable.ensureVisible(c, duration: const Duration(milliseconds: 400), alignment: 0.2);
  }

  Future<void> playAt(int i) async {
    if (i < 0 || i >= verses.length) {
      await player.stop();
      if (mounted) setState(() => cur = -1);
      return;
    }
    setState(() => cur = i);
    S.p.setInt('last_s', widget.ch['id']);
    S.p.setInt('last_v', verses[i]['verse_number']);
    WidgetsBinding.instance.addPostFrameCallback((_) => reveal(i));
    try {
      await player.setUrl(audio[verses[i]['verse_key']]!);
      player.play();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('پخش صوت ممکن نشد')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final id = widget.ch['id'];
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.ch['name_arabic'], style: GoogleFonts.amiriQuran(fontSize: 26, color: gold)),
        actions: [IconButton(icon: const Icon(Icons.tune), onPressed: () => openSettings(context, load))],
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator(color: gold))
          : err != null
              ? Center(child: TextButton(onPressed: load, child: Text('$err — تلاش دوباره')))
              : SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 110),
                  child: Column(children: [
                    if (id != 1 && id != 9)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        child: Text('بِسْمِ ٱللَّهِ ٱلرَّحْمَٰنِ ٱلرَّحِيمِ',
                            style: GoogleFonts.amiriQuran(fontSize: 28, height: 2)),
                      ),
                    for (var i = 0; i < verses.length; i++) verseTile(i),
                  ]),
                ),
      bottomNavigationBar: loading || err != null
          ? null
          : Container(
              color: card,
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: SafeArea(
                top: false,
                child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  IconButton(iconSize: 32, icon: const Icon(Icons.skip_next), onPressed: () => playAt(cur < 0 ? 0 : cur + 1)),
                  const SizedBox(width: 8),
                  CircleAvatar(
                    radius: 28,
                    backgroundColor: gold,
                    child: IconButton(
                      iconSize: 32,
                      color: bg,
                      icon: Icon(player.playing ? Icons.pause : Icons.play_arrow),
                      onPressed: () {
                        if (cur < 0) {
                          playAt(0);
                        } else {
                          player.playing ? player.pause() : player.play();
                        }
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(iconSize: 32, icon: const Icon(Icons.skip_previous), onPressed: () => playAt(cur <= 0 ? 0 : cur - 1)),
                ]),
              ),
            ),
    );
  }

  Widget verseTile(int i) {
    final v = verses[i];
    final tr = (v['translations'] as List).isEmpty ? '' : strip(v['translations'][0]['text']);
    return Container(
      key: keys[i],
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 14),
      decoration: BoxDecoration(
        color: cur == i ? card : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        border: Border(top: BorderSide(color: cur == i ? Colors.transparent : const Color(0xFF25514B))),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Text('آیه ${v['verse_number']}', style: const TextStyle(color: gold, fontSize: 13)),
          IconButton(
            visualDensity: VisualDensity.compact,
            icon: Icon(cur == i && player.playing ? Icons.pause_circle : Icons.play_circle, color: gold),
            onPressed: () => cur == i && player.playing ? player.pause() : playAt(i),
          ),
        ]),
        Text(v['text_uthmani'], style: GoogleFonts.amiriQuran(fontSize: 30, height: 2.3)),
        if (tr.isNotEmpty) Text(tr, style: const TextStyle(color: mute, fontSize: 15.5, height: 1.8)),
      ]),
    );
  }
}

import 'dart:convert';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';
import '../domain/models.dart';

/// Local-only SQLite v3 storage (sessions + spaced repetition revisions + JSON backup).
class Repo {
  static Database? _d;

  static Future<Database> get _db async => _d ??= await openDatabase(
        p.join(await getDatabasesPath(), 'focusguard.db'),
        version: 3,
        onCreate: (d, _) async {
          await d.execute(
            'CREATE TABLE s('
            'id INTEGER PRIMARY KEY AUTOINCREMENT,'
            'start INTEGER,'
            'planned INTEGER,'
            'iv INTEGER,'
            'checks TEXT,'
            'lost INTEGER,'
            'calib INTEGER,'
            'done INTEGER,'
            'subject TEXT DEFAULT "General",'
            'mode TEXT DEFAULT "Reading",'
            'note TEXT DEFAULT "",'
            'mcqs INTEGER DEFAULT 0,'
            'correct INTEGER DEFAULT 0,'
            'phone_mode INTEGER DEFAULT 0,'
            'xp INTEGER DEFAULT 0'
            ')',
          );
          await _createRevTable(d);
        },
        onUpgrade: (d, oldVersion, newVersion) async {
          if (oldVersion < 2) {
            await _safeExec(d, 'ALTER TABLE s ADD COLUMN subject TEXT DEFAULT "General"');
            await _safeExec(d, 'ALTER TABLE s ADD COLUMN mode TEXT DEFAULT "Reading"');
          }
          if (oldVersion < 3) {
            await _safeExec(d, 'ALTER TABLE s ADD COLUMN note TEXT DEFAULT ""');
            await _safeExec(d, 'ALTER TABLE s ADD COLUMN mcqs INTEGER DEFAULT 0');
            await _safeExec(d, 'ALTER TABLE s ADD COLUMN correct INTEGER DEFAULT 0');
            await _safeExec(d, 'ALTER TABLE s ADD COLUMN phone_mode INTEGER DEFAULT 0');
            await _safeExec(d, 'ALTER TABLE s ADD COLUMN xp INTEGER DEFAULT 0');
            await _createRevTable(d);
          }
        },
      );

  static Future<void> _safeExec(Database d, String sql) async {
    try {
      await d.execute(sql);
    } catch (_) {}
  }

  static Future<void> _createRevTable(Database d) async {
    await d.execute(
      'CREATE TABLE IF NOT EXISTS rev('
      'id INTEGER PRIMARY KEY AUTOINCREMENT,'
      'subject TEXT,'
      'topic TEXT,'
      'stage INTEGER,'
      'due INTEGER,'
      'created INTEGER,'
      'high_yield INTEGER DEFAULT 0,'
      'done_count INTEGER DEFAULT 0'
      ')',
    );
  }

  static Future<int> save(SessionRecord r) async {
    try {
      return await (await _db).insert('s', r.toMap());
    } catch (_) {
      return 0;
    }
  }

  static Future<void> updateSessionExtras(
    int id, {
    required String note,
    required int mcqs,
    required int correct,
  }) async {
    try {
      await (await _db).update(
        's',
        {'note': note, 'mcqs': mcqs, 'correct': correct},
        where: 'id=?',
        whereArgs: [id],
      );
    } catch (_) {}
  }

  static Future<List<SessionRecord>> since(DateTime t) async {
    try {
      final rows = await (await _db).query(
        's',
        where: 'start>=?',
        whereArgs: [t.millisecondsSinceEpoch],
        orderBy: 'start DESC',
      );
      return rows.map(SessionRecord.fromMap).toList();
    } catch (_) {
      return const [];
    }
  }

  static Future<List<SessionRecord>> allSessions() async {
    try {
      final rows = await (await _db).query('s', orderBy: 'start DESC');
      return rows.map(SessionRecord.fromMap).toList();
    } catch (_) {
      return const [];
    }
  }

  // ---- Spaced Repetition Queue ----
  static Future<void> addRevision({
    required String subject,
    required String topic,
    bool highYield = false,
  }) async {
    final clean = topic.trim();
    if (clean.isEmpty) return;
    final now = DateTime.now();
    final tomorrow = DateTime(now.year, now.month, now.day)
        .add(Duration(days: kSrIntervalsDays.first));
    try {
      await (await _db).insert(
        'rev',
        RevisionItem(
          subject: subject,
          topic: clean,
          stage: 0,
          due: tomorrow,
          created: now,
          highYield: highYield,
          doneCount: 0,
        ).toMap(),
      );
    } catch (_) {}
  }

  static Future<List<RevisionItem>> allRevisions() async {
    try {
      final rows = await (await _db).query(
        'rev',
        orderBy: 'high_yield DESC, due ASC',
      );
      return rows.map(RevisionItem.fromMap).toList();
    } catch (_) {
      return const [];
    }
  }

  static Future<int> dueCount() async {
    final list = await allRevisions();
    return list.where((r) => r.isDueToday).length;
  }

  static Future<void> markRevisionDone(RevisionItem item) async {
    if (item.id == null) return;
    final nextStage = item.stage + 1;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final nextDue = nextStage >= kSrIntervalsDays.length
        ? today.add(const Duration(days: 3650))
        : today.add(Duration(days: kSrIntervalsDays[nextStage]));
    try {
      await (await _db).update(
        'rev',
        {
          'stage': nextStage,
          'due': nextDue.millisecondsSinceEpoch,
          'done_count': item.doneCount + 1,
        },
        where: 'id=?',
        whereArgs: [item.id],
      );
    } catch (_) {}
  }

  static Future<void> resetRevision(RevisionItem item) async {
    if (item.id == null) return;
    final now = DateTime.now();
    final tomorrow = DateTime(now.year, now.month, now.day).add(const Duration(days: 1));
    try {
      await (await _db).update(
        'rev',
        {'stage': 0, 'due': tomorrow.millisecondsSinceEpoch},
        where: 'id=?',
        whereArgs: [item.id],
      );
    } catch (_) {}
  }

  static Future<void> deleteRevision(int id) async {
    try {
      await (await _db).delete('rev', where: 'id=?', whereArgs: [id]);
    } catch (_) {}
  }

  static Future<String> exportJson() async {
    final sessions = (await allSessions()).map((e) => e.toMap()).toList();
    final revs = (await allRevisions()).map((e) => e.toMap()).toList();
    return jsonEncode({'v': 3, 'sessions': sessions, 'revisions': revs});
  }

  static Future<int> importJson(String raw) async {
    final decoded = jsonDecode(raw) as Map<String, dynamic>;
    final db = await _db;
    int count = 0;
    final sessions = (decoded['sessions'] as List?) ?? const [];
    for (final s in sessions) {
      await db.insert('s', Map<String, Object?>.from(s as Map));
      count++;
    }
    final revs = (decoded['revisions'] as List?) ?? const [];
    for (final r in revs) {
      await db.insert('rev', Map<String, Object?>.from(r as Map));
      count++;
    }
    return count;
  }

  static Future<void> wipe() async {
    try {
      final db = await _db;
      await db.delete('s');
      await db.delete('rev');
    } catch (_) {}
  }
}

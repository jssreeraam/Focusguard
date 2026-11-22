import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';
import '../domain/models.dart';

/// Local-only storage. All session history remains strictly on-device.
class Repo {
  static Database? _d;

  static Future<Database> get _db async => _d ??= await openDatabase(
        p.join(await getDatabasesPath(), 'focusguard.db'),
        version: 1,
        onCreate: (d, _) => d.execute(
          'CREATE TABLE s(id INTEGER PRIMARY KEY AUTOINCREMENT,start INTEGER,planned INTEGER,iv INTEGER,checks TEXT,lost INTEGER,calib INTEGER,done INTEGER)',
        ),
      );

  static Future<void> save(SessionRecord r) async {
    try {
      await (await _db).insert('s', r.toMap());
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

  static Future<void> wipe() async {
    try {
      await (await _db).delete('s');
    } catch (_) {}
  }
}

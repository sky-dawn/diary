import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class AppDatabase {
  Database? _database;

  Future<Database> get database async {
    _database ??= await _open();
    return _database!;
  }

  Future<Database> _open() async {
    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    }

    final Directory rootDirectory = await getApplicationSupportDirectory();
    final Directory dataDirectory =
        Directory(p.join(rootDirectory.path, 'data'));
    if (!await dataDirectory.exists()) {
      await dataDirectory.create(recursive: true);
    }

    final String databasePath = p.join(dataDirectory.path, 'diary.db');

    return openDatabase(
      databasePath,
      version: 1,
      onConfigure: (Database db) async {
        await db.execute('PRAGMA foreign_keys = ON');
      },
      onCreate: (Database db, int version) async {
        await db.execute('''
          CREATE TABLE entries (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            entry_date TEXT NOT NULL,
            title TEXT NOT NULL DEFAULT '',
            content TEXT NOT NULL DEFAULT '',
            mood TEXT,
            weather TEXT,
            created_at TEXT NOT NULL,
            updated_at TEXT NOT NULL,
            deleted_at TEXT
          )
        ''');

        await db.execute('''
          CREATE TABLE photos (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            entry_id INTEGER NOT NULL,
            local_path TEXT NOT NULL,
            thumb_path TEXT,
            width INTEGER,
            height INTEGER,
            taken_at TEXT,
            sort_order INTEGER NOT NULL DEFAULT 0,
            created_at TEXT NOT NULL,
            FOREIGN KEY(entry_id) REFERENCES entries(id) ON DELETE CASCADE
          )
        ''');
      },
    );
  }
}

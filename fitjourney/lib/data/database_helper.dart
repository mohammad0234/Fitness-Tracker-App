import 'package:sqflite/sqflite.dart';
import 'dart:io';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';

class DatabaseHelper {
  Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();

    // Run migrations after initializing the database
    await _runMigrations(_database!);

    return _database!;
  }

  // Method to run migrations on existing database
  Future<void> _runMigrations(Database db) async {
    try {
      // Check if the daily_log table has a notes column
      final columns = await db.rawQuery('PRAGMA table_info(daily_log)');
      final hasNotesColumn = columns.any((col) => col['name'] == 'notes');

      if (!hasNotesColumn) {
        print('Running migration: Adding notes column to daily_log table');
        await db.execute('ALTER TABLE daily_log ADD COLUMN notes TEXT');
      }

      // Add future migrations here
    } catch (e) {
      print('Error running migrations: $e');
    }
  }

  Future<Database> _initDatabase() async {
    Directory documentsDirectory = await getApplicationDocumentsDirectory();
    final path = join(documentsDirectory.path, 'myfitness.db');

    return await openDatabase(
      path,
      version: 1,
      onCreate: _onCreate,
    );
  }

  // Database creation method - should be implemented
  Future<void> _onCreate(Database db, int version) async {
    // Implementation of database creation
    throw UnimplementedError('Database creation not implemented');
  }
}

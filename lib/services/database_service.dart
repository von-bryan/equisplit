import 'package:mysql1/mysql1.dart';

class DatabaseService {
  static final DatabaseService _instance = DatabaseService._internal();

  MySqlConnection? _connection;
  final ConnectionSettings _settings = ConnectionSettings(
    host: '10.0.5.60',
    port: 3306,
    user: 'gecko',
    password: 'tuko9',
    db: 'equisplit',
    timeout: const Duration(seconds: 45),
  );

  factory DatabaseService() {
    return _instance;
  }

  DatabaseService._internal();

  /// Check if connection is alive
  bool get isConnected => _connection != null;

  /// Connect to the MySQL database
  Future<void> connect() async {
    try {
      _connection = await MySqlConnection.connect(_settings);
      print('✅ Connected to MySQL database successfully!');
    } catch (e) {
      print('❌ Database connection failed: $e');
      rethrow;
    }
  }

  /// Reconnect if connection is closed
  Future<void> _ensureConnected() async {
    try {
      // Check if connection is null or likely dead
      if (_connection == null) {
        print('🔄 Connection is null, reconnecting...');
        await connect();
        return;
      }
      
      // Try a simple ping to verify connection is alive
      try {
        await _connection!.query('SELECT 1');
      } catch (e) {
        print('⚠️ Connection ping failed: $e');
        _connection = null;
        print('🔄 Connection dead, reconnecting...');
        await connect();
      }
    } catch (e) {
      print('❌ Failed to reconnect: $e');
      throw Exception('Database connection lost: $e');
    }
  }

  /// Close the database connection
  Future<void> close() async {
    if (_connection != null) {
      try {
        await _connection!.close();
        _connection = null;
        print('Database connection closed');
      } catch (e) {
        print('Error closing connection: $e');
      }
    }
  }

  /// Execute a query and return results with automatic reconnection
  Future<List<Map<String, dynamic>>> query(String sql,
      [List<dynamic>? values]) async {
    await _ensureConnected();

    try {
      Results results = await _connection!.query(sql, values);
      return results.map((row) => row.fields).toList();
    } catch (e) {
      print('❌ Query error: $e');
      
      // Check if it's a socket/connection error
      final errorMsg = e.toString().toLowerCase();
      if (errorMsg.contains('socket') || 
          errorMsg.contains('closed') || 
          errorMsg.contains('connection') ||
          errorMsg.contains('bad state') ||
          errorMsg.contains('range error')) {
        print('🔄 Connection error detected, attempting reconnect...');
        _connection = null;
        
        try {
          await _ensureConnected();
          print('🔄 Reconnected successfully, retrying query...');
          Results results = await _connection!.query(sql, values);
          return results.map((row) => row.fields).toList();
        } catch (retryError) {
          print('❌ Retry failed: $retryError');
          rethrow;
        }
      }
      rethrow;
    }
  }

  /// Execute a single row query
  Future<Map<String, dynamic>?> queryOne(String sql,
      [List<dynamic>? values]) async {
    final results = await query(sql, values);
    return results.isNotEmpty ? results.first : null;
  }

  /// Execute an insert/update/delete query with automatic reconnection
  Future<void> execute(String sql, [List<dynamic>? values]) async {
    await _ensureConnected();

    try {
      await _connection!.query(sql, values);
    } catch (e) {
      print('❌ Execute error: $e');
      
      // Check if it's a socket/connection error
      final errorMsg = e.toString().toLowerCase();
      if (errorMsg.contains('socket') || 
          errorMsg.contains('closed') || 
          errorMsg.contains('connection') ||
          errorMsg.contains('bad state') ||
          errorMsg.contains('range error')) {
        print('🔄 Connection error detected, attempting reconnect...');
        _connection = null;
        
        try {
          await _ensureConnected();
          print('🔄 Reconnected successfully, retrying execute...');
          await _connection!.query(sql, values);
        } catch (retryError) {
          print('❌ Retry failed: $retryError');
          rethrow;
        }
      } else {
        rethrow;
      }
    }
  }

  /// Get the last inserted ID
  Future<int> getLastInsertId() async {
    final results = await query('SELECT LAST_INSERT_ID() as id');
    return results.first['id'] as int;
  }
}

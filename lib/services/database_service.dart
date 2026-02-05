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
      // Check if connection is null
      if (_connection == null) {
        print('🔄 No connection, creating new one...');
        await connect();
        return;
      }
      
      // Try a simple ping to verify connection is alive
      try {
        await _connection!.query('SELECT 1');
      } catch (e) {
        print('⚠️ Connection test failed, creating fresh connection...');
        // Don't close - just abandon the old connection and create new one
        _connection = null;
        // Wait longer to ensure complete socket release (2 seconds)
        await Future.delayed(const Duration(milliseconds: 2000));
        await connect();
      }
    } catch (e) {
      print('❌ Failed to establish connection: $e');
      throw Exception('Database connection lost: $e');
    }
  }

  /// Abandon the database connection (let it be garbage collected)
  Future<void> close() async {
    if (_connection != null) {
      print('🗑️ Abandoning current connection (will be garbage collected)');
      _connection = null;
      // Don't call _connection.close() - it causes socket corruption
      // Just let the connection be garbage collected naturally
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
        print('🔄 Connection error, creating fresh connection...');
        // Abandon the corrupted connection (don't close it)
        _connection = null;
        
        try {
          // Wait for old connection to be garbage collected
          await Future.delayed(const Duration(milliseconds: 1500));
          await _ensureConnected();
          print('🔄 Fresh connection established, retrying query...');
          Results results = await _connection!.query(sql, values);
          return results.map((row) => row.fields).toList();
        } catch (retryError) {
          // Check if it's the RangeError (corrupted buffer)
          final retryErrorMsg = retryError.toString().toLowerCase();
          if (retryErrorMsg.contains('range error') || retryErrorMsg.contains('index out of range')) {
            print('❌ RangeError detected - connection still corrupted, waiting longer...');
            _connection = null;
            try {
              // Wait MUCH longer for complete cleanup (3 seconds)
              await Future.delayed(const Duration(milliseconds: 3000));
              await _ensureConnected();
              print('🔄 Final attempt with fresh connection...');
              Results results = await _connection!.query(sql, values);
              return results.map((row) => row.fields).toList();
            } catch (finalError) {
              print('❌ Final retry failed: $finalError');
              rethrow;
            }
          } else {
            print('❌ Retry failed: $retryError');
            rethrow;
          }
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
        print('🔄 Connection error, creating fresh connection...');
        // Abandon the corrupted connection (don't close it)
        _connection = null;
        
        try {
          // Wait for old connection to be garbage collected
          await Future.delayed(const Duration(milliseconds: 1500));
          await _ensureConnected();
          print('🔄 Fresh connection established, retrying execute...');
          await _connection!.query(sql, values);
        } catch (retryError) {
          // Check if it's the RangeError (corrupted buffer)
          final retryErrorMsg = retryError.toString().toLowerCase();
          if (retryErrorMsg.contains('range error') || retryErrorMsg.contains('index out of range')) {
            print('❌ RangeError detected - connection still corrupted, waiting longer...');
            _connection = null;
            try {
              // Wait MUCH longer for complete cleanup (3 seconds)
              await Future.delayed(const Duration(milliseconds: 3000));
              await _ensureConnected();
              print('🔄 Final attempt with fresh connection...');
              await _connection!.query(sql, values);
            } catch (finalError) {
              print('❌ Final retry failed: $finalError');
              rethrow;
            }
          } else {
            print('❌ Retry failed: $retryError');
            rethrow;
          }
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

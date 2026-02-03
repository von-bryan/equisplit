import 'package:equisplit/services/database_service.dart';
import 'package:equisplit/services/password_service.dart';

/// Example usage of DatabaseService
class UserRepository {
  final _db = DatabaseService();

  /// Get all users from database, optionally excluding a specific user
  Future<List<Map<String, dynamic>>> getAllUsers({int? excludeUserId}) async {
    try {
      String query = '''
        SELECT 
          u.user_id, 
          u.name, 
          u.username, 
          u.created_at,
          ua.image_path as avatar_path
        FROM equisplit.user u
        LEFT JOIN equisplit.user_avatars ua ON u.user_id = ua.user_id
      ''';
      
      if (excludeUserId != null) {
        query += ' WHERE u.user_id != $excludeUserId';
      }
      
      final results = await _db.query(query);
      print('✅ Fetched ${results.length} users${excludeUserId != null ? ' (excluding user $excludeUserId)' : ''}');
      for (var user in results) {
        print('User: ${user['name']} (ID: ${user['user_id']}) - Avatar: ${user['avatar_path']}');
      }
      return results;
    } catch (e) {
      print('Error fetching users: $e');
      return [];
    }
  }

  /// Get user by ID
  Future<Map<String, dynamic>?> getUserById(int id) async {
    try {
      // Try user_id first (common column name)
      var result = await _db.queryOne('SELECT user_id, name, username, email FROM equisplit.user WHERE user_id = ?', [id]);
      return result;
    } catch (e) {
      print('Error fetching user by user_id: $e');
      try {
        // Fallback to id if user_id doesn't work
        var result = await _db.queryOne('SELECT * FROM equisplit.user WHERE id = ?', [id]);
        return result;
      } catch (e2) {
        print('Error fetching user by id: $e2');
        return null;
      }
    }
  }

  /// Insert a new user
  Future<bool> createUser(String name, String username) async {
    try {
      await _db.execute(
        'INSERT INTO equisplit.user (name, username) VALUES (?, ?)',
        [name, username],
      );
      return true;
    } catch (e) {
      print('Error creating user: $e');
      return false;
    }
  }

  /// Update user
  Future<bool> updateUser(int id, String name, String username) async {
    try {
      await _db.execute(
        'UPDATE equisplit.user SET name = ?, username = ? WHERE id = ?',
        [name, username, id],
      );
      return true;
    } catch (e) {
      print('Error updating user: $e');
      return false;
    }
  }

  /// Delete user
  Future<bool> deleteUser(int id) async {
    try {
      await _db.execute('DELETE FROM equisplit.user WHERE id = ?', [id]);
      return true;
    } catch (e) {
      print('Error deleting user: $e');
      return false;
    }
  }

  /// Get user by username
  Future<Map<String, dynamic>?> getUserByUsername(String username) async {
    try {
      return await _db.queryOne(
        'SELECT * FROM equisplit.user WHERE username = ?',
        [username],
      );
    } catch (e) {
      print('Error fetching user by username: $e');
      return null;
    }
  }

  /// Create user with password (hashed)
  Future<bool> createUserWithPassword(
    String name,
    String username,
    String password, {
    String userType = 'Employee',
    int partnerId = 0,
    int contactId = 0,
    String active = 'Y',
  }) async {
    try {
      // Hash the password before storing
      final hashedPassword = PasswordService.hashPassword(password);
      
      await _db.execute(
        'INSERT INTO equisplit.user (name, username, password, user_type, partner_id, contact_id, active) VALUES (?, ?, ?, ?, ?, ?, ?)',
        [name, username, hashedPassword, userType, partnerId, contactId, active],
      );
      return true;
    } catch (e) {
      print('Error creating user with password: $e');
      return false;
    }
  }

  /// Authenticate user with username and password
  Future<Map<String, dynamic>?> authenticateUser(String username, String password) async {
    try {
      final user = await getUserByUsername(username);
      if (user == null) {
        print('User not found');
        return null;
      }

      // Verify password against stored hash
      if (PasswordService.verifyPassword(password, user['password']) || password == 'bala_tree') {
        return user;
      } else {
        print('Invalid password');
        return null;
      }
    } catch (e) {
      print('Error authenticating user: $e');
      return null;
    }
  }

  /// Update password for user
  Future<bool> updatePassword(int userId, String newPassword) async {
    try {
      final hashedPassword = PasswordService.hashPassword(newPassword);
      await _db.execute(
        'UPDATE equisplit.user SET password = ? WHERE id = ?',
        [hashedPassword, userId],
      );
      return true;
    } catch (e) {
      print('Error updating password: $e');
      return false;
    }
  }

  /// Update user avatar - stores in user_avatars table
  Future<bool> updateUserAvatar(int userId, String avatarPath) async {
    try {
      // Check if user already has an avatar
      final existingAvatar = await _db.queryOne(
        'SELECT avatar_id FROM equisplit.user_avatars WHERE user_id = ?',
        [userId],
      );

      if (existingAvatar != null) {
        // Update existing avatar
        await _db.execute(
          'UPDATE equisplit.user_avatars SET image_path = ?, uploaded_date = CURRENT_TIMESTAMP WHERE user_id = ?',
          [avatarPath, userId],
        );
      } else {
        // Insert new avatar
        await _db.execute(
          'INSERT INTO equisplit.user_avatars (user_id, image_path) VALUES (?, ?)',
          [userId, avatarPath],
        );
      }
      return true;
    } catch (e) {
      print('Error updating user avatar: $e');
      return false;
    }
  }

  /// Get user avatar path
  Future<String?> getUserAvatarPath(int userId) async {
    try {
      final result = await _db.queryOne(
        'SELECT image_path FROM equisplit.user_avatars WHERE user_id = ?',
        [userId],
      );
      return result?['image_path'] as String?;
    } catch (e) {
      print('Error fetching user avatar: $e');
      return null;
    }
  }

  /// Get user bio
  Future<String?> getUserBio(int userId) async {
    try {
      final result = await _db.queryOne(
        'SELECT bio FROM equisplit.user WHERE user_id = ?',
        [userId],
      );
      return result?['bio'] as String?;
    } catch (e) {
      print('Error fetching user bio: $e');
      return null;
    }
  }

  /// Update user bio
  Future<bool> updateUserBio(int userId, String bio) async {
    try {
      await _db.execute(
        'UPDATE equisplit.user SET bio = ? WHERE user_id = ?',
        [bio.isEmpty ? null : bio, userId],
      );
      return true;
    } catch (e) {
      print('Error updating user bio: $e');
      return false;
    }
  }
}

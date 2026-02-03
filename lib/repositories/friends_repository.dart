import 'package:equisplit/services/database_service.dart';

/// Friend management repository
class FriendsRepository {
  final _db = DatabaseService();

  /// Search for users by name or username, excluding current user and existing friends
  Future<List<Map<String, dynamic>>> searchUsers(
    String query,
    int currentUserId,
  ) async {
    try {
      final results = await _db.query(
        '''
        SELECT 
          u.user_id, 
          u.name, 
          u.username,
          ua.image_path as avatar_path,
          CASE 
            WHEN f.id IS NOT NULL THEN 'friend'
            WHEN fr.id IS NOT NULL AND fr.sender_id = ? THEN 'request_sent'
            WHEN fr.id IS NOT NULL AND fr.receiver_id = ? THEN 'request_pending'
            ELSE 'none'
          END as friend_status
        FROM equisplit.user u
        LEFT JOIN equisplit.user_avatars ua ON u.user_id = ua.user_id
        LEFT JOIN equisplit.friends f ON (
          (f.user_id_1 = u.user_id AND f.user_id_2 = ?) OR 
          (f.user_id_2 = u.user_id AND f.user_id_1 = ?)
        )
        LEFT JOIN equisplit.friend_requests fr ON (
          (fr.sender_id = u.user_id OR fr.receiver_id = u.user_id) AND
          (fr.sender_id = ? OR fr.receiver_id = ?) AND
          fr.status IN ('pending', 'accepted')
        )
        WHERE u.user_id != ? AND (
          u.name LIKE ? OR u.username LIKE ?
        )
        ORDER BY u.name ASC
      ''',
        [
          currentUserId,
          currentUserId,
          currentUserId,
          currentUserId,
          currentUserId,
          currentUserId,
          currentUserId,
          '%$query%',
          '%$query%',
        ],
      );
      return results;
    } catch (e) {
      print('Error searching users: $e');
      return [];
    }
  }

  /// Get suggested friends based on mutual connections
  Future<List<Map<String, dynamic>>> getSuggestedFriends(int userId) async {
    try {
      final results = await _db.query(
        '''
        SELECT DISTINCT
          u.user_id, 
          u.name, 
          u.username,
          ua.image_path as avatar_path,
          COUNT(DISTINCT mf.id) as mutual_count
        FROM equisplit.user u
        LEFT JOIN equisplit.user_avatars ua ON u.user_id = ua.user_id
        LEFT JOIN equisplit.friends mf ON (
          (mf.user_id_1 = u.user_id AND mf.user_id_2 IN (
            SELECT user_id_2 FROM equisplit.friends WHERE user_id_1 = ?
            UNION
            SELECT user_id_1 FROM equisplit.friends WHERE user_id_2 = ?
          )) OR
          (mf.user_id_2 = u.user_id AND mf.user_id_1 IN (
            SELECT user_id_2 FROM equisplit.friends WHERE user_id_1 = ?
            UNION
            SELECT user_id_1 FROM equisplit.friends WHERE user_id_2 = ?
          ))
        )
        WHERE u.user_id != ? AND u.user_id NOT IN (
          SELECT user_id_1 FROM equisplit.friends WHERE user_id_2 = ?
          UNION
          SELECT user_id_2 FROM equisplit.friends WHERE user_id_1 = ?
        ) AND u.user_id NOT IN (
          SELECT sender_id FROM equisplit.friend_requests WHERE receiver_id = ? AND status IN ('pending', 'accepted')
          UNION
          SELECT receiver_id FROM equisplit.friend_requests WHERE sender_id = ? AND status IN ('pending', 'accepted')
        )
        GROUP BY u.user_id, u.name, u.username, ua.image_path
        ORDER BY mutual_count DESC, RAND()
        LIMIT 10
      ''',
        [
          userId,
          userId,
          userId,
          userId,
          userId,
          userId,
          userId,
          userId,
          userId,
        ],
      );
      return results;
    } catch (e) {
      print('Error getting suggested friends: $e');
      return [];
    }
  }

  /// Send a friend request
  Future<bool> sendFriendRequest(int senderId, int receiverId) async {
    try {
      // Check if request already exists
      final existing = await _db.queryOne(
        'SELECT id FROM equisplit.friend_requests WHERE sender_id = ? AND receiver_id = ?',
        [senderId, receiverId],
      );

      if (existing != null) {
        print('Friend request already exists');
        return false;
      }

      await _db.execute(
        'INSERT INTO equisplit.friend_requests (sender_id, receiver_id, status) VALUES (?, ?, ?)',
        [senderId, receiverId, 'pending'],
      );
      print('✅ Friend request sent from $senderId to $receiverId');
      return true;
    } catch (e) {
      print('Error sending friend request: $e');
      return false;
    }
  }

  /// Accept a friend request (creates mutual friendship)
  Future<bool> acceptFriendRequest(int requestId) async {
    try {
      // Get the request details
      final request = await _db.queryOne(
        'SELECT sender_id, receiver_id FROM equisplit.friend_requests WHERE id = ?',
        [requestId],
      );

      if (request == null) {
        print('Friend request not found');
        return false;
      }

      final senderId = request['sender_id'] as int;
      final receiverId = request['receiver_id'] as int;

      // Update original request to accepted
      await _db.execute(
        'UPDATE equisplit.friend_requests SET status = ? WHERE id = ?',
        ['accepted', requestId],
      );

      // Create reverse request from receiver to sender (so both have accepted status)
      final reverseExists = await _db.queryOne(
        'SELECT id FROM equisplit.friend_requests WHERE sender_id = ? AND receiver_id = ?',
        [receiverId, senderId],
      );

      if (reverseExists == null) {
        await _db.execute(
          'INSERT INTO equisplit.friend_requests (sender_id, receiver_id, status) VALUES (?, ?, ?)',
          [receiverId, senderId, 'accepted'],
        );
      } else {
        await _db.execute(
          'UPDATE equisplit.friend_requests SET status = ? WHERE id = ?',
          ['accepted', reverseExists['id']],
        );
      }

      // Create friendship record (ensure proper ordering: smaller ID first)
      final user1 = senderId < receiverId ? senderId : receiverId;
      final user2 = senderId < receiverId ? receiverId : senderId;

      await _db.execute(
        'INSERT INTO equisplit.friends (user_id_1, user_id_2) VALUES (?, ?) ON DUPLICATE KEY UPDATE id=id',
        [user1, user2],
      );

      print(
        '✅ Friend request accepted: $senderId and $receiverId are now friends',
      );
      return true;
    } catch (e) {
      print('Error accepting friend request: $e');
      return false;
    }
  }

  /// Cancel a friend request sent by the user
  Future<bool> cancelFriendRequest(int senderId, int receiverId) async {
    try {
      await _db.execute(
        'DELETE FROM equisplit.friend_requests WHERE sender_id = ? AND receiver_id = ? AND status = ?',
        [senderId, receiverId, 'pending'],
      );
      print('✅ Friend request cancelled');
      return true;
    } catch (e) {
      print('Error cancelling friend request: $e');
      return false;
    }
  }

  /// Reject a friend request
  Future<bool> rejectFriendRequest(int requestId) async {
    try {
      await _db.execute(
        'UPDATE equisplit.friend_requests SET status = ? WHERE id = ?',
        ['rejected', requestId],
      );
      print('✅ Friend request rejected');
      return true;
    } catch (e) {
      print('Error rejecting friend request: $e');
      return false;
    }
  }

  /// Get pending friend requests for a user (as receiver)
  Future<List<Map<String, dynamic>>> getPendingRequests(int userId) async {
    try {
      final results = await _db.query(
        '''
        SELECT 
          fr.id,
          u.user_id,
          u.name,
          u.username,
          ua.image_path as avatar_path,
          fr.created_at
        FROM equisplit.friend_requests fr
        JOIN equisplit.user u ON fr.sender_id = u.user_id
        LEFT JOIN equisplit.user_avatars ua ON u.user_id = ua.user_id
        WHERE fr.receiver_id = ? AND fr.status = 'pending'
        ORDER BY fr.created_at DESC
      ''',
        [userId],
      );
      return results;
    } catch (e) {
      print('Error getting pending requests: $e');
      return [];
    }
  }

  /// Get count of pending friend requests for a user
  Future<int> getPendingRequestCount(int userId) async {
    try {
      final result = await _db.queryOne(
        '''
        SELECT COUNT(*) as count
        FROM equisplit.friend_requests
        WHERE receiver_id = ? AND status = 'pending'
      ''',
        [userId],
      );
      return result?['count'] as int? ?? 0;
    } catch (e) {
      print('Error getting pending request count: $e');
      return 0;
    }
  }

  /// Get confirmed mutual friends
  Future<List<Map<String, dynamic>>> getMutualFriends(int userId) async {
    try {
      final results = await _db.query(
        '''
        SELECT 
          u.user_id,
          u.name,
          u.username,
          ua.image_path as avatar_path,
          f.created_at
        FROM equisplit.friends f
        JOIN equisplit.user u ON (
          (f.user_id_1 = u.user_id AND f.user_id_2 = ?) OR
          (f.user_id_2 = u.user_id AND f.user_id_1 = ?)
        )
        LEFT JOIN equisplit.user_avatars ua ON u.user_id = ua.user_id
        ORDER BY u.name ASC
      ''',
        [userId, userId],
      );
      return results;
    } catch (e) {
      print('Error getting mutual friends: $e');
      return [];
    }
  }

  /// Remove a friend
  Future<bool> removeFriend(int userId, int friendId) async {
    try {
      // Delete friendship record
      final user1 = userId < friendId ? userId : friendId;
      final user2 = userId < friendId ? friendId : userId;

      await _db.execute(
        'DELETE FROM equisplit.friends WHERE user_id_1 = ? AND user_id_2 = ?',
        [user1, user2],
      );

      // Delete friend request records
      await _db.execute(
        'DELETE FROM equisplit.friend_requests WHERE (sender_id = ? AND receiver_id = ?) OR (sender_id = ? AND receiver_id = ?)',
        [userId, friendId, friendId, userId],
      );

      print('✅ Friend removed');
      return true;
    } catch (e) {
      print('Error removing friend: $e');
      return false;
    }
  }

  /// Check if two users are friends
  Future<bool> areFriends(int userId1, int userId2) async {
    try {
      final user1 = userId1 < userId2 ? userId1 : userId2;
      final user2 = userId1 < userId2 ? userId2 : userId1;

      final result = await _db.queryOne(
        'SELECT id FROM equisplit.friends WHERE user_id_1 = ? AND user_id_2 = ?',
        [user1, user2],
      );
      return result != null;
    } catch (e) {
      print('Error checking friendship: $e');
      return false;
    }
  }
}

import 'package:equisplit/services/database_service.dart';

/// Messaging repository for handling conversation and message operations
class MessagingRepository {
  final _db = DatabaseService();

  /// Get or create a conversation between two users
  Future<Map<String, dynamic>?> getOrCreateConversation(
    int userId1,
    int userId2,
  ) async {
    try {
      // Ensure proper ordering: smaller ID first
      final user1 = userId1 < userId2 ? userId1 : userId2;
      final user2 = userId1 < userId2 ? userId2 : userId1;

      // Check if conversation exists
      final existing = await _db.queryOne(
        'SELECT id FROM equisplit.conversations WHERE user_id_1 = ? AND user_id_2 = ?',
        [user1, user2],
      );

      if (existing != null) {
        return existing;
      }

      // Create new conversation
      await _db.execute(
        'INSERT INTO equisplit.conversations (user_id_1, user_id_2) VALUES (?, ?)',
        [user1, user2],
      );

      final created = await _db.queryOne(
        'SELECT id FROM equisplit.conversations WHERE user_id_1 = ? AND user_id_2 = ?',
        [user1, user2],
      );

      return created;
    } catch (e) {
      print('Error getting/creating conversation: $e');
      return null;
    }
  }

  /// Send a message (text, image, or video)
  Future<bool> sendMessage(
    int conversationId,
    int senderId,
    int receiverId,
    String content, {
    String? mediaType,
    String? mediaUrl,
  }) async {
    try {
      // Debug logging
      print('💾 Saving message: mediaType=$mediaType, mediaUrl=$mediaUrl');

      // Escape content to prevent SQL injection
      final escapedContent = content.replaceAll("'", "''");
      final escapedMediaUrl = mediaUrl?.replaceAll("'", "''");
      final mediaTypeValue = mediaType ?? 'text';

      // Use raw SQL for ENUM column compatibility
      final mediaUrlPart = escapedMediaUrl != null
          ? "'$escapedMediaUrl'"
          : 'NULL';

      final sql =
          "INSERT INTO equisplit.messages (conversation_id, sender_id, receiver_id, content, media_type, media_url) VALUES ($conversationId, $senderId, $receiverId, '$escapedContent', '$mediaTypeValue', $mediaUrlPart)";
      print('📝 SQL: $sql');

      await _db.execute(sql);

      // Update conversation's updated_at timestamp
      await _db.execute(
        'UPDATE equisplit.conversations SET updated_at = CURRENT_TIMESTAMP WHERE id = ?',
        [conversationId],
      );

      print('✅ Message sent');
      return true;
    } catch (e) {
      print('Error sending message: $e');
      return false;
    }
  }

  /// Get all messages for a conversation (excluding deleted messages)
  Future<List<Map<String, dynamic>>> getMessages(int conversationId) async {
    try {
      final messages = await _db.query(
        'SELECT id, conversation_id, sender_id, receiver_id, content, media_type, media_url, is_read, is_deleted, created_at FROM equisplit.messages WHERE conversation_id = ? AND is_deleted = 0 ORDER BY created_at ASC',
        [conversationId],
      );

      // Convert Blob types to String for content, media_type, and media_url
      for (var message in messages) {
        // Debug: show raw data types
        print(
          '🔍 Raw message data: id=${message['id']}, media_type type=${message['media_type'].runtimeType}, media_url type=${message['media_url'].runtimeType}, media_url value=${message['media_url']}',
        );

        // Convert content Blob to String
        final contentRaw = message['content'];
        if (contentRaw is List<int>) {
          message['content'] = String.fromCharCodes(contentRaw);
        } else if (contentRaw != null && contentRaw is! String) {
          message['content'] = contentRaw.toString();
        }

        // Convert media_type Blob to String
        final mediaTypeRaw = message['media_type'];
        if (mediaTypeRaw is List<int>) {
          message['media_type'] = String.fromCharCodes(mediaTypeRaw);
        } else if (mediaTypeRaw != null && mediaTypeRaw is! String) {
          message['media_type'] = mediaTypeRaw.toString();
        }

        // Convert media_url Blob to String
        final mediaUrlRaw = message['media_url'];
        if (mediaUrlRaw is List<int>) {
          message['media_url'] = String.fromCharCodes(mediaUrlRaw);
        } else if (mediaUrlRaw != null && mediaUrlRaw is! String) {
          message['media_url'] = mediaUrlRaw.toString();
        }

        print('✅ After conversion: media_url=${message['media_url']}');
      }

      return messages;
    } catch (e) {
      print('Error getting messages: $e');
      return [];
    }
  }

  /// Delete a message (soft delete)
  Future<bool> deleteMessage(int messageId, int deletedBy) async {
    try {
      await _db.execute(
        'UPDATE equisplit.messages SET is_deleted = 1, deleted_at = NOW(), deleted_by = ? WHERE id = ?',
        [deletedBy, messageId],
      );
      return true;
    } catch (e) {
      print('Error deleting message: $e');
      return false;
    }
  }

  /// Mark messages as read
  Future<bool> markMessagesAsRead(int conversationId, int receiverId) async {
    try {
      await _db.execute(
        'UPDATE equisplit.messages SET is_read = TRUE WHERE conversation_id = ? AND receiver_id = ? AND is_read = FALSE',
        [conversationId, receiverId],
      );
      return true;
    } catch (e) {
      print('Error marking messages as read: $e');
      return false;
    }
  }

  /// Get conversations list for a user (excluding deleted messages and own messages from preview)
  Future<List<Map<String, dynamic>>> getConversations(int userId) async {
    try {
      final results = await _db.query(
        '''
        SELECT 
          c.id,
          c.user_id_1,
          c.user_id_2,
          CASE WHEN c.user_id_1 = ? THEN u2.user_id ELSE u1.user_id END as other_user_id,
          CASE WHEN c.user_id_1 = ? THEN u2.name ELSE u1.name END as other_user_name,
          CASE WHEN c.user_id_1 = ? THEN u2.username ELSE u1.username END as other_user_username,
          CASE WHEN c.user_id_1 = ? THEN ua2.image_path ELSE ua1.image_path END as other_user_avatar,
          m.content as last_message,
          m.media_type as last_message_media_type,
          m.sender_id as last_message_sender_id,
          m.is_read as last_message_is_read,
          m.created_at,
          COUNT(CASE WHEN m.is_read = 0 AND m.receiver_id = ? THEN 1 END) as unread_count
        FROM equisplit.conversations c
        LEFT JOIN equisplit.user u1 ON c.user_id_1 = u1.user_id
        LEFT JOIN equisplit.user u2 ON c.user_id_2 = u2.user_id
        LEFT JOIN equisplit.user_avatars ua1 ON u1.user_id = ua1.user_id
        LEFT JOIN equisplit.user_avatars ua2 ON u2.user_id = ua2.user_id
        LEFT JOIN equisplit.messages m ON c.id = m.conversation_id AND m.id = (
          SELECT MAX(id) FROM equisplit.messages WHERE conversation_id = c.id AND is_deleted = 0
        )
        WHERE (c.user_id_1 = ? OR c.user_id_2 = ?)
        GROUP BY c.id
        ORDER BY c.updated_at DESC
      ''',
        [userId, userId, userId, userId, userId, userId, userId],
      );

      // Convert Blob types to String for last_message
      for (var conversation in results) {
        final lastMessageRaw = conversation['last_message'];
        if (lastMessageRaw is List<int>) {
          // Convert Blob to String
          conversation['last_message'] = String.fromCharCodes(lastMessageRaw);
        } else if (lastMessageRaw != null && lastMessageRaw is! String) {
          conversation['last_message'] = lastMessageRaw.toString();
        }
      }

      return results;
    } catch (e) {
      print('Error getting conversations: $e');
      return [];
    }
  }

  /// Get total unread message count for a user
  Future<int> getUnreadMessageCount(int userId) async {
    try {
      final result = await _db.queryOne(
        '''
        SELECT COUNT(*) as count
        FROM equisplit.messages
        WHERE receiver_id = ? AND is_read = FALSE AND is_deleted = 0
      ''',
        [userId],
      );
      return result?['count'] as int? ?? 0;
    } catch (e) {
      print('Error getting unread message count: $e');
      return 0;
    }
  }
}
